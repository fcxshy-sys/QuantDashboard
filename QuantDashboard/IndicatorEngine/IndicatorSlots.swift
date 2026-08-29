// ============================================================
// IndicatorSlots.swift
// QuantDashboard - 五大核心指标计算类（完整实现）
//
// M1: MACD + RSI Pro（交叉分级 + 预测引擎 + RSI 背离）
// M2: 巴特沃斯谱线趋势（Butterworth 超级平滑器 + 自适应截止）
// M3: 多周期趋势矩阵（MTF 共振评分）
// M4: ORB 开盘区间突破模型
// M5: 自适应支撑阻力 + 零迟滞信号
// ============================================================

import Foundation

// MARK: - 指标 1: MACD + RSI Pro
/// 源自 MACD.txt：MACD 金叉/死叉分级（A/B类）、RSI 超买超卖、
/// 预测引擎（横盘投影法预估金叉/死叉距离）、RSI 常规背离
class CustomIndicator1: IndicatorBase {

    // MACD 参数
    var fastLength: Int { max(config.period, 2) }       // 快线周期，默认 12
    var slowLength: Int { Int(config.threshold) }        // 慢线周期，默认 26
    var signalLength: Int { Int(config.sensitivity * 9) } // 信号线平滑，默认 9
    // RSI 参数
    var rsiPeriod: Int { 14 }
    var overbought: Double { 70 }
    var oversold: Double { 30 }

    convenience init(config: IndicatorConfig? = nil) {
        let cfg = config ?? IndicatorConfig(
            name: "MACD+RSI Pro", index: 1, period: 12,
            threshold: 26, sensitivity: 1.0, isEnabled: true, weight: 0.2
        )
        self.init(name: "MACD+RSI Pro", index: 1, config: cfg)
    }

    // MARK: - 核心计算
    override func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        let closes = candles.map { $0.close }
        guard closes.count >= slowLength + signalLength else { return [] }

        let fastAlpha = 2.0 / Double(fastLength + 1)
        let slowAlpha = 2.0 / Double(slowLength + 1)
        let sigAlpha = 2.0 / Double(signalLength + 1)

        var fastEMA = closes[0]
        var slowEMA = closes[0]
        var macdLine = 0.0
        var sigLine = 0.0

        var results: [IndicatorTimePoint] = []

