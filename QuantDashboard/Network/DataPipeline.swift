// ============================================================
// DataPipeline.swift
// QuantDashboard - 数据管道调度层（多交易所 + 自动切换）
// ============================================================

import Foundation
import Combine

// MARK: - 数据管道
class DataPipeline: ObservableObject {

    static let shared = DataPipeline()

    // MARK: - Published 状态
    @Published var currentAsset: TradeAsset = .btcUSDT
    @Published var currentInterval: KLineInterval = .m15
    @Published var candles: [CandleData] = []
    @Published var latestPrice: Double = 0
    @Published var ticker24h: Ticker24h?
    @Published var lastUpdateTime: Date = Date()
    @Published var connectionStatus: String = "未连接"
    @Published var activeExchange: ExchangeType = .binance

    // MARK: - 核心组件
    private let binanceWS = BinanceWebSocketManager()
    private let bitgetWS = BitgetWebSocketManager()
    private let gateWS = GateIOWebSocketManager()
    private let goldProvider = GoldDataProvider()
    private let indicatorEngine = IndicatorEngine.shared

    // MARK: - 数据源配置
    private var dataSourceConfig = DataSourceConfig(primary: .binance, fallback1: .bitget, fallback2: .gateIO)
    private var currentFailCount: [ExchangeType: Int] = [:]
    private let maxFailBeforeSwitch = 3

    // MARK: - 缓存
    private var candleCache: [TradeAsset: [KLineInterval: [CandleData]]] = [:]
    private let maxCacheSize = 1000

    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current

    // MARK: - 初始化
    private init() {
        setupAllCallbacks()
    }

    // MARK: - 更新数据源配置
    func updateDataSource(_ config: DataSourceConfig) {
        dataSourceConfig = config
    }

    func getDataSourceConfig() -> DataSourceConfig {
        dataSourceConfig
    }

    // MARK: - 配置所有交易所回调
    private func setupAllCallbacks() {
        setupBinanceCallbacks()
        setupBitgetCallbacks()
        setupGateCallbacks()
    }

