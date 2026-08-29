// ============================================================
// IndicatorModels.swift
// QuantDashboard - 指标计算结果与信号模型
// ============================================================

import Foundation

// MARK: - 信号方向
enum SignalDirection: String, Codable {
    case bullish = "看多"
    case bearish = "看空"
    case neutral = "中性"
}

// MARK: - 信号强度
enum SignalStrength: Int, Comparable, Codable {
    case weak = 1
    case moderate = 2
    case strong = 3
    case extreme = 4

    static func < (lhs: SignalStrength, rhs: SignalStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .weak: return "弱"
        case .moderate: return "中"
        case .strong: return "强"
        case .extreme: return "极强"
        }
    }
}

// MARK: - 单个指标的计算结果
struct IndicatorResult: Identifiable {
    let id = UUID()
    let indicatorName: String
    let indicatorIndex: Int          // 指标编号 1-5
    let value: Double                // 当前主值
    let secondaryValue: Double?      // 辅助值（如 MACD 的信号线）
    let tertiaryValue: Double?       // 第三值（如 MACD 柱状图）
    let signal: SignalDirection
    let strength: SignalStrength
    let description: String          // 信号文字描述
    let timestamp: Date

    init(indicatorName: String, indicatorIndex: Int, value: Double,
         secondaryValue: Double? = nil, tertiaryValue: Double? = nil,
         signal: SignalDirection = .neutral, strength: SignalStrength = .weak,
         description: String = "", timestamp: Date = Date()) {
        self.indicatorName = indicatorName
        self.indicatorIndex = indicatorIndex
        self.value = value
        self.secondaryValue = secondaryValue
        self.tertiaryValue = tertiaryValue
        self.signal = signal
        self.strength = strength
        self.description = description
        self.timestamp = timestamp
    }
}

// MARK: - 指标时间序列点（用于副图绘制）
struct IndicatorTimePoint: Identifiable {
    let id = UUID()
    let time: Date
    let mainValue: Double
    let secondaryValue: Double?
    let tertiaryValue: Double?
}

// MARK: - 综合雷达评分
struct RadarScore {
    /// 综合多空得分 (-100 ~ +100)，正值看多，负值看空
    let score: Double
    /// 各指标独立得分
    let indicatorScores: [Int: Double]  // key: 指标编号 1-5
    /// 共振方向
    let consensusDirection: SignalDirection
    /// 共振强度（产生同向信号的指标数量）
    let consensusCount: Int
    /// 是否触发强信号告警（>=3 个指标共振）
    let isStrongSignal: Bool
    /// 建议文案
    let advisory: String
    let timestamp: Date

    /// 综合得分的归一化显示文本（0~100 百分制）
    var normalizedScore: Double {
        (score + 100) / 2.0  // -100..+100 → 0..100
    }

    /// 评分等级
    var scoreLevel: String {
        switch score {
        case 60...100: return "极度看多"
        case 30..<60: return "偏多"
        case -30..<30: return "震荡中性"
        case -60..<(-30): return "偏空"
        default: return "极度看空"
        }
    }
}

// MARK: - 告警事件
struct AlertEvent: Identifiable {
    let id = UUID()
    let asset: TradeAsset
    let indicatorName: String
    let indicatorIndex: Int
    let direction: SignalDirection
    let strength: SignalStrength
    let message: String
    let timestamp: Date
    var isRead: Bool = false
}

// MARK: - 指标参数配置
struct IndicatorConfig: Identifiable, Codable {
    let id: UUID
    var name: String
    var index: Int
    var period: Int
    var threshold: Double
    var sensitivity: Double
    var isEnabled: Bool
    var weight: Double  // 雷达权重 0.0 ~ 1.0

    init(name: String, index: Int, period: Int = 14,
         threshold: Double = 70, sensitivity: Double = 1.0,
         isEnabled: Bool = true, weight: Double = 0.2) {
        self.id = UUID()
        self.name = name
        self.index = index
        self.period = period
        self.threshold = threshold
        self.sensitivity = sensitivity
        self.isEnabled = isEnabled
        self.weight = weight
    }
}