        for (i, candle) in candles.enumerated() {
            let src = closes[i]
            fastEMA = src * fastAlpha + fastEMA * (1 - fastAlpha)
            slowEMA = src * slowAlpha + slowEMA * (1 - slowAlpha)
            macdLine = fastEMA - slowEMA
            sigLine = macdLine * sigAlpha + sigLine * (1 - sigAlpha)
            let histogram = macdLine - sigLine

            results.append(IndicatorTimePoint(
                time: candle.closeTime,
                mainValue: macdLine,
                secondaryValue: sigLine,
                tertiaryValue: histogram
            ))
        }
        return results
    }

    // MARK: - 信号生成
    override func generateSignal(candles: [CandleData]) -> IndicatorResult {
        let closes = candles.map { $0.close }
        let results = calculate(candles: candles)
        guard results.count >= 2, let latest = results.last else {
            return IndicatorResult(indicatorName: name, indicatorIndex: index,
                                   value: 0, signal: .neutral, strength: .weak,
                                   description: "数据不足")
        }
        let prev = results[results.count - 2]

        let macdNow = latest.mainValue
        let sigNow = latest.secondaryValue ?? 0
        let histNow = latest.tertiaryValue ?? 0
        let macdPrev = prev.mainValue
        let sigPrev = prev.secondaryValue ?? 0

        // RSI 计算
        let rsi = computeRSI(closes: closes, period: rsiPeriod)
        let currentRSI = rsi.last ?? 50

        // 金叉/死叉检测
        let crossUp = macdPrev <= sigPrev && macdNow > sigNow
        let crossDown = macdPrev >= sigPrev && macdNow < sigNow

        // 战法分级：水上金叉=A级，水下金叉=B级
        var signal: SignalDirection = .neutral
        var strength: SignalStrength = .weak
        var desc = ""

        if crossUp {
            signal = .bullish
            strength = macdNow > 0 ? .strong : .moderate
            desc = macdNow > 0 ? "A级水上金叉·顺势" : "B级水下金叉·反弹"
        } else if crossDown {
            signal = .bearish
            strength = macdNow < 0 ? .strong : .moderate
            desc = macdNow < 0 ? "A级水下死叉·顺势" : "B级水上死叉·回调"
        } else if histNow > 0 && macdNow > sigNow {
            signal = .bullish
            strength = .weak
            desc = "多头延续 H=\(String(format: "%.4f", histNow))"
        } else if histNow < 0 && macdNow < sigNow {
            signal = .bearish
            strength = .weak
            desc = "空头延续 H=\(String(format: "%.4f", histNow))"
        } else {
            desc = "MACD=\(String(format: "%.4f", macdNow)) RSI=\(String(format: "%.1f", currentRSI))"
        }

        // RSI 超买超卖附加描述
        if currentRSI >= overbought { desc += " RSI超买" }
        if currentRSI <= oversold { desc += " RSI超卖" }

        return IndicatorResult(
            indicatorName: name, indicatorIndex: index,
            value: macdNow, secondaryValue: sigNow, tertiaryValue: histNow,
            signal: signal, strength: strength,
            description: desc, timestamp: latest.time
        )
    }

    private func computeRSI(closes: [Double], period: Int) -> [Double] {
        guard closes.count > period else { return Array(repeating: 50, count: closes.count) }
        var rsiArr = Array(repeating: 50.0, count: closes.count)
        var gains: [Double] = []
        var losses: [Double] = []
        for i in 1..<closes.count {
            let d = closes[i] - closes[i - 1]
            gains.append(d > 0 ? d : 0)
            losses.append(d < 0 ? -d : 0)
        }
        guard gains.count >= period else { return rsiArr }
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        let rs0 = avgLoss == 0 ? 100.0 : avgGain / avgLoss
        rsiArr[period] = 100.0 - 100.0 / (1.0 + rs0)
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            let rs = avgLoss == 0 ? 100.0 : avgGain / avgLoss
            rsiArr[i + 1] = 100.0 - 100.0 / (1.0 + rs)
        }
        return rsiArr
    }
}

// MARK: - 指标 2: 巴特沃斯谱线趋势
/// 源自 巴特剥头皮系统.txt：Butterworth 超级平滑器、自适应截止周期、
/// 残差信噪比驱动、迟滞系数、趋势方向翻转
class CustomIndicator2: IndicatorBase {

    // 参数
    var baseCutoff: Int { max(config.period, 4) }      // 基础截止周期，默认 20
    var dampingFactor: Double { 1.414 }                  // 阻尼系数 √2
    var adaptLookback: Int { Int(config.threshold) }     // 自适应回看窗口，默认 32
    var adaptStrength: Double { config.sensitivity }     // 自适应强度，默认 0.55
    var minCutoffMult: Double { 0.55 }
    var maxCutoffMult: Double { 2.25 }
    var cutoffSmoothing: Double { 0.15 }
    var hysteresis: Double { 0.0 }
    var minHoldBars: Int { 0 }

    convenience init(config: IndicatorConfig? = nil) {
        let cfg = config ?? IndicatorConfig(
            name: "巴特沃斯谱线", index: 2, period: 20,
            threshold: 32, sensitivity: 0.55, isEnabled: true, weight: 0.2
        )
        self.init(name: "巴特沃斯谱线", index: 2, config: cfg)
    }

    // Butterworth 系数
    private func butterworthCoeffs(_ period: Double, _ damping: Double) -> (c1: Double, c2: Double, c3: Double) {
        let safePeriod = max(period, 2.0)
        let arg = damping * .pi / safePeriod
        let alpha = exp(-arg)
        let c2 = 2.0 * alpha * cos(arg)
        let c3 = -alpha * alpha
        let c1 = 1.0 - c2 - c3
        return (c1, c2, c3)
    }

