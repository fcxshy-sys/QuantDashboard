// ============================================================
// MarketViewModel.swift
// QuantDashboard - 行情视图模型 — Crash-safe 重构版
// ============================================================

import Foundation
import Combine

// MARK: - 行情视图模型
class MarketViewModel: ObservableObject {

    // MARK: - Published 状态
    @Published var currentAsset: TradeAsset = .btcUSDT
    @Published var currentInterval: KLineInterval = .m15
    @Published var latestPrice: Double = 0
    @Published var priceChange24h: Double = 0
    @Published var priceChangePercent24h: Double = 0
    @Published var high24h: Double = 0
    @Published var low24h: Double = 0
    @Published var volume24h: Double = 0
    @Published var candles: [CandleData] = []
    @Published var connectionStatus: String = "未连接"
    @Published var latency: Double = 0
    @Published var lastUpdateTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - 组件引用
    private let dataPipeline = DataPipeline.shared
    private let indicatorEngine = IndicatorEngine.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    // MARK: - 初始化
    init() {
        setupBindings()
    }

    // MARK: - 绑定数据管道
    private func setupBindings() {
        dataPipeline.$latestPrice
            .receive(on: DispatchQueue.main)
            .assign(to: &$latestPrice)

        dataPipeline.$candles
            .receive(on: DispatchQueue.main)
            .assign(to: &$candles)

        dataPipeline.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)

        dataPipeline.$ticker24h
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ticker in
                guard let ticker = ticker else { return }
                self?.priceChange24h = ticker.priceChange
                self?.priceChangePercent24h = ticker.priceChangePercent
                self?.high24h = ticker.high24h
                self?.low24h = ticker.low24h
                self?.volume24h = ticker.volume24h
            }
            .store(in: &cancellables)

        dataPipeline.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateTime)

        dataPipeline.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        dataPipeline.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    // MARK: - 启动数据流（延迟启动）
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        // Delay 0.5s to let SwiftUI finish rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.dataPipeline.start(for: self.currentAsset, interval: self.currentInterval)
        }
    }

    // MARK: - 停止数据流
    func stop() {
        dataPipeline.stopAll()
        hasStarted = false
    }

    // MARK: - 切换资产
    func switchAsset(to asset: TradeAsset) {
        currentAsset = asset
        dataPipeline.switchAsset(to: asset)
    }

    // MARK: - 切换周期
    func switchInterval(to interval: KLineInterval) {
        currentInterval = interval
        dataPipeline.switchInterval(to: interval)
    }

    // MARK: - 格式化
    var formattedPrice: String {
        if latestPrice >= 10000 {
            return String(format: "$%.2f", latestPrice)
        } else if latestPrice >= 100 {
            return String(format: "$%.4f", latestPrice)
        } else {
            return String(format: "$%.6f", latestPrice)
        }
    }

    var formattedChange: String {
        let sign = priceChangePercent24h >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", priceChangePercent24h))%"
    }

    var formattedVolume: String {
        if volume24h >= 1_000_000_000 {
            return String(format: "%.2fB", volume24h / 1_000_000_000)
        } else if volume24h >= 1_000_000 {
            return String(format: "%.2fM", volume24h / 1_000_000)
        } else if volume24h >= 1_000 {
            return String(format: "%.2fK", volume24h / 1_000)
        }
        return String(format: "%.0f", volume24h)
    }
}
