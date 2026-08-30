// ============================================================
// DataPipeline.swift
// QuantDashboard - 数据管道（仅 Gate.io）— Crash-safe 重构版
// ============================================================

import Foundation
import Combine

class DataPipeline: ObservableObject {

    static let shared = DataPipeline()

    @Published var currentAsset: TradeAsset = .btcUSDT
    @Published var currentInterval: KLineInterval = .m15
    @Published var candles: [CandleData] = []
    @Published var latestPrice: Double = 0
    @Published var ticker24h: Ticker24h?
    @Published var lastUpdateTime: Date = Date()
    @Published var connectionStatus: String = "未连接"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var activeExchange: ExchangeType = .gateIO

    private var gateWS: GateIOWebSocketManager?
    private let goldProvider = GoldDataProvider()
    private let indicatorEngine = IndicatorEngine.shared

    private var cancellables = Set<AnyCancellable>()
    private var isStarted = false

    private init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        guard let gateWS = gateWS else { return }
        gateWS.onKLineUpdate = { [weak self] sym, iv, candle in
            self?.handleKLineUpdate(symbol: sym, interval: iv, candle: candle)
        }
        gateWS.onTradeUpdate = { [weak self] _, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
            }
        }
        gateWS.onTickerUpdate = { [weak self] _, ticker in
            DispatchQueue.main.async {
                self?.ticker24h = ticker
                self?.latestPrice = ticker.lastPrice
            }
        }
        gateWS.onConnectStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.connectionStatus = connected ? "Gate.io 已连接" : "重连中..."
            }
        }
    }

    func updateDataSource(_ config: DataSourceConfig) {}
    func getDataSourceConfig() -> DataSourceConfig { DataSourceConfig(primary: .gateIO) }

    func start(for asset: TradeAsset, interval: KLineInterval) {
        currentAsset = asset
        currentInterval = interval
        errorMessage = nil

        if asset.assetType == .preciousMetal {
            startGoldStream()
        } else {
            startCryptoStream(asset: asset, interval: interval)
        }
    }

    func stopAll() {
        gateWS?.disconnect()
        gateWS = nil
        goldProvider.stopPolling()
        isStarted = false
        DispatchQueue.main.async {
            self.connectionStatus = "已断开"
            self.isLoading = false
        }
    }

    private func startCryptoStream(asset: TradeAsset, interval: KLineInterval) {
        guard let name = asset.gateIOName else {
            DispatchQueue.main.async { self.connectionStatus = "不支持的资产" }
            return
        }

        DispatchQueue.main.async {
            self.connectionStatus = "连接中..."
            self.isLoading = true
        }

        // Clean up old WebSocket first
        gateWS?.disconnect()
        gateWS = nil

        // Create fresh WebSocket manager for each connection
        let ws = GateIOWebSocketManager()

        // Setup callbacks on the new instance
        ws.onKLineUpdate = { [weak self] sym, iv, candle in
            self?.handleKLineUpdate(symbol: sym, interval: iv, candle: candle)
        }
        ws.onTradeUpdate = { [weak self] _, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
            }
        }
        ws.onTickerUpdate = { [weak self] _, ticker in
            DispatchQueue.main.async {
                self?.ticker24h = ticker
                self?.latestPrice = ticker.lastPrice
            }
        }
        ws.onConnectStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.connectionStatus = connected ? "Gate.io 已连接" : "重连中..."
            }
        }

        self.gateWS = ws

        let streams = [
            "candle_\(Int(interval.intervalSeconds))_\(name)",
            "trades_\(name)",
            "tickers_\(name)"
        ]

        // Delay connection by 1s to let UI settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            ws.connect(streams: streams)
        }

        loadHistoricalKLines(exchange: .gateIO, asset: asset, interval: interval)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.connectionStatus == "连接中..." {
                self.connectionStatus = "连接超时，自动重试..."
                self.gateWS?.connect(streams: streams)
            }
        }
    }

    private func startGoldStream() {
        DispatchQueue.main.async {
            self.connectionStatus = "黄金数据连接中..."
            self.isLoading = true
        }

        goldProvider.onPriceUpdate = { [weak self] price, change, changePct in
            DispatchQueue.main.async {
                self?.latestPrice = price
                self?.lastUpdateTime = Date()
                self?.ticker24h = Ticker24h(
                    symbol: "XAU/USD", lastPrice: price,
                    priceChange: change, priceChangePercent: changePct,
                    high24h: price * 1.02, low24h: price * 0.98,
                    volume24h: 0, quoteVolume24h: 0,
                    timestamp: Date()
                )
            }
        }

        goldProvider.onCandlesUpdate = { [weak self] newCandles in
            guard let self = self, !newCandles.isEmpty else { return }
            DispatchQueue.main.async {
                self.candles = newCandles
                self.connectionStatus = "黄金数据已连接"
                self.latestPrice = newCandles.last?.close ?? 0
                self.isLoading = false
                self.indicatorEngine.computeAll(candles: newCandles, asset: .xauUSD)
            }
        }

        goldProvider.onError = { [weak self] msg in
            DispatchQueue.main.async {
                self?.errorMessage = msg
                self?.isLoading = false
            }
        }

        goldProvider.startPolling(interval: 5)
    }

    func loadHistoricalKLines(exchange: ExchangeType, asset: TradeAsset, interval: KLineInterval) {
        guard let name = asset.gateIOName else { return }

        gateWS?.fetchHistoricalKLines(symbol: name, interval: interval, limit: 500) { [weak self] historicalCandles in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if historicalCandles.isEmpty {
                    self.errorMessage = "历史数据加载失败"
                    self.isLoading = false
                    return
                }
                self.candles = historicalCandles
                self.latestPrice = historicalCandles.last?.close ?? 0
                self.lastUpdateTime = Date()
                self.isLoading = false
                self.indicatorEngine.computeAll(candles: historicalCandles, asset: asset)
            }
        }
    }

    private func handleKLineUpdate(symbol: String, interval: KLineInterval, candle: CandleData) {
        guard interval == currentInterval else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var updatedCandles = self.candles
            if let lastIndex = updatedCandles.indices.last,
               Calendar.current.isDate(updatedCandles[lastIndex].openTime, equalTo: candle.openTime, toGranularity: .second) {
                updatedCandles[lastIndex] = candle
            } else {
                updatedCandles.append(candle)
                if updatedCandles.count > 1000 { updatedCandles.removeFirst(updatedCandles.count - 1000) }
            }

            self.candles = updatedCandles
            self.latestPrice = candle.close
            self.lastUpdateTime = Date()
            self.errorMessage = nil

            self.indicatorEngine.computeAll(candles: updatedCandles, asset: self.currentAsset)
        }
    }

    func switchAsset(to asset: TradeAsset) {
        stopAll()
        currentAsset = asset
        start(for: asset, interval: currentInterval)
    }

    func switchInterval(to interval: KLineInterval) {
        currentInterval = interval
        start(for: currentAsset, interval: interval)
    }
}
