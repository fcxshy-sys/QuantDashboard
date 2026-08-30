// ============================================================
// BitgetWebSocketManager.swift
// QuantDashboard - Bitget WebSocket 实时行情引擎
// ============================================================

import Foundation
import Combine

// MARK: - Bitget WebSocket 管理器
class BitgetWebSocketManager: NSObject, ObservableObject {

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

    private let baseWSSURL = "wss://ws.bitget.com"
    private let baseRESTURL = "https://api.bitget.com"

    func connect(streams: [String]) {
        currentStreams = streams
        disconnect()

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())

        let urlString = "\(baseWSSURL)/spot/v1/stream/public"
        guard let url = URL(string: urlString) else { return }

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
            var channel: String
            var instId: String

            if parts.count >= 3 {
                channel = parts.dropLast().joined(separator: "_")
                instId = String(parts.last!)
            } else if parts.count == 2 {
                channel = String(parts[0])
                instId = String(parts[1])
            } else {
                channel = stream
                instId = "BTCUSDT"
            }

            let arg: [String: Any] = ["op": "subscribe", "args": [["channel": channel, "instType": "SPOT", "instId": instId]]]
            guard let data = try? JSONSerialization.data(withJSONObject: arg),
                  let str = String(data: data, encoding: .utf8) else { continue }
            webSocket?.send(.string(str)) { error in
                if let error = error {
                    #if DEBUG
                    print("[BitgetWS] 订阅失败: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        let msg = URLSessionWebSocketTask.Message.string("{\"op\":\"ping\"}")
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

        if let event = json["event"] as? String {
            if event == "subscribe" {
                #if DEBUG
                print("[BitgetWS] 订阅确认")
                #endif
            }
            return
        }

        if let channel = json["arg"] as? [String: String],
           let dataArr = json["data"] as? [[String: Any]] {
            let ch = channel["channel"] ?? ""
            if ch.contains("candle") {
                parseKLine(dataArr, arg: channel)
            } else if ch == "trade" {
                parseTrade(dataArr, arg: channel)
            } else if ch.contains("ticker") {
                parseTicker(dataArr, arg: channel)
            }
        }
    }

    private func parseKLine(_ dataArr: [[String: Any]], arg: [String: String]) {
        guard let instId = arg["instId"],
              let raw = dataArr.first,
              let tsStr = raw["ts"] as? String,
              let ts = TimeInterval(tsStr),
              let o = raw["o"] as? String,
              let h = raw["h"] as? String,
              let l = raw["l"] as? String,
              let c = raw["c"] as? String,
              let vol = raw["vol"] as? String,
              let intervalStr = arg["channel"]?.replacingOccurrences(of: "candle", with: "")
        else { return }

        let candle = CandleData(
            openTime: Date(timeIntervalSince1970: ts / 1000),
            open: Double(o) ?? 0, high: Double(h) ?? 0,
            low: Double(l) ?? 0, close: Double(c) ?? 0,
            volume: Double(vol) ?? 0,
            closeTime: Date(timeIntervalSince1970: ts / 1000 + 60)
        )

        let intervalMap: [String: KLineInterval] = [
            "1m": .m1, "5m": .m5, "15m": .m15,
            "1H": .h1, "4H": .h4, "1Dutc": .d1
        ]
        guard let interval = intervalMap[intervalStr] else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onKLineUpdate?(instId, interval, candle)
        }
    }

    private func parseTrade(_ dataArr: [[String: Any]], arg: [String: String]) {
        guard let instId = arg["instId"],
              let raw = dataArr.first,
              let price = Double("\(raw["p"] ?? "0")"),
              let qty = Double("\(raw["v"] ?? "0")"),
              let tsStr = raw["ts"] as? String,
              let ts = TimeInterval(tsStr)
        else { return }

        let trade = RealtimeTrade(
            symbol: instId, price: price, quantity: qty,
            time: Date(timeIntervalSince1970: ts / 1000),
            isBuyerMaker: (raw["s"] as? String) == "sell"
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTradeUpdate?(instId, trade)
        }
    }

    private func parseTicker(_ dataArr: [[String: Any]], arg: [String: String]) {
        guard let instId = arg["instId"],
              let raw = dataArr.first
        else { return }

        let last = Double("\(raw["last"] ?? "0")") ?? 0
        let high24 = Double("\(raw["high24h"] ?? "0")") ?? 0
        let low24 = Double("\(raw["low24h"] ?? "0")") ?? 0
        let vol24 = Double("\(raw["baseVolume"] ?? "0")") ?? 0
        let change = Double("\(raw["change24h"] ?? "0")") ?? 0
        let changePct = last > 0 ? (change / (last - change)) * 100 : 0

        let ticker = Ticker24h(
            symbol: instId, lastPrice: last,
            priceChange: change, priceChangePercent: changePct,
            high24h: high24, low24h: low24,
            volume24h: vol24, quoteVolume24h: vol24 * last,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTickerUpdate?(instId, ticker)
        }
    }

    private func handleDisconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            DispatchQueue.main.async { self.isConnected = false }
            return
        }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)
        reconnectAttempts += 1

        DispatchQueue.main.async {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            self.isConnected = false
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect(streams: self?.currentStreams ?? [])
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension BitgetWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        #if DEBUG
        print("[BitgetWS] 连接成功")
        #endif
        DispatchQueue.main.async { self.isConnected = true; self.reconnectAttempts = 0 }
        receiveMessages()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}

// MARK: - REST API
extension BitgetWebSocketManager {
    func fetchHistoricalKLines(symbol: String, interval: KLineInterval,
                                limit: Int = 500,
                                completion: @escaping ([CandleData]) -> Void) {
        let intervalStr = interval.bitgetParameter
        let urlString = "\(baseRESTURL)/api/v2/spot/market/candles?symbol=\(symbol)&granularity=\(intervalStr)&limit=\(limit)"
        guard let url = URL(string: urlString) else { completion([]); return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = json["data"] as? [[String]]
            else { completion([]); return }

            let candles = arr.compactMap { row -> CandleData? in
                guard row.count >= 6,
                      let ts = TimeInterval(row[0]),
                      let o = Double(row[1]),
                      let h = Double(row[2]),
                      let l = Double(row[3]),
                      let c = Double(row[4]),
                      let v = Double(row[5])
                else { return nil }
                return CandleData(
                    openTime: Date(timeIntervalSince1970: ts / 1000),
                    open: o, high: h, low: l, close: c,
                    volume: v,
                    closeTime: Date(timeIntervalSince1970: ts / 1000 + interval.intervalSeconds)
                )
            }
            DispatchQueue.main.async { completion(candles) }
        }.resume()
    }
}