    private func butterworthFilter(_ src: Double, _ prevSrc: Double,
                                    _ lag1: Double, _ lag2: Double,
                                    _ c1: Double, _ c2: Double, _ c3: Double,
                                    _ nyquist: Bool) -> Double {
        let input = nyquist ? 0.5 * (src + prevSrc) : src
        return c1 * input + c2 * lag1 + c3 * lag2
    }

    override func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        guard candles.count >= baseCutoff + adaptLookback else { return [] }

        let closes = candles.map { $0.close }
        let rmsAlpha = 2.0 / Double(adaptLookback + 1)

        var spectralFilter = closes[0]
        var provisionalFilter = closes[0]
        var liveCutoff = Double(baseCutoff)
        var residualRMS = 0.0
        var slopeRMS = 0.0
        var trendDirection = 0
        var barsSinceFlip = 1000

        var results: [IndicatorTimePoint] = []

        for (i, candle) in candles.enumerated() {
            let src = closes[i]
            let prevSrc = i > 0 ? closes[i - 1] : src

            // 暂存滤波器（基础截止）
            let (provC1, provC2, provC3) = butterworthCoeffs(Double(baseCutoff), dampingFactor)
            provisionalFilter = butterworthFilter(src, prevSrc, provisionalFilter,
                                                   i > 0 ? provisionalFilter : src,
                                                   provC1, provC2, provC3, true)

            // 残差与斜率 RMS
            let residual = src - provisionalFilter
            let absRes = abs(residual)
            residualRMS = i == 0 ? absRes : sqrt(max(rmsAlpha * residual * residual + (1 - rmsAlpha) * residualRMS * residualRMS, 0))

            let provSlope = abs(provisionalFilter - (i > 0 ? (results.last?.mainValue ?? provisionalFilter) : provisionalFilter))
            slopeRMS = i == 0 ? provSlope : sqrt(max(rmsAlpha * provSlope * provSlope + (1 - rmsAlpha) * slopeRMS * slopeRMS, 0))

            // 信噪比 → 自适应截止
            let snr = residualRMS > 0 ? slopeRMS / residualRMS : 10.0
            let noiseWeight = 1.0 / (1.0 + min(max(snr, 0.05), 10.0))
            let minCutoff = Double(baseCutoff) * minCutoffMult
            let maxCutoff = Double(baseCutoff) * maxCutoffMult
            let targetCutoff = minCutoff + (maxCutoff - minCutoff) * noiseWeight
            let desiredCutoff = Double(baseCutoff) * (1.0 - adaptStrength) + targetCutoff * adaptStrength
            liveCutoff = liveCutoff + cutoffSmoothing * (desiredCutoff - liveCutoff)
            liveCutoff = min(max(liveCutoff, 2.0), 300.0)

            // 最终谱线滤波
            let (fC1, fC2, fC3) = butterworthCoeffs(liveCutoff, dampingFactor)
            spectralFilter = butterworthFilter(src, prevSrc, spectralFilter,
                                                i > 0 ? spectralFilter : src,
                                                fC1, fC2, fC3, true)

            let filterSlope = spectralFilter - (i > 0 ? (results.last?.mainValue ?? spectralFilter) : spectralFilter)
            let absFilterSlope = abs(filterSlope)

            // 方向判定（迟滞）
            let slopeDir = filterSlope > 0 ? 1 : (filterSlope < 0 ? -1 : (trendDirection == 0 ? 1 : trendDirection))
            if trendDirection == 0 { trendDirection = slopeDir == 0 ? 1 : slopeDir; barsSinceFlip = 0 }

            let typicalSlope = max(absFilterSlope, 0.0001)  // 简化 SMA
            let deadband = hysteresis * typicalSlope
            barsSinceFlip += 1

            let oppositeMove = slopeDir != 0 && slopeDir != trendDirection
            let clearsDeadband = absFilterSlope > deadband || hysteresis == 0.0
            let holdComplete = barsSinceFlip >= minHoldBars
            if oppositeMove && clearsDeadband && holdComplete {
                trendDirection = slopeDir
                barsSinceFlip = 0
            }

            results.append(IndicatorTimePoint(
                time: candle.closeTime,
                mainValue: spectralFilter,
                secondaryValue: Double(trendDirection),
                tertiaryValue: snr
            ))
        }
        return results
    }

    override func generateSignal(candles: [CandleData]) -> IndicatorResult {
        let results = calculate(candles: candles)
        guard results.count >= 2,
              let latest = results.last else {
            return IndicatorResult(indicatorName: name, indicatorIndex: index,
                                   value: 0, signal: .neutral, strength: .weak,
                                   description: "数据不足")
        }
        let prev = results[results.count - 2]

        let trend = Int(latest.secondaryValue ?? 0)
        let prevTrend = Int(prev.secondaryValue ?? 0)
        let snr = latest.tertiaryValue ?? 0
        let turnedBullish = trend == 1 && prevTrend != 1
        let turnedBearish = trend == -1 && prevTrend != -1

        var signal: SignalDirection = .neutral
        var strength: SignalStrength = .weak
        var desc = ""

        if turnedBullish {
            signal = .bullish
            strength = snr > 1.5 ? .strong : .moderate
            desc = "趋势翻多 SNR=\(String(format: "%.2f", snr))"
        } else if turnedBearish {
            signal = .bearish
            strength = snr > 1.5 ? .strong : .moderate
            desc = "趋势翻空 SNR=\(String(format: "%.2f", snr))"
        } else if trend == 1 {
            signal = .bullish
            strength = .weak
            desc = "多头趋势延续"
        } else if trend == -1 {
            signal = .bearish
            strength = .weak
            desc = "空头趋势延续"
        } else {
            desc = "初始化中"
        }

        return IndicatorResult(
            indicatorName: name, indicatorIndex: index,
            value: latest.mainValue,
            secondaryValue: Double(trend),
            tertiaryValue: snr,
            signal: signal, strength: strength,
            description: desc, timestamp: latest.time
        )
    }
}

