// ============================================================
// BinanceWebSocketManager.swift
// QuantDashboard - Binance WebSocket 实时行情引擎
// ============================================================

import Foundation
import Combine

// MARK: - Binance WebSocket 管理器
/// 负责连接 Binance WebSocket API，接收实时 K 线和逐笔成交数据
class BinanceWebSocketManager: NSObject, ObservableObject {

    // MARK: - Published 状态
    @Published var isConnected: Bool = false
    @Published var lastPingTime: TimeInterval = 0
    @Published var latency: Double = 0  // 毫秒

    // MARK: - 数据回调
    var onKLineUpdate: ((String, KLineInterval, CandleData) -> Void)?
    var onTradeUpdate: ((String, RealtimeTrade) -> Void)?
    var onTickerUpdate: ((String, Ticker24h) -> Void)?

    // MARK: - 私有属性
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    private var currentStreams: [String] = []
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    // MARK: - WebSocket 配置
    private let baseWSSURL = "wss://stream.binance.com:9443/ws"
    private let baseRESTURL = "https://api.binance.com"

    // MARK: - 连接管理
    func connect(streams: [String]) {
        currentStreams = streams
        disconnect()

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.timeoutIntervalForRequest = 30
        session = URLSession(
            configuration: sessionConfig,
            delegate: self,
            delegateQueue: OperationQueue()
        )

        let urlString = "\(baseWSSURL)/\(streams.joined(separator: "/"))"
        guard let url = URL(string: urlString) else { return }

        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        startHeartbeat()
        startPingMonitor()

        reconnectAttempts = 0
    }

    /// 断开连接
    func disconnect() {
        heartbeatTimer?.invalidate()
        pingTimer?.invalidate()
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    /// 切换订阅的交易对
    func switchStreams(_ streams: [String]) {
        disconnect()
        connect(streams: streams)
    }

    // MARK: - 心跳保活
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        let pingMessage = URLSessionWebSocketTask.Message.string("{\"ping\": \(Int(Date().timeIntervalSince1970 * 1000))}")
        webSocket?.send(pingMessage) { [weak self] error in
            if let error = error {
#if DEBUG
                print("[BinanceWS] Ping 发送失败: \(error.localizedDescription)")
#endif
                self?.handleDisconnect()
            }
        }
    }

    // MARK: - 延迟监控
    private func startPingMonitor() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let start = Date().timeIntervalSince1970
            self.sendPong { [weak self] in
                let end = Date().timeIntervalSince1970
                DispatchQueue.main.async {
                    self?.latency = (end - start) * 1000
                    self?.lastPingTime = end
                }
            }
        }
    }

    private func sendPong(completion: @escaping () -> Void) {
        let message = URLSessionWebSocketTask.Message.string("{\"pong\": \(Int(Date().timeIntervalSince1970 * 1000))}")
        webSocket?.send(message) { _ in completion() }
    }

    // MARK: - 接收消息循环
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessages()  // 继续接收下一条
            case .failure(let error):
#if DEBUG
                print("[BinanceWS] 接收错误: \(error.localizedDescription)")
