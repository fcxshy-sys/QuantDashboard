import Foundation

class BacktestEngine {
    
    static func run(candles: [CandleData], asset: TradeAsset, interval: KLineInterval, configs: [IndicatorConfig]) -> BacktestResult {
        let engine = IndicatorEngine.shared
        for (i, config) in configs.enumerated() { engine.updateConfig(for: i, config: config) }
        
        var trades: [BacktestTrade] = []
        var equity = 10000.0
        var equityCurve: [Double] = []
        var inPosition = false
        var entryPrice = 0.0
        var entryIndex = 0
        var entrySide: TradeSide = .long
        var entrySignal = ""
        
        let lookback = 100
        
        for i in lookback..<candles.count {
            let slice = Array(candles[0...i])
            engine.computeAll(candles: slice, asset: asset)
            
            let results = engine.latestResults
            var bullishCount = 0
            var bearishCount = 0
            var signalNames: [String] = []
            
            for (_, result) in results {
                if result.signal == .bullish { bullishCount += 1; signalNames.append(result.indicatorName) }
                else if result.signal == .bearish { bearishCount += 1; signalNames.append(result.indicatorName) }
            }
            
            let price = candles[i].close
            
            if !inPosition {
                if bullishCount >= 3 {
                    inPosition = true; entryPrice = price; entryIndex = i
                    entrySide = .long; entrySignal = signalNames.joined(separator: "+")
                } else if bearishCount >= 3 {
                    inPosition = true; entryPrice = price; entryIndex = i
                    entrySide = .short; entrySignal = signalNames.joined(separator: "+")
                }
            } else {
                let shouldExit = (entrySide == .long && bearishCount >= 3) || (entrySide == .short && bullishCount >= 3) || (i - entryIndex >= 100)
                if shouldExit {
                    let mult: Double = entrySide == .long ? 1 : -1
                    let pnl = (price - entryPrice) * mult
                    equity += pnl * 100
                    trades.append(BacktestTrade(side: entrySide, entryPrice: entryPrice, exitPrice: price, entryIndex: entryIndex, exitIndex: i, signalName: entrySignal))
                    inPosition = false
                }
            }
            equityCurve.append(equity)
        }
        
        let wins = trades.filter { $0.profitPercent > 0 }.count
        let winRate = trades.isEmpty ? 0 : Double(wins) / Double(trades.count) * 100
        let totalReturn = equityCurve.last ?? 10000
        let returnPct = (totalReturn - 10000) / 10000 * 100
        
        var peak = 10000.0
        var maxDD = 0.0
        for e in equityCurve {
            peak = max(peak, e)
            let dd = (peak - e) / peak * 100
            maxDD = max(maxDD, dd)
        }
        
        let avgReturn = trades.isEmpty ? 0 : trades.map { $0.profitPercent }.reduce(0, +) / Double(trades.count)
        let stdDev = trades.isEmpty ? 0 : sqrt(trades.map { pow($0.profitPercent - avgReturn, 2) }.reduce(0, +) / Double(max(trades.count, 1)))
        let sharpe = stdDev > 0 ? avgReturn / stdDev : 0
        
        return BacktestResult(
            asset: asset, interval: interval,
            startDate: candles.first?.openTime ?? Date(),
            endDate: candles.last?.openTime ?? Date(),
            totalTrades: trades.count, winRate: winRate,
            totalReturn: returnPct, maxDrawdown: maxDD,
            sharpeRatio: sharpe, trades: trades,
            equityCurve: equityCurve
        )
    }
}