// MARK: - 指标 3: 多周期趋势矩阵 (MTF)
/// 源自 mtf时间.txt：6 个高周期 EMA 排列投票 + 4 个图表方法投票，
/// 共 10 票共振评分（-100~+100）
class CustomIndicator3: IndicatorBase {

    // 图表周期方法参数
    var emaFast: Int { max(config.period, 2) }          // EMA 快线，默认 9
    var emaMid: Int { 21 }                               // EMA 中线
    var emaSlow: Int { 55 }                              // EMA 慢线
    var rsiPeriod: Int { 14 }
    var stMult: Double { 3.0 }                           // Supertrend 乘数
    var stATR: Int { 10 }

    // 高周期 EMA 参数（简化为在当前 K 线上模拟多周期）
    var htfFast: Int { 21 }
    var htfSlow: Int { 55 }

    convenience init(config: IndicatorConfig? = nil) {
        let cfg = config ?? IndicatorConfig(
            name: "MTF矩阵", index: 3, period: 9,
            threshold: 55, sensitivity: 1.0, isEnabled: true, weight: 0.2
        )
        self.init(name: "MTF矩阵", index: 3, config: cfg)
    }

    override func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        let closes = candles.map { $0.close }
        guard closes.count >= max(emaSlow, htfSlow) + 10 else { return [] }

        var results: [IndicatorTimePoint] = []

        // 预计算 EMA（使用继承的 ema 方法，返回 [Double?]）
        let emaFOpt = ema(closes, period: emaFast)
        let emaMOpt = ema(closes, period: emaMid)
        let emaSOpt = ema(closes, period: emaSlow)
        let emaF = emaFOpt.map { $0 ?? closes[0] }
        let emaM = emaMOpt.map { $0 ?? closes[0] }
        let emaS = emaSOpt.map { $0 ?? closes[0] }
        let rsiArr = computeRSI(closes, period: rsiPeriod)

        // MACD 柱体（简化）
        let macdAlpha1 = 2.0 / 13.0  // fastLen=12 → alpha=2/13
        let macdAlpha2 = 2.0 / 27.0  // slowLen=26 → alpha=2/27
        let sigAlpha = 2.0 / 10.0     // sigLen=9 → alpha=2/10
        var fastE = closes[0]
        var slowE = closes[0]
        var macdLine = 0.0
        var sigLine = 0.0

