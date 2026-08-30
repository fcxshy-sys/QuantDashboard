import Foundation

struct SignalStats: Identifiable, Codable {
    let id: UUID
    let indicatorIndex: Int
    let indicatorName: String
    var totalSignals: Int = 0
    var bullishSignals: Int = 0
    var bearishSignals: Int = 0
    var correctPredictions: Int = 0

    init(indicatorIndex: Int, indicatorName: String) {
        self.id = UUID()
        self.indicatorIndex = indicatorIndex
        self.indicatorName = indicatorName
    }

    var accuracy: Double {
        guard totalSignals > 0 else { return 0 }
        return Double(correctPredictions) / Double(totalSignals) * 100
    }
}

struct DailySnapshot: Identifiable, Codable {
    let id: UUID
    let date: Date
    let asset: String
    let price: Double
    let radarScore: Double
    let signals: [String: String]
    let imageData: Data?

    init(id: UUID = UUID(), date: Date, asset: TradeAsset, price: Double, radarScore: Double, signals: [Int: String], imageData: Data?) {
        self.id = id
        self.date = date
        self.asset = asset.rawValue
        self.price = price
        self.radarScore = radarScore
        self.signals = Dictionary(uniqueKeysWithValues: signals.map { (String($0.key), $0.value) })
        self.imageData = imageData
    }
}
