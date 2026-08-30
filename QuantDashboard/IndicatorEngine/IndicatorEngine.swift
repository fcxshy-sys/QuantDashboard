// ============================================================
// IndicatorEngine.swift
// QuantDashboard - 指标引擎总调度器
// ============================================================

import Foundation
import Combine

// MARK: - 指标引擎调度器
/// 统一管理所有指标的计算调度、参数配置和结果缓存
class IndicatorEngine: ObservableObject {

    // MARK: - 单例
    static let shared = IndicatorEngine()

    // MARK: - Published 状态
    @Published var latestResults: [Int: IndicatorResult] = [:]     // 指标编号 → 最新结果
    @Published var timeSeries: [Int: [IndicatorTimePoint]] = [:]   // 指标编号 → 时间序列
    @Published var radarScore: RadarScore?

    // MARK: - 核心组件
    let radarEngine = SignalRadarEngine()

    // MARK: - 指标实例列表
    private(set) var indicators: [IndicatorProtocol] = []
    private let indicatorLock = NSLock()
    private var computeWorkItem: DispatchWorkItem?
    private var lastComputeTime: Date = .distantPast
    private let minComputeInterval: TimeInterval = 0.3

    // MARK: - 初始化
    private init() {
        indicators = [
            CustomIndicator1(),
            CustomIndicator2(),
            CustomIndicator3(),
            CustomIndicator4(),
            CustomIndicator5(),
        ]
    }

    // MARK: - 计算所有指标
    /// 对给定 K 线数据执行所有已启用指标的计算
    func computeAll(candles: [CandleData], asset: TradeAsset) {
        guard !candles.isEmpty else { return }
        let now = Date()
        guard now.timeIntervalSince(lastComputeTime) >= minComputeInterval else { return }
        lastComputeTime = now

        computeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let computeCandles = candles

            var newResults: [Int: IndicatorResult] = [:]
            var newTimeSeries: [Int: [IndicatorTimePoint]] = [:]

            self.indicatorLock.lock()
            for indicator in self.indicators {
                guard indicator.config.isEnabled else { continue }
                let series = indicator.calculate(candles: computeCandles)
                let signal = indicator.generateSignal(candles: computeCandles)
                if signal.value.isFinite {
                    newResults[indicator.index] = signal
                }
                newTimeSeries[indicator.index] = series.filter { $0.mainValue.isFinite }
            }
            self.indicatorLock.unlock()

            let radar = self.radarEngine.evaluate(candles: computeCandles, asset: asset)

            let safeResults = newResults.mapValues { r -> IndicatorResult in
                guard r.value.isFinite else {
                    return IndicatorResult(indicatorName: r.indicatorName, indicatorIndex: r.indicatorIndex, value: 0, signal: .neutral, strength: .weak, description: "计算异常")
                }
                return r
            }

            DispatchQueue.main.async { [weak self] in
                self?.latestResults = safeResults
                self?.timeSeries = newTimeSeries
                self?.radarScore = radar
            }
        }
        computeWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // MARK: - 更新单个指标配置
    func updateConfig(for index: Int, config: IndicatorConfig) {
        guard index >= 0 && index < indicators.count else { return }
        indicatorLock.lock()
        indicators[index].updateConfig(config)
        indicatorLock.unlock()
        radarEngine.updateIndicatorConfig(at: index, config: config)
    }

    // MARK: - 获取指标实例
    func indicator(at index: Int) -> IndicatorProtocol? {
        guard index >= 0 && index < indicators.count else { return nil }
        return indicators[index]
    }

    // MARK: - 获取所有指标配置
    func allConfigs() -> [IndicatorConfig] {
        indicatorLock.lock()
        let configs = indicators.map { $0.config }
        indicatorLock.unlock()
        return configs
    }
}