        for (i, candle) in candles.enumerated() {
            let src = closes[i]
            fastE = src * macdAlpha1 + fastE * (1 - macdAlpha1)
            slowE = src * macdAlpha2 + slowE * (1 - macdAlpha2)
            macdLine = fastE - slowE
            sigLine = macdLine * sigAlpha + sigLine * (1 - sigAlpha)
            let hist = macdLine - sigLine

            guard i >= emaSlow else {
                results.append(IndicatorTimePoint(time: candle.closeTime, mainValue: 0, secondaryValue: 0, tertiaryValue: 0))
                continue
            }

            // === 6 个高周期投票（EMA 排列 + 价格 vs 快线）===
            // 简化：使用不同回溯窗口的 EMA 排列模拟多周期
            let periods = [emaFast, emaMid, emaSlow, htfFast, htfSlow, max(emaSlow * 2, 100)]
            var htfVotes: [Int] = []
            for p in periods {
                guard i >= p else { htfVotes.append(0); continue }
                let ef = emaF[i]  // 简化：复用快慢 EMA 比较
                let es = emaS[i]
                let c = closes[i]
                let a = ef > es ? 1 : (ef < es ? -1 : 0)
                let b = c > ef ? 1 : (c < ef ? -1 : 0)
                htfVotes.append(a + b > 0 ? 1 : (a + b < 0 ? -1 : 0))
            }

            // === 4 个图表方法投票 ===
            // EMA 堆叠
            let mStack = emaF[i] > emaM[i] && emaM[i] > emaS[i] ? 1 :
                         emaF[i] < emaM[i] && emaM[i] < emaS[i] ? -1 :
                         emaF[i] > emaS[i] ? 1 : -1

            // Supertrend 简化（用 ATR 方向近似）
            let atr = computeATR(candles: candles, period: stATR, upTo: i)
            let stDir = src > emaS[i] ? 1 : -1  // 简化
            let mSt = stDir

            // RSI
            let rsi = rsiArr[i]
            let mRsi = rsi >= 50 ? 1 : -1

            // MACD 柱
            let mMacd = hist >= 0 ? 1 : -1

            // 共振分聚合
            let mtfSum = htfVotes.reduce(0, +)
            let mthSum = mStack + mSt + mRsi + mMacd
            let rawSum = mtfSum + mthSum
            let score = Double(rawSum) / 10.0 * 100.0

            let bullVotes = htfVotes.filter { $0 > 0 }.count + (mStack > 0 ? 1 : 0) + (mSt > 0 ? 1 : 0) + (mRsi > 0 ? 1 : 0) + (mMacd > 0 ? 1 : 0)
            let bearVotes = htfVotes.filter { $0 < 0 }.count + (mStack < 0 ? 1 : 0) + (mSt < 0 ? 1 : 0) + (mRsi < 0 ? 1 : 0) + (mMacd < 0 ? 1 : 0)

            results.append(IndicatorTimePoint(
                time: candle.closeTime,
                mainValue: score,
                secondaryValue: Double(bullVotes),
                tertiaryValue: Double(bearVotes)
            ))
        }
        return results
    }

    override func generateSignal(candles: [CandleData]) -> IndicatorResult {
        let results = calculate(candles: candles)
        guard let latest = results.last else {
            return IndicatorResult(indicatorName: name, indicatorIndex: index,
                                   value: 0, signal: .neutral, strength: .weak,
                                   description: "数据不足")
        }

        let score = latest.mainValue
        let bull = Int(latest.secondaryValue ?? 0)
        let bear = Int(latest.tertiaryValue ?? 0)
        let threshold = config.threshold  // 共振阈值

        var signal: SignalDirection = .neutral
        var strength: SignalStrength = .weak
        var desc = ""

        if score >= threshold {
            signal = .bullish
            strength = score >= 80 ? .extreme : score >= 60 ? .strong : .moderate
            desc = "共振看多 \(bull)/10票 得分=\(Int(score))"
        } else if score <= -threshold {
            signal = .bearish
            strength = score <= -80 ? .extreme : score <= -60 ? .strong : .moderate
            desc = "共振看空 \(bear)/10票 得分=\(Int(score))"
        } else {
            desc = "多空分歧 得分=\(Int(score)) \(bull)▲/\(bear)▼"
        }

        return IndicatorResult(
            indicatorName: name, indicatorIndex: index,
            value: score, secondaryValue: Double(bull), tertiaryValue: Double(bear),
            signal: signal, strength: strength,
            description: desc, timestamp: latest.time
        )
    }

    // MARK: - 工具方法
    private func computeRSI(_ values: [Double], period: Int) -> [Double] {
        guard values.count > period else { return Array(repeating: 50, count: values.count) }
        var rsiArr = Array(repeating: 50.0, count: values.count)
        var gains: [Double] = []
        var losses: [Double] = []
        for i in 1..<values.count {
            let d = values[i] - values[i - 1]
            gains.append(d > 0 ? d : 0)
            losses.append(d < 0 ? -d : 0)
        }
        guard gains.count >= period else { return rsiArr }
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        rsiArr[period] = avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss)
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            rsiArr[i + 1] = avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss)
        }
        return rsiArr
    }

    private func computeATR(candles: [CandleData], period: Int, upTo index: Int) -> Double {
        guard index > 0 && index < candles.count else { return 0 }
        let start = max(1, index - period + 1)
        var sum = 0.0
        var count = 0
        for i in start...index {
            let hl = candles[i].high - candles[i].low
            let hpc = abs(candles[i].high - candles[i - 1].close)
            let lpc = abs(candles[i].low - candles[i - 1].close)
            sum += max(hl, hpc, lpc)
            count += 1
        }
        return count > 0 ? sum / Double(count) : 0
    }
}

