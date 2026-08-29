// ============================================================
// DataPipeline.swift
// QuantDashboard - 数据管道调度层
// 负责多资产、多周期的行情数据聚合与内存缓存
// ============================================================

import Foundation
import Combine

// MARK: - 数据管道
/// 统一调度加密货币 WebSocket 与黄金 REST 轮询，
/// 管理多周期 K 线缓存，驱动指标引擎实时计算
class DataPipeline: ObservableObject {

    // MARK: - 单例
    static let shared = DataPipeline()

    // MARK: - Published 状态
    @Published var currentAsset: TradeAsset = .btcUSDT
    @Published var currentInterval: KLineInterval = .m15
    @Published var candles: [CandleData] = []
    @Published var latestPrice: Double = 0
    @Published var ticker24h: Ticker24h?
    @Published var lastUpdateTime: Date = Date()
    @Published var connectionStatus: String = "未连接"

    // MARK: - 核心组件
    private let binanceWS = BinanceWebSocketManager()
    private let goldProvider = GoldDataProvider()
    private let indicatorEngine = IndicatorEngine.shared

    // MARK: - 内存时序缓存 [资产: [周期: K线数组]]
    private var candleCache: [TradeAsset: [KLineInterval: [CandleData]]] = [:]
    private let maxCacheSize = 1000

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    private init() {
        setupCallbacks()
    }

    // MARK: - 配置回调
    private func setupCallbacks() {
        // Binance K 线回调
        binanceWS.onKLineUpdate = { [weak self] symbol, interval, candle in
            self?.handleKLineUpdate(symbol: symbol, interval: interval, candle: candle)
        }

        // Binance 逐笔回调
        binanceWS.onTradeUpdate = { [weak self] symbol, trade in
            DispatchQueue.main.async {
                self?.latestPrice = trade.price
                self?.lastUpdateTime = trade.time
            }
        }

        // Binance Ticker 回调
        binanceWS.onTickerUpdate = { [weak self] symbol, ticker in
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

    /// 停止所有数据流
    func stopAll() {
        binanceWS.disconnect()
        goldProvider.stopPolling()
        DispatchQueue.main.async { self.connectionStatus = "已断开" }
    }

    // MARK: - 启动加密货币 WebSocket
    private func startCryptoStream(asset: TradeAsset, interval: KLineInterval) {
        guard let streamName = asset.binanceStreamName else { return }

        let streams = [
            "\(streamName)@kline_\(interval.rawValue)",
            "\(streamName)@trade",
            "\(streamName)@ticker"
        ]

        binanceWS.connect(streams: streams)

        // 先加载历史 K 线
        loadHistoricalKLines(asset: asset, interval: interval)

        DispatchQueue.main.async { self.connectionStatus = "Binance 已连接" }
    }

    // MARK: - 启动黄金数据轮询
    private func startGoldStream() {
        goldProvider.startPolling(interval: 5)

        // 使用模拟数据作为基础
        let mockCandles = goldProvider.generateMockCandles(count: 500, basePrice: 2400.0)
        updateCache(asset: .xauUSD, interval: currentInterval, candles: mockCandles)

        DispatchQueue.main.async {
            self.candles = mockCandles
            self.connectionStatus = "黄金数据已连接"
            self.latestPrice = mockCandles.last?.close ?? 2400.0
        }
    }

    // MARK: - 加载历史 K 线
    func loadHistoricalKLines(asset: TradeAsset, interval: KLineInterval) {
        guard let streamName = asset.binanceStreamName else { return }

        binanceWS.fetchHistoricalKLines(
            symbol: streamName.uppercased(),
            interval: interval,
            limit: 500
        ) { [weak self] historicalCandles in
            guard let self = self else { return }
            self.updateCache(asset: asset, interval: interval, candles: historicalCandles)

            DispatchQueue.main.async {
                self.candles = historicalCandles
                self.lastUpdateTime = Date()
            }

            // 触发指标计算
            self.indicatorEngine.computeAll(candles: historicalCandles, asset: asset)
        }
    }

    // MARK: - 处理实时 K 线更新
    private func handleKLineUpdate(symbol: String, interval: KLineInterval, candle: CandleData) {
        guard interval == currentInterval else { return }

        var cached = candleCache[currentAsset]?[interval] ?? []

        // 如果新 K 线与最后一条时间相同则更新，否则追加
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

        // 触发指标实时计算
        indicatorEngine.computeAll(candles: cached, asset: currentAsset)
    }

    // MARK: - 切换交易对
    func switchAsset(to asset: TradeAsset) {
        stopAll()
        currentAsset = asset
        start(for: asset, interval: currentInterval)
    }

    // MARK: - 切换周期
    func switchInterval(to interval: KLineInterval) {
        currentInterval = interval
        start(for: currentAsset, interval: interval)
    }

    // MARK: - 缓存管理
    private func updateCache(asset: TradeAsset, interval: KLineInterval, candles: [CandleData]) {
        if candleCache[asset] == nil { candleCache[asset] = [:] }
        candleCache[asset]?[interval] = candles
    }

    /// 获取缓存的 K 线数据
    func cachedCandles(for asset: TradeAsset, interval: KLineInterval) -> [CandleData] {
        candleCache[asset]?[interval] ?? []
    }

    // MARK: - 日期工具
    private let calendar = Calendar.current
}

// MARK: - CandleData 辅助扩展
private extension CandleData {
    /// 用于日期比较的参考时间
    var toOpenTime: Date { openTime }
}
