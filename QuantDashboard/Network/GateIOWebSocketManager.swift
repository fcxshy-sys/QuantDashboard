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

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var currentStreams: [String] = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private let baseWSSURL = "wss://api.gateio.ws/ws/"
    private let baseRESTURL = "https://api.gateio.ws/api/v4"

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

    private func subscribeStreams(_ streams: [String]) {
        for stream in streams {
            let parts = stream.split(separator: "_")
            guard parts.count >= 2 else { continue }
            let channel = String(parts[0])
            let pair = String(parts[1])

            let sub: [String: Any] = [
                "time": Int(Date().timeIntervalSince1970),
                "channel": "spot.\(channel)",
                "payload": [pair]
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

        guard let channel = json["channel"] as? String,
              let result = json["result"] as? [String: Any] ?? (json["result"] as? [[String: Any]])?.first else { return }

        if channel.contains("candle") {
            parseKLine(result, channel: channel)
        } else if channel.contains("trades") {
            if let arr = json["result"] as? [[String: Any]], let first = arr.first {
                parseTrade(first, channel: channel)
            }
        } else if channel.contains("tickers") {
            parseTicker(result, channel: channel)
        }
    }

    private func parseKLine(_ result: [String: Any], channel: String) {
        guard let pair = (result["pair"] as? String) ?? channel.split(separator: ".").last.map(String.init),
              let ts = result["t"] as? TimeInterval,
              let o = result["o"] as? String,
              let h = result["h"] as? String,
              let l = result["l"] as? String,
              let c = result["c"] as? String,
              let v = result["v"] as? String
        else { return }

        let intervalMap: [String: KLineInterval] = [
            "60": .m1, "300": .m5, "900": .m15,
            "3600": .h1, "14400": .h4, "86400": .d1
        ]
        let intervalKey = channel.components(separatedBy: ".").last ?? ""
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
        guard let pair = channel.split(separator: ".").last.map(String.init),
              let price = Double("\(result["price"] ?? "0")"),
              let amount = Double("\(result["amount"] ?? "0")"),
              let ts = result["create_time"] as? TimeInterval
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
        guard let pair = (result["pair"] as? String) ?? channel.split(separator: ".").last.map(String.init),
              let last = Double("\(result["last"] ?? "0")"),
              let high24 = Double("\(result["high_24h"] ?? "0")"),
              let low24 = Double("\(result["low_24h"] ?? "0")"),
              let vol24 = Double("\(result["base_volume_24h"] ?? "0")"),
              let changePct = Double("\(result["change_percentage"] ?? "0")")
        else { return }

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
        DispatchQueue.main.async { self.isConnected = false }
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
        print("[GateWS] 连接成功")
        DispatchQueue.main.async { self.isConnected = true; self.reconnectAttempts = 0 }
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
        let intervalSec = Int(interval.intervalSeconds)
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