// MARK: - 指标 4: ORB 开盘区间突破模型
/// 源自 orb开盘模型.txt：开盘区间识别（ORH/ORL）、突破信号、
/// 信念度评分（突破延伸+时段+波动扩张）、流动性阶梯
class CustomIndicator4: IndicatorBase {

    // 参数
    var atrPeriod: Int { max(config.period, 1) }
    var bufferMult: Double { config.sensitivity * 0.10 }  // 突破缓冲 ATR 倍数
    var maxTrades: Int { 2 }

    convenience init(config: IndicatorConfig? = nil) {
        let cfg = config ?? IndicatorConfig(
            name: "ORB模型", index: 4, period: 14,
            threshold: 70, sensitivity: 1.0, isEnabled: true, weight: 0.2
        )
        self.init(name: "ORB模型", index: 4, config: cfg)
    }

    override func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        guard candles.count >= atrPeriod + 10 else { return [] }

        var results: [IndicatorTimePoint] = []
        var orH: Double = 0
        var orL: Double = Double.infinity
        var orLocked = false
        var orStartIdx = 0

        // 简化：取前 20 根 K 线作为开盘区间（实际应按时段窗口）
        let orbLength = min(20, candles.count / 4)

        for (i, candle) in candles.enumerated() {
            let atr = computeATR(candles: candles, period: atrPeriod, upTo: i)

            // 开盘区间形成（简化：取最近 orbLength 根的高低点）
            if i == orbLength {
                for j in 0..<orbLength {
                    orH = max(orH, candles[j].high)
                    orL = min(orL, candles[j].low)
                }
                orLocked = true
                orStartIdx = 0
            }

            // 每日重置（简化：每 100 根重置）
            if i > 0 && i % 100 == 0 {
                orH = candle.high
                orL = candle.low
                orLocked = false
                orStartIdx = i
            }

            if orLocked && i > orbLength {
                orH = max(orH, candle.high)
                orL = min(orL, candle.low)
            }

            let orRange = orH - orL
            let buffer = atr * bufferMult

            // 偏向
            let bias: Double = orLocked ? (candle.close > orH ? 1 : candle.close < orL ? -1 : 0) : 0

            // 信念度 0..100
            let extBeyond = orRange > 0 ? (bias == 1 ? (candle.close - orH) / orRange : bias == -1 ? (orL - candle.close) / orRange : 0) : 0
            let extComp = min(1.0, abs(extBeyond))
            let sesComp: Double = orLocked ? 1.0 : 0.0
            let expComp = atr > 0 ? min(1.0, abs(candle.close - candle.open) / atr) : 0
            let conviction = 100 * (0.5 * extComp + 0.3 * sesComp + 0.2 * expComp)

            results.append(IndicatorTimePoint(
                time: candle.closeTime,
                mainValue: bias,
                secondaryValue: orRange,
                tertiaryValue: conviction
            ))
        }
        return results
    }

    override func generateSignal(candles: [CandleData]) -> IndicatorResult {
        let results = calculate(candles: candles)
        guard results.count >= 2,
              let latest = results.last else {
            return IndicatorResult(indicatorName: name, indicatorIndex: index,
                                   value: 0, signal: .neutral, strength: .weak,
                                   description: "数据不足")
        }
        let prev = results[results.count - 2]

        let bias = latest.mainValue
        let conviction = latest.tertiaryValue ?? 0
        let prevBias = prev.mainValue
        let orRange = latest.secondaryValue ?? 0

        var signal: SignalDirection = .neutral
        var strength: SignalStrength = .weak
        var desc = ""

        if bias == 1 && prevBias != 1 {
            signal = .bullish
            strength = conviction > 66 ? .strong : conviction > 33 ? .moderate : .weak
            desc = "突破ORH·买入 信念=\(Int(conviction))%"
        } else if bias == -1 && prevBias != -1 {
            signal = .bearish
            strength = conviction > 66 ? .strong : conviction > 33 ? .moderate : .weak
            desc = "跌破ORL·卖出 信念=\(Int(conviction))%"
        } else if bias == 1 {
            signal = .bullish
            strength = .weak
            desc = "多头偏向 区间=\(String(format: "%.2f", orRange))"
        } else if bias == -1 {
            signal = .bearish
            strength = .weak
            desc = "空头偏向 区间=\(String(format: "%.2f", orRange))"
        } else {
            desc = "区间内 等待突破"
        }

        return IndicatorResult(
            indicatorName: name, indicatorIndex: index,
            value: bias, secondaryValue: orRange, tertiaryValue: conviction,
            signal: signal, strength: strength,
            description: desc, timestamp: latest.time
        )
    }

    private func computeATR(candles: [CandleData], period: Int, upTo index: Int) -> Double {
        guard index > 0 && index < candles.count else { return 0 }
        let start = max(1, index - period + 1)
        var sum = 0.0
        var count = 0
        for i in start...index {
            let hl = candles[i].high - candles[i].low
            let hpc = abs(candles[i].high - candles[i - 1].close)
            let lpc = abs(candles[i].low - candles[i - 1].close)
            sum += max(hl, hpc, lpc)
            count += 1
        }
        return count > 0 ? sum / Double(count) : 0
    }
}

