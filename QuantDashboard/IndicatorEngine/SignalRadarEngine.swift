// ============================================================
// SignalRadarEngine.swift
// QuantDashboard - 多空共振评分雷达引擎
// ============================================================

import Foundation
import Combine

// MARK: - 共振雷达决策引擎
/// 综合 5 个指标的实时状态，按权重动态计算多空综合评分
class SignalRadarEngine: ObservableObject {

    // MARK: - Published 状态
    @Published var currentScore: RadarScore?
    @Published var alertHistory: [AlertEvent] = []

    // MARK: - 私有状态
    private var indicators: [IndicatorProtocol] = []
    private var configs: [IndicatorConfig]

    // MARK: - 共振阈值（>= 此数量的同向信号触发强信号）
    var consensusThreshold: Int = 3

    // MARK: - 初始化
    init() {
        // 初始化 5 个指标槽位（对应 5 个 Pine Script 指标）
        let defaultConfigs = [
            IndicatorConfig(name: "MACD+RSI Pro", index: 1, period: 12, threshold: 26, sensitivity: 1.0, weight: 0.2),
            IndicatorConfig(name: "巴特沃斯谱线", index: 2, period: 20, threshold: 32, sensitivity: 0.55, weight: 0.2),
            IndicatorConfig(name: "MTF矩阵", index: 3, period: 9, threshold: 55, sensitivity: 1.0, weight: 0.2),
            IndicatorConfig(name: "ORB模型", index: 4, period: 14, threshold: 70, sensitivity: 1.0, weight: 0.2),
            IndicatorConfig(name: "自适应S/R", index: 5, period: 50, threshold: 70, sensitivity: 1.5, weight: 0.2),
        ]
        self.configs = defaultConfigs
        self.indicators = [
            CustomIndicator1(config: defaultConfigs[0]),
            CustomIndicator2(config: defaultConfigs[1]),
            CustomIndicator3(config: defaultConfigs[2]),
            CustomIndicator4(config: defaultConfigs[3]),
            CustomIndicator5(config: defaultConfigs[4]),
        ]
    }

    // MARK: - 更新指标配置
    func updateIndicatorConfig(at index: Int, config: IndicatorConfig) {
        guard index >= 0 && index < indicators.count else { return }
        configs[index] = config
        indicators[index].updateConfig(config)
    }

    // MARK: - 核心评分计算
    /// 根据当前 K 线数据，计算综合多空雷达评分
    /// - Parameters:
    ///   - candles: 当前资产的 K 线序列
    ///   - asset: 当前资产
    /// - Returns: 综合雷达评分 RadarScore
    func evaluate(candles: [CandleData], asset: TradeAsset) -> RadarScore {
        var scores: [Int: Double] = [:]
        var directions: [SignalDirection] = []
        var enabledCount = 0
        var totalWeight: Double = 0

        // 逐个计算已启用的指标
        for (i, indicator) in indicators.enumerated() {
            guard indicator.config.isEnabled else { continue }
            enabledCount += 1
            totalWeight += indicator.config.weight

            let result = indicator.generateSignal(candles: candles)
            let directionScore = resultToScore(result)
            scores[indicator.index] = directionScore
            directions.append(result.signal)
        }

        // 确保权重归一化
        let normalizedWeight = totalWeight > 0 ? totalWeight : 1.0

        // 加权综合评分 (-100 ~ +100)
        var weightedSum: Double = 0
        for (i, indicator) in indicators.enumerated() {
            guard indicator.config.isEnabled,
                  let score = scores[indicator.index] else { continue }
            weightedSum += score * (indicator.config.weight / normalizedWeight)
        }

        let finalScore = max(-100, min(100, weightedSum))

        // 计算共振方向
        let bullCount = directions.filter { $0 == .bullish }.count
        let bearCount = directions.filter { $0 == .bearish }.count
        let consensusCount = max(bullCount, bearCount)

        let consensusDirection: SignalDirection
        if bullCount > bearCount {
            consensusDirection = .bullish
        } else if bearCount > bullCount {
            consensusDirection = .bearish
        } else {
            consensusDirection = .neutral
        }

        // 判断是否触发强信号
        let isStrongSignal = consensusCount >= consensusThreshold

        // 生成建议文案
        let advisory = generateAdvisory(
            score: finalScore,
            consensus: consensusDirection,
            consensusCount: consensusCount,
            isStrong: isStrongSignal
        )

        let radarScore = RadarScore(
            score: finalScore,
            indicatorScores: scores,
            consensusDirection: consensusDirection,
            consensusCount: consensusCount,
            isStrongSignal: isStrongSignal,
            advisory: advisory,
            timestamp: Date()
        )

        // 更新主线程状态
        DispatchQueue.main.async { [weak self] in
            self?.currentScore = radarScore

            // 如果触发强信号，生成告警
            if isStrongSignal {
                let alert = AlertEvent(
                    asset: asset,
                    indicatorName: "共振雷达",
                    indicatorIndex: 0,
                    direction: consensusDirection,
                    strength: consensusCount >= 4 ? .extreme : .strong,
                    message: "⚠️ \(asset.shortName) \(consensusDirection.rawValue)共振：\(consensusCount)/\(enabledCount) 指标同向 | 综合得分: \(String(format: "%.1f", finalScore))",
                    timestamp: Date()
                )
                self?.alertHistory.insert(alert, at: 0)

                // 触发本地通知
                LocalAlertManager.shared.triggerAlert(for: alert)
            }
        }

        return radarScore
    }

    // MARK: - 信号结果转分数
    private func resultToScore(_ result: IndicatorResult) -> Double {
        let baseScore: Double
        switch result.signal {
        case .bullish: baseScore = 1.0
        case .bearish: baseScore = -1.0
        case .neutral: baseScore = 0.0
        }

        let strengthMultiplier: Double
        switch result.strength {
        case .weak: strengthMultiplier = 25
        case .moderate: strengthMultiplier = 50
        case .strong: strengthMultiplier = 75
        case .extreme: strengthMultiplier = 100
        }

        return baseScore * strengthMultiplier
    }

    // MARK: - 生成建议文案
    private func generateAdvisory(score: Double, consensus: SignalDirection,
                                   consensusCount: Int, isStrong: Bool) -> String {
        if isStrong {
            switch consensus {
            case .bullish:
                return "🟢 \(consensusCount) 指标共振看多，综合得分 \(String(format: "%.0f", score))，建议关注做多机会"
            case .bearish:
                return "🔴 \(consensusCount) 指标共振看空，综合得分 \(String(format: "%.0f", score))，建议关注做空机会"
            case .neutral:
                return "⚪ 指标方向分歧，建议观望"
            }
        } else {
            switch consensus {
            case .bullish: return "偏多格局，综合得分 \(String(format: "%.0f", score))"
            case .bearish: return "偏空格局，综合得分 \(String(format: "%.0f", score))"
            case .neutral: return "多空胶着，综合得分 \(String(format: "%.0f", score))"
            }
        }
    }
}
