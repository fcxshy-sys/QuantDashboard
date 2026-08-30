// ============================================================
// GateIOWebSocketManager.swift
// QuantDashboard - Gate.io WebSocket 实时行情引擎
// ============================================================

import Foundation
import Combine

// MARK: - Gate.io WebSocket 管理器
class GateIOWebSocketManager: NSObject, ObservableObject {

    @Published var isConnected: Bool = false

    var onKLineUpdate: ((String, KLineInterval, CandleData) -> Void)?
    var onTradeUpdate: ((String, RealtimeTrade) -> Void)?
    var onTickerUpdate: ((String, Ticker24h) -> Void)?
    var onConnectStatusChanged: ((Bool) -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var currentStreams: [String] = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private let baseWSSURL = "wss://api.gateio.ws/ws/"
    private let baseRESTURL = "https://api.gateio.ws/api/v4"

    struct StreamInfo {
        let channel: String
        let pair: String
    }

    func connect(streams: [String]) {
        currentStreams = streams
        disconnect()

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())

        guard let url = URL(string: baseWSSURL) else { return }
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        startHeartbeat()
        reconnectAttempts = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.subscribeStreams(streams)
        }
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    func switchStreams(_ streams: [String]) {
        disconnect()
        connect(streams: streams)
    }

    private func parseStream(_ stream: String) -> StreamInfo? {
        let parts = stream.split(separator: "_")
        guard parts.count >= 2 else { return nil }

        let pair = String(parts.last!)

        if parts[0] == "candle" && parts.count >= 3 {
            let period = parts[1]
            let channel = "spot.candle.\(period)s"
            return StreamInfo(channel: channel, pair: pair)
        } else if parts[0] == "trades" {
            return StreamInfo(channel: "spot.trades", pair: pair)
        } else if parts[0] == "tickers" {
            return StreamInfo(channel: "spot.tickers", pair: pair)
        }
        return nil
    }

    private func subscribeStreams(_ streams: [String]) {
        for stream in streams {
            guard let info = parseStream(stream) else { continue }

            let sub: [String: Any] = [
                "time": Int(Date().timeIntervalSince1970),
                "channel": info.channel,
                "payload": [info.pair]
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: sub),
                  let str = String(data: data, encoding: .utf8) else { continue }
            webSocket?.send(.string(str)) { _ in }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        let msg = URLSessionWebSocketTask.Message.string("{\"time\":\(Int(Date().timeIntervalSince1970)),\"channel\":\"spot.ping\",\"payload\":[]}")
        webSocket?.send(msg) { [weak self] error in
            if error != nil { self?.handleDisconnect() }
        }
    }

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessages()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        guard let channel = json["channel"] as? String else { return }

        if channel.contains("candle") {
            if let result = json["result"] as? [String: Any] {
                parseKLine(result, channel: channel)
            }
        } else if channel.contains("trades") {
            if let arr = json["result"] as? [[String: Any]], let first = arr.first {
                parseTrade(first, channel: channel)
            }
        } else if channel.contains("tickers") {
            if let result = json["result"] as? [String: Any] {
                parseTicker(result, channel: channel)
            }
        }
    }

    private func parseKLine(_ result: [String: Any], channel: String) {
        let pair = (result["pair"] as? String) ?? channel.split(separator: ".").last.map(String.init) ?? ""
        guard let ts = result["t"] as? TimeInterval else { return }
        let o = "\(result["o"] ?? "0")"
        let h = "\(result["h"] ?? "0")"
        let l = "\(result["l"] ?? "0")"
        let c = "\(result["c"] ?? "0")"
        let v = "\(result["v"] ?? "0")"

        let intervalMap: [String: KLineInterval] = [
            "60": .m1, "300": .m5, "900": .m15,
            "3600": .h1, "14400": .h4, "86400": .d1
        ]
        let intervalKey = channel.components(separatedBy: ".").first { $0.allSatisfy(\.isNumber) } ?? ""
        guard let interval = intervalMap[intervalKey] else { return }

        let candle = CandleData(
            openTime: Date(timeIntervalSince1970: ts),
            open: Double(o) ?? 0, high: Double(h) ?? 0,
            low: Double(l) ?? 0, close: Double(c) ?? 0,
            volume: Double(v) ?? 0,
            closeTime: Date(timeIntervalSince1970: ts + interval.intervalSeconds)
        )

        DispatchQueue.main.async { [weak self] in
            self?.onKLineUpdate?(pair, interval, candle)
        }
    }