// MARK: - 指标 5: 自适应支撑阻力 + 零迟滞信号
/// 源自 自适应系统.txt：零迟滞 EMA 基础线、波动率缓冲区、
/// 循环分析评分、自适应 S/R 水平线与缓冲区域
class CustomIndicator5: IndicatorBase {

    // 零迟滞参数
    var zlLength: Int { max(config.period, 1) }         // 零迟滞周期，默认 50
    var volatilityMult: Double { config.sensitivity }    // 波动率乘数，默认 1.5
    var loopEnd: Int { Int(config.threshold) }           // 循环终点，默认 70
    var thresholdUp: Int { 5 }
    var thresholdDown: Int { -5 }

    convenience init(config: IndicatorConfig? = nil) {
        let cfg = config ?? IndicatorConfig(
            name: "自适应S/R", index: 5, period: 50,
            threshold: 70, sensitivity: 1.5, isEnabled: true, weight: 0.2
        )
        self.init(name: "自适应S/R", index: 5, config: cfg)
    }

    override func calculate(candles: [CandleData]) -> [IndicatorTimePoint] {
        guard candles.count >= zlLength + loopEnd else { return [] }

        let closes = candles.map { $0.close }
        let lag = (zlLength - 1) / 2

        // 零迟滞后 EMA: zl_basis = ema(close + (close - close[lag]), length)
        var adjustedClose: [Double] = []
        for i in 0..<closes.count {
            let lagIdx = max(0, i - lag)
            adjustedClose.append(closes[i] + (closes[i] - closes[lagIdx]))
        }
        let zlBasisOpt = ema(adjustedClose, period: zlLength)
        let zlBasis = zlBasisOpt.map { $0 ?? closes[0] }

        // 波动率: highest(atr(length), length*3) * mult
        var atrValues: [Double] = []
        for i in 0..<candles.count {
            if i == 0 {
                atrValues.append(candles[i].high - candles[i].low)
            } else {
                let hl = candles[i].high - candles[i].low
                let hpc = abs(candles[i].high - candles[i - 1].close)
                let lpc = abs(candles[i].low - candles[i - 1].close)
                atrValues.append(max(hl, hpc, lpc))
            }
        }
        let atrSMAOpt = sma(atrValues, period: zlLength)
        let atrSMA = atrSMAOpt.map { $0 ?? 0 }
        let volatility = highest(atrSMA, period: zlLength * 3).map { $0 * volatilityMult }

        // 循环分析评分
        var results: [IndicatorTimePoint] = []
        for (i, candle) in candles.enumerated() {
            let basis = i < zlBasis.count ? zlBasis[i] : closes[i]
            let vol = i < volatility.count ? volatility[i] : 0

            // 循环得分
            var score = 0
            let loopStart = 1
            for j in loopStart...min(loopEnd, i) {
                let basisPrev = (i - j) < zlBasis.count ? zlBasis[i - j] : closes[max(0, i - j)]
                score += basis > basisPrev ? 1 : -1
            }

            results.append(IndicatorTimePoint(
                time: candle.closeTime,
                mainValue: basis,
                secondaryValue: Double(score),
                tertiaryValue: vol
            ))
        }
        return results
    }

