// BacktestResult.swift - 回测结果模型
import Foundation

struct BacktestResult: Identifiable {
    let id = UUID()
    let asset: TradeAsset
    let interval: KLineInterval
    let startDate: Date
    let endDate: Date
    let totalTrades: Int
    let winRate: Double
    let totalReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double
    let trades: [BacktestTrade]
    let equityCurve: [Double]
}

struct BacktestTrade: Identifiable {
    let id = UUID()
    let side: TradeSide
    let entryPrice: Double
    let exitPrice: Double
    let entryIndex: Int
    let exitIndex: Int
    let signalName: String
    var profitPercent: Double { (exitPrice - entryPrice) / entryPrice * (side == .long ? 1 : -1) * 100 }
}