    private func setupBinanceCallbacks() {
        binanceWS.onKLineUpdate = { [weak self] sym, iv, candle in
            self?.handleKLineUpdate(symbol: sym, interval: iv, candle: candle, exchange: .binance)
        }
        binanceWS.onTradeUpdate = { [weak self] _, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
                self?.currentFailCount[.binance] = 0
            }
        }
        binanceWS.onTickerUpdate = { [weak self] _, ticker in
            DispatchQueue.main.async {
                self?.ticker24h = ticker
                self?.latestPrice = ticker.lastPrice
            }
        }
    }

    private func setupBitgetCallbacks() {
        bitgetWS.onKLineUpdate = { [weak self] sym, iv, candle in
            self?.handleKLineUpdate(symbol: sym, interval: iv, candle: candle, exchange: .bitget)
        }
        bitgetWS.onTradeUpdate = { [weak self] _, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
                self?.currentFailCount[.bitget] = 0
            }
        }
        bitgetWS.onTickerUpdate = { [weak self] _, ticker in
            DispatchQueue.main.async {
                self?.ticker24h = ticker
                self?.latestPrice = ticker.lastPrice
            }
        }
    }

    private func setupGateCallbacks() {
        gateWS.onKLineUpdate = { [weak self] sym, iv, candle in
            self?.handleKLineUpdate(symbol: sym, interval: iv, candle: candle, exchange: .gateIO)
        }
        gateWS.onTradeUpdate = { [weak self] _, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
                self?.currentFailCount[.gateIO] = 0
            }
        }
        gateWS.onTickerUpdate = { [weak self] _, ticker in
            DispatchQueue.main.async {
                self?.ticker24h = ticker
                self?.latestPrice = ticker.lastPrice
            }
        }
    }

    // MARK: - 启动数据流
    func start(for asset: TradeAsset, interval: KLineInterval) {
        currentAsset = asset
        currentInterval = interval

        switch asset.assetType {
        case .crypto:
            startCryptoStream(asset: asset, interval: interval)
        case .preciousMetal:
            startGoldStream()
        }
    }

    func stopAll() {
        binanceWS.disconnect()
        bitgetWS.disconnect()
        gateWS.disconnect()
        goldProvider.stopPolling()
        DispatchQueue.main.async { self.connectionStatus = "已断开" }
    }

    // MARK: - 加密货币数据流（按优先级尝试）
    private func startCryptoStream(asset: TradeAsset, interval: KLineInterval) {
        let exchanges = dataSourceConfig.ordered

        for exchange in exchanges {
            if tryConnect(exchange: exchange, asset: asset, interval: interval) {
                return
            }
        }

        DispatchQueue.main.async { self.connectionStatus = "所有交易所连接失败" }
    }

    private func tryConnect(exchange: ExchangeType, asset: TradeAsset, interval: KLineInterval) -> Bool {
        switch exchange {
        case .binance:
            guard let stream = asset.binanceStreamName else { return false }
            let streams = ["\(stream)@kline_\(interval.rawValue)", "\(stream)@trade", "\(stream)@ticker"]
            binanceWS.connect(streams: streams)
            loadHistoricalKLines(exchange: .binance, asset: asset, interval: interval)
            DispatchQueue.main.async {
                self.activeExchange = .binance
                self.connectionStatus = "Binance 已连接"
            }
            return true

        case .bitget:
            guard let name = asset.bitgetName else { return false }
            let streams = ["candle_\(interval.bitgetParameter)_\(name)", "trade_\(name)", "ticker_\(name)"]
            bitgetWS.connect(streams: streams)
            loadHistoricalKLines(exchange: .bitget, asset: asset, interval: interval)
            DispatchQueue.main.async {
                self.activeExchange = .bitget
                self.connectionStatus = "Bitget 已连接"
            }
            return true

        case .gateIO:
            guard let name = asset.gateIOName else { return false }
            let streams = ["candle_\(Int(interval.intervalSeconds))_\(name)", "trades_\(name)", "tickers_\(name)"]
            gateWS.connect(streams: streams)
            loadHistoricalKLines(exchange: .gateIO, asset: asset, interval: interval)
            DispatchQueue.main.async {
                self.activeExchange = .gateIO
                self.connectionStatus = "Gate.io 已连接"
            }
            return true
        }
    }

    // MARK: - 自动切换到备用交易所
    private func handleConnectionFail(exchange: ExchangeType, asset: TradeAsset, interval: KLineInterval) {
        let count = (currentFailCount[exchange] ?? 0) + 1
        currentFailCount[exchange] = count

        guard count >= maxFailBeforeSwitch else { return }

        print("[DataPipeline] \(exchange.rawValue) 连接失败 \(count) 次，切换备用源")
        let remaining = dataSourceConfig.ordered.filter { $0 != exchange }

        for next in remaining {
            if tryConnect(exchange: next, asset: asset, interval: interval) {
                return
            }
        }

        DispatchQueue.main.async { self.connectionStatus = "所有交易所连接失败" }
    }

    // MARK: - 黄金数据
    private func startGoldStream() {
        goldProvider.startPolling(interval: 5)

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
            self.updateCache(asset: .xauUSD, interval: self.currentInterval, candles: newCandles)
            DispatchQueue.main.async {
                self.candles = newCandles
                self.connectionStatus = "黄金数据已连接"
                self.latestPrice = newCandles.last?.close ?? 0
            }
            self.indicatorEngine.computeAll(candles: newCandles, asset: .xauUSD)
        }

        goldProvider.startPolling(interval: 5)
        DispatchQueue.main.async { self.connectionStatus = "黄金数据连接中..." }
    }

    // MARK: - 加载历史 K 线
    func loadHistoricalKLines(exchange: ExchangeType, asset: TradeAsset, interval: KLineInterval) {
        let completion: ([CandleData]) -> Void = { [weak self] historicalCandles in
            guard let self = self, !historicalCandles.isEmpty else { return }
            self.updateCache(asset: asset, interval: interval, candles: historicalCandles)
            DispatchQueue.main.async {
                self.candles = historicalCandles
                self.lastUpdateTime = Date()
            }
            self.indicatorEngine.computeAll(candles: historicalCandles, asset: asset)
        }

        switch exchange {
        case .binance:
            guard let stream = asset.binanceStreamName else { return }
            binanceWS.fetchHistoricalKLines(symbol: stream.uppercased(), interval: interval, limit: 500, completion: completion)
        case .bitget:
            guard let name = asset.bitgetName else { return }
            bitgetWS.fetchHistoricalKLines(symbol: name, interval: interval, limit: 500, completion: completion)
        case .gateIO:
            guard let name = asset.gateIOName else { return }
            gateWS.fetchHistoricalKLines(symbol: name, interval: interval, limit: 500, completion: completion)
        }
    }

    // MARK: - 处理实时 K 线更新
    private func handleKLineUpdate(symbol: String, interval: KLineInterval, candle: CandleData, exchange: ExchangeType) {
        guard interval == currentInterval else { return }

        currentFailCount[exchange] = 0

        var cached = candleCache[currentAsset]?[interval] ?? []

        if let lastIndex = cached.indices.last,
           calendar.isDate(cached[lastIndex].openTime, equalTo: candle.toOpenTime, toGranularity: .second) {
            cached[lastIndex] = candle
        } else {
            cached.append(candle)
            if cached.count > maxCacheSize {
                cached.removeFirst(cached.count - maxCacheSize)
            }
        }

        updateCache(asset: currentAsset, interval: interval, candles: cached)

        DispatchQueue.main.async {
            self.candles = cached
            self.latestPrice = candle.close
            self.lastUpdateTime = Date()
        }

        indicatorEngine.computeAll(candles: cached, asset: currentAsset)
    }

    // MARK: - 切换
    func switchAsset(to asset: TradeAsset) {
        stopAll()
        currentAsset = asset
        start(for: asset, interval: currentInterval)
    }

    func switchInterval(to interval: KLineInterval) {
        currentInterval = interval
        start(for: currentAsset, interval: interval)
    }

    // MARK: - 缓存管理
    private func updateCache(asset: TradeAsset, interval: KLineInterval, candles: [CandleData]) {
        if candleCache[asset] == nil { candleCache[asset] = [:] }
        candleCache[asset]?[interval] = candles
    }

    func cachedCandles(for asset: TradeAsset, interval: KLineInterval) -> [CandleData] {
        candleCache[asset]?[interval] ?? []
    }
}

// MARK: - CandleData 辅助扩展
private extension CandleData {
    var toOpenTime: Date { openTime }
}