    private func parseTrade(_ result: [String: Any], channel: String) {
        let pair = channel.components(separatedBy: ".").last ?? ""
        guard let priceStr = result["price"] as? String ?? (result["price"] as? NSNumber)?.stringValue,
              let price = Double(priceStr),
              let amountStr = result["amount"] as? String ?? (result["amount"] as? NSNumber)?.stringValue,
              let amount = Double(amountStr),
              let ts = result["create_time"] as? TimeInterval ?? (result["create_time"] as? NSNumber)?.doubleValue
        else { return }

        let trade = RealtimeTrade(
            symbol: pair, price: price, quantity: amount,
            time: Date(timeIntervalSince1970: ts),
            isBuyerMaker: (result["side"] as? String) == "sell"
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTradeUpdate?(pair, trade)
        }
    }

    private func parseTicker(_ result: [String: Any], channel: String) {
        let pair = (result["pair"] as? String) ?? channel.components(separatedBy: ".").last ?? ""
        let lastStr = "\(result["last"] ?? "0")"
        let highStr = "\(result["high_24h"] ?? "0")"
        let lowStr = "\(result["low_24h"] ?? "0")"
        let volStr = "\(result["base_volume_24h"] ?? "0")"
        let pctStr = "\(result["change_percentage"] ?? "0")"

        guard let last = Double(lastStr) else { return }
        let high24 = Double(highStr) ?? 0
        let low24 = Double(lowStr) ?? 0
        let vol24 = Double(volStr) ?? 0
        let changePct = Double(pctStr) ?? 0

        let change = last * changePct / 100
        let ticker = Ticker24h(
            symbol: pair, lastPrice: last,
            priceChange: change, priceChangePercent: changePct,
            high24h: high24, low24h: low24,
            volume24h: vol24, quoteVolume24h: vol24 * last,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTickerUpdate?(pair, ticker)
        }
    }

    private func handleDisconnect() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.onConnectStatusChanged?(false)
        }
        heartbeatTimer?.invalidate()

        guard reconnectAttempts < maxReconnectAttempts else { return }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect(streams: self?.currentStreams ?? [])
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension GateIOWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
            self.onConnectStatusChanged?(true)
        }
        receiveMessages()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}

// MARK: - REST API
extension GateIOWebSocketManager {
    func fetchHistoricalKLines(symbol: String, interval: KLineInterval,
                                limit: Int = 500,
                                completion: @escaping ([CandleData]) -> Void) {
        let urlString = "\(baseRESTURL)/spot/candlesticks?currency_pair=\(symbol)&interval=\(interval.gateIOParameter)&limit=\(limit)"
        guard let url = URL(string: urlString) else { completion([]); return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]]
            else { completion([]); return }

            let candles = json.compactMap { row -> CandleData? in
                guard row.count >= 6,
                      let ts = row[0] as? TimeInterval,
                      let vol = Double("\(row[1])"),
                      let close = Double("\(row[2])"),
                      let high = Double("\(row[3])"),
                      let low = Double("\(row[4])"),
                      let open = Double("\(row[5])")
                else { return nil }
                return CandleData(
                    openTime: Date(timeIntervalSince1970: ts),
                    open: open, high: high, low: low, close: close,
                    volume: vol,
                    closeTime: Date(timeIntervalSince1970: ts + interval.intervalSeconds)
                )
            }
            DispatchQueue.main.async { completion(candles) }
        }.resume()
    }
}