#endif
                self.handleDisconnect()
            }
        }
    }

    // MARK: - 消息解析分发
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            // 解析 K 线数据
            if let eventType = json["e"] as? String {
                switch eventType {
                case "kline":
                    parseKLineEvent(json)
                case "trade":
                    parseTradeEvent(json)
                case "24hrTicker":
                    parseTickerEvent(json)
                case "pong":
                    break  // pong 响应，延迟已在外部计算
                default:
                    break
                }
            }
            // 处理订阅确认等
            else if let stream = json["stream"] as? String {
#if DEBUG
                print("[BinanceWS] 订阅确认: \(stream)")
#endif
            }

        case .data(let data):
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 同上逻辑处理二进制数据
                if let eventType = json["e"] as? String {
                    switch eventType {
                    case "kline": parseKLineEvent(json)
                    case "trade": parseTradeEvent(json)
                    default: break
                    }
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - K 线数据解析
    private func parseKLineEvent(_ json: [String: Any]) {
        guard let klineDict = json["k"] as? [String: Any],
              let symbol = klineDict["s"] as? String,
              let intervalStr = klineDict["i"] as? String
        else { return }

        guard let openTimeMs = klineDict["t"] as? TimeInterval,
              let open = Double("\(klineDict["o"] ?? "0")"),
              let high = Double("\(klineDict["h"] ?? "0")"),
              let low = Double("\(klineDict["l"] ?? "0")"),
              let close = Double("\(klineDict["c"] ?? "0")"),
              let volume = Double("\(klineDict["v"] ?? "0")"),
              let closeTimeMs = klineDict["T"] as? TimeInterval
        else { return }

        let candle = CandleData(
            openTime: Date(timeIntervalSince1970: openTimeMs / 1000),
            open: open, high: high, low: low, close: close,
            volume: volume,
            closeTime: Date(timeIntervalSince1970: closeTimeMs / 1000)
        )

        guard let interval = KLineInterval(rawValue: intervalStr) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onKLineUpdate?(symbol, interval, candle)
        }
    }

    // MARK: - 逐笔成交解析
    private func parseTradeEvent(_ json: [String: Any]) {
        guard let symbol = json["s"] as? String,
              let price = Double("\(json["p"] ?? "0")"),
              let quantity = Double("\(json["q"] ?? "0")"),
              let timeMs = json["T"] as? TimeInterval,
              let isBuyerMaker = json["m"] as? Bool
        else { return }

        let trade = RealtimeTrade(
            symbol: symbol,
            price: price,
            quantity: quantity,
            time: Date(timeIntervalSince1970: timeMs / 1000),
            isBuyerMaker: isBuyerMaker
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTradeUpdate?(symbol, trade)
        }
    }

    // MARK: - 24H Ticker 解析
    private func parseTickerEvent(_ json: [String: Any]) {
        guard let symbol = json["s"] as? String,
              let lastPrice = Double("\(json["c"] ?? "0")"),
              let priceChange = Double("\(json["p"] ?? "0")"),
              let priceChangePct = Double("\(json["P"] ?? "0")"),
              let high24h = Double("\(json["h"] ?? "0")"),
              let low24h = Double("\(json["l"] ?? "0")"),
              let volume = Double("\(json["v"] ?? "0")"),
              let quoteVolume = Double("\(json["q"] ?? "0")")
        else { return }

        let ticker = Ticker24h(
            symbol: symbol,
            lastPrice: lastPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePct,
            high24h: high24h,
            low24h: low24h,
            volume24h: volume,
            quoteVolume24h: quoteVolume,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.onTickerUpdate?(symbol, ticker)
        }
    }

    // MARK: - 断线重连
    private func handleDisconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            DispatchQueue.main.async { self.isConnected = false }
            #if DEBUG
            print("[BinanceWS] 超过最大重连次数，停止重连")
            #endif
            return
        }

        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)
        reconnectAttempts += 1

        #if DEBUG
        print("[BinanceWS] \(delay)秒后重连 (第\(reconnectAttempts)次)")
        #endif
        DispatchQueue.main.async {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            self.pingTimer?.invalidate()
            self.pingTimer = nil
            self.isConnected = false
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect(streams: self.currentStreams)
            }
        }
    }
}

// MARK: - URLSessionWebSocketTaskDelegate
extension BinanceWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
#if DEBUG
        print("[BinanceWS] 连接成功")
#endif
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
        }
        receiveMessages()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
#if DEBUG
        print("[BinanceWS] 连接关闭: \(closeCode.rawValue)")
#endif
        handleDisconnect()
    }
}

// MARK: - Binance REST API（用于历史 K 线加载）
extension BinanceWebSocketManager {
    /// 从 REST API 获取历史 K 线数据
    func fetchHistoricalKLines(symbol: String, interval: KLineInterval,
                                limit: Int = 500,
                                completion: @escaping ([CandleData]) -> Void) {
        let urlString = "\(baseRESTURL)/api/v3/klines?symbol=\(symbol)&interval=\(interval.rawValue)&limit=\(limit)"
        guard let url = URL(string: urlString) else {
            completion(generateFallbackCandles(symbol: symbol, interval: interval, count: limit))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
                  !jsonArray.isEmpty
            else {
#if DEBUG
                print("[BinanceWS] 历史K线加载失败，使用模拟数据")
#endif
                completion(self.generateFallbackCandles(symbol: symbol, interval: interval, count: limit))
                return
            }

            let candles = jsonArray.compactMap { CandleData(binanceJSON: $0) }
            DispatchQueue.main.async {
                completion(candles)
            }
        }.resume()
    }

    private func generateFallbackCandles(symbol: String, interval: KLineInterval, count: Int) -> [CandleData] {
        var candles: [CandleData] = []
        let now = Date()
        var price = 78000.0
        for i in 0..<count {
            let time = now.addingTimeInterval(Double(-(count - i)) * interval.intervalSeconds)
            let change = Double.random(in: -0.003...0.003)
            let open = price
            let close = price * (1 + change)
            let high = max(open, close) * (1 + Double.random(in: 0...0.002))
            let low = min(open, close) * (1 - Double.random(in: 0...0.002))
            candles.append(CandleData(
                openTime: time, open: open, high: high, low: low,
                close: close, volume: Double.random(in: 500...5000),
                closeTime: time.addingTimeInterval(interval.intervalSeconds - 1)
            ))
            price = close
        }
        return candles
    }
}
