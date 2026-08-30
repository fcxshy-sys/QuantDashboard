// PriceAlert.swift - 价格预警模型
import Foundation

struct PriceAlert: Identifiable, Codable {
    let id: UUID
    var asset: TradeAsset
    var targetPrice: Double
    var isAbove: Bool  // true=高于触发, false=低于触发
    var isEnabled: Bool
    var message: String
    let createdAt: Date
    var triggeredAt: Date?
    
    init(asset: TradeAsset, targetPrice: Double, isAbove: Bool, message: String = "") {
        self.id = UUID()
        self.asset = asset
        self.targetPrice = targetPrice
        self.isAbove = isAbove
        self.isEnabled = true
        self.message = message.isEmpty ? "\(asset.rawValue) \(isAbove ? "突破" : "跌破") \(targetPrice)" : message
        self.createdAt = Date()
        self.triggeredAt = nil
    }
    
    func checkPrice(_ currentPrice: Double) -> Bool {
        guard isEnabled, triggeredAt == nil else { return false }
        return isAbove ? currentPrice >= targetPrice : currentPrice <= targetPrice
    }
}
