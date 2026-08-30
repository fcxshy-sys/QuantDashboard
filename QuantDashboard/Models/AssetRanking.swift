// AssetRanking.swift - 资产排行数据
import Foundation

struct AssetRanking: Identifiable {
    let id = UUID()
    let asset: TradeAsset
    var price: Double = 0
    var changePercent: Double = 0
    var volume24h: Double = 0
    var isUp: Bool { changePercent >= 0 }
}
