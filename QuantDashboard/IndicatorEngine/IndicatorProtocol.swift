// ============================================================
// IndicatorProtocol.swift
// QuantDashboard - 量化指标计算协议与基础架构
// ============================================================

import Foundation

// MARK: - 指标计算协议
/// 所有量化指标必须遵循此协议，实现标准化的输入输出接口
protocol IndicatorProtocol: AnyObject {
    /// 指标名称（如 "RSI", "MACD" 等）
    var name: String { get }

    /// 指标编号（1-5，对应五大核心指标槽位）
    var index: Int { get }

    /// 当前参数配置
    var config: IndicatorConfig { get set }

    /// 更新参数配置
    func updateConfig(_ config: IndicatorConfig)

    /// 核心计算方法：输入 K 线序列，输出指标时间序列
    /// - Parameters:
    ///   - candles: 按时间正序排列的 K 线数组
    /// - Returns: 指标时间序列点数组
    func calculate(candles: [CandleData]) -> [IndicatorTimePoint]

    /// 生成当前最新信号
    /// - Parameters:
    ///   - candles: 按时间正序排列的 K 线数组
    /// - Returns: 最新的指标计算结果（包含信号方向与强度）
    func generateSignal(candles: [CandleData]) -> IndicatorResult
}

// MARK: - 指标计算基类（提供通用工具方法）
class IndicatorBase: IndicatorProtocol {
    let name: String
    let index: Int
    var config: IndicatorConfig

    init(name: String, index: Int, config: IndicatorConfig) {
        self.name = name
        self.index = index
        self.config = config
    }

    func updateConfig(_ config: IndicatorConfig) {
        self.config = config
    }

    func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        fatalError("子类必须重写 calculate 方法")
    }

    func generateSignal(candles: [CandleData]) -> IndicatorResult {
        fatalError("子类必须重写 generateSignal 方法")
    }

    // MARK: - 通用计算工具方法

    /// 计算简单移动平均线 SMA
    func sma(_ values: [Double], period: Int) -> [Double?] {
        guard values.count >= period else {
            return Array(repeating: nil, count: values.count)
        }
        var result: [Double?] = Array(repeating: nil, count: values.count)
        var sum = values.prefix(period).reduce(0, +)
        result[period - 1] = sum / Double(period)

        for i in period..<values.count {
            sum += values[i] - values[i - period]
            result[i] = sum / Double(period)
        }
        return result
    }

    /// 计算指数移动平均线 EMA
    func ema(_ values: [Double], period: Int) -> [Double?] {
        guard !values.isEmpty, period > 0 else { return [] }
        var result: [Double?] = []
        let multiplier = 2.0 / Double(period + 1)

        // 前 period-1 个值为 nil
        for i in 0..<min(period - 1, values.count) {
            result.append(nil)
        }

        // 第一个 EMA 值用 SMA 初始化
        if values.count >= period {
            let initialSMA = values.prefix(period).reduce(0, +) / Double(period)
            result.append(initialSMA)

            var prevEMA = initialSMA
            for i in period..<values.count {
                let ema = (values[i] - prevEMA) * multiplier + prevEMA
                result.append(ema)
                prevEMA = ema
            }
        }
        return result
    }

    /// 计算 RSI（相对强弱指数）
    func rsi(_ closes: [Double], period: Int) -> [Double?] {
        guard closes.count > period else {
            return Array(repeating: nil, count: closes.count)
        }
        var result: [Double?] = Array(repeating: nil, count: closes.count)

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<closes.count {
            let delta = closes[i] - closes[i - 1]
            gains.append(delta > 0 ? delta : 0)
            losses.append(delta < 0 ? -delta : 0)
        }

        guard gains.count >= period else { return result }

        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)

        let rs: Double = avgLoss == 0 ? 100 : avgGain / avgLoss
        result[period] = 100.0 - (100.0 / (1.0 + rs))

        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            let rsVal: Double = avgLoss == 0 ? 100 : avgGain / avgLoss
            result[i + 1] = 100.0 - (100.0 / (1.0 + rsVal))
        }
        return result
    }

    /// 计算标准差
    func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }

    /// 计算真实波幅 ATR
    func trueRange(candle: CandleData, prevClose: Double) -> Double {
        let hl = candle.high - candle.low
        let hpc = abs(candle.high - prevClose)
        let lpc = abs(candle.low - prevClose)
        return max(hl, hpc, lpc)
    }

    /// 计算 ATR 序列
    func atr(candles: [CandleData], period: Int) -> [Double?] {
        guard candles.count > 1 else {
            return Array(repeating: nil, count: candles.count)
        }
        var trs: [Double] = [candles[0].high - candles[0].low]
        for i in 1..<candles.count {
            trs.append(trueRange(candle: candles[i], prevClose: candles[i - 1].close))
        }
        return sma(trs, period: period)
    }
}