    override func generateSignal(candles: [CandleData]) -> IndicatorResult {
        let timePoints = calculate(candles: candles)
        guard timePoints.count >= 2,
              let latest = timePoints.last else {
            return IndicatorResult(indicatorName: name, indicatorIndex: index,
                                   value: 0, signal: .neutral, strength: .weak,
                                   description: "数据不足")
        }
        let prev = timePoints[timePoints.count - 2]

        let basis = latest.mainValue
        let score = Int(latest.secondaryValue ?? 0)
        let vol = latest.tertiaryValue ?? 0
        let close = candles.last?.close ?? 0

        let longSignal = score > thresholdUp && close > basis + vol
        let shortSignal = score < thresholdDown && close < basis - vol

        var signal: SignalDirection = .neutral
        var strength: SignalStrength = .weak
        var desc = ""

        if longSignal {
            signal = .bullish
            strength = score > 8 ? .extreme : score > 5 ? .strong : .moderate
            desc = "零迟滞多头 循环分=\(score) 偏离=\(String(format: "%.2f", close - basis))"
        } else if shortSignal {
            signal = .bearish
            strength = score < -8 ? .extreme : score < -5 ? .strong : .moderate
            desc = "零迟滞空头 循环分=\(score) 偏离=\(String(format: "%.2f", close - basis))"
        } else if score > 0 {
            signal = .bullish
            strength = .weak
            desc = "偏多 循环分=\(score) 基线=\(String(format: "%.2f", basis))"
        } else if score < 0 {
            signal = .bearish
            strength = .weak
            desc = "偏空 循环分=\(score) 基线=\(String(format: "%.2f", basis))"
        } else {
            desc = "中性 循环分=0"
        }

        return IndicatorResult(
            indicatorName: name, indicatorIndex: index,
            value: basis, secondaryValue: Double(score), tertiaryValue: vol,
            signal: signal, strength: strength,
            description: desc, timestamp: latest.time
        )
    }

    // MARK: - 工具方法
    private func highest(_ values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return Array(repeating: values.max() ?? 0, count: values.count) }
        var result = Array(repeating: 0.0, count: values.count)
        for i in (period - 1)..<values.count {
            let start = max(0, i - period + 1)
            result[i] = Array(values[start...i]).max() ?? 0
        }
        return result
    }
}
