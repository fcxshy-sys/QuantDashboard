// SignalStats.swift - 信号统计模型
import Foundation

struct SignalStats: Identifiable {
    let id = UUID()
    let indicatorIndex: Int
    let indicatorName: String
    var totalSignals: Int = 0
    var bullishSignals: Int = 0
    var bearishSignals: Int = 0
    var correctPredictions: Int = 0
    
    var accuracy: Double {
        guard totalSignals > 0 else { return 0 }
        return Double(correctPredictions) / Double(totalSignals) * 100
    }
    
    var bullishAccuracy: Double {
        guard bullishSignals > 0 else { return 0 }
        return Double(correctPredictions) / Double(totalSignals) * 100
    }
}

struct DailySnapshot: Identifiable, Codable {
    let id: UUID
    let date: Date
    let asset: TradeAsset
    let price: Double
    let radarScore: Double
    let signals: [Int: String]  // 指标编号 -> 信号描述
    let imageData: Data?
}
