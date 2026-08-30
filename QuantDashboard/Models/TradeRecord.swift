// TradeRecord.swift - 交易记录模型
import Foundation

struct TradeRecord: Identifiable, Codable {
    let id: UUID
    var asset: TradeAsset
    var side: TradeSide
    var entryPrice: Double
    var exitPrice: Double?
    var quantity: Double
    var entryDate: Date
    var exitDate: Date?
    var notes: String
    var indicatorSignals: [String]  // 入场时的指标信号
    
    var profitLoss: Double? {
        guard let exit = exitPrice else { return nil }
        let mult = side == .long ? 1.0 : -1.0
        return (exit - entryPrice) * quantity * mult
    }
    
    var profitLossPercent: Double? {
        guard let exit = exitPrice else { return nil }
        let mult = side == .long ? 1.0 : -1.0
        return (exit - entryPrice) / entryPrice * mult * 100
    }
    
    var isOpen: Bool { exitPrice == nil }
    
    init(asset: TradeAsset, side: TradeSide, entryPrice: Double, quantity: Double, notes: String = "", indicatorSignals: [String] = []) {
        self.id = UUID()
        self.asset = asset
        self.side = side
        self.entryPrice = entryPrice
        self.quantity = quantity
        self.entryDate = Date()
        self.notes = notes
        self.indicatorSignals = indicatorSignals
    }
}

enum TradeSide: String, Codable, CaseIterable {
    case long = "做多"
    case short = "做空"
}
