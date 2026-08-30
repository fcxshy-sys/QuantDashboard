import Foundation
import Combine

class SignalStatsManager: ObservableObject {
    static let shared = SignalStatsManager()
    
    @Published var stats: [SignalStats] = []
    @Published var snapshots: [DailySnapshot] = []
    
    private var lastSignalValues: [Int: SignalDirection] = [:]
    private let defaults = UserDefaults.standard
    
    private init() { load() }
    
    func recordSignals(_ results: [Int: IndicatorResult], candles: [CandleData]) {
        guard candles.count >= 2 else { return }
        let currentPrice = candles.last!.close
        let previousPrice = candles[candles.count - 2].close
        let priceUp = currentPrice > previousPrice
        
        for (index, result) in results {
            if let lastDir = lastSignalValues[index], lastDir != result.signal {
                updateStats(index: index, direction: result.signal, wasCorrect: priceUp)
            }
            lastSignalValues[index] = result.signal
        }
    }
    
    func takeSnapshot(asset: TradeAsset, price: Double, radarScore: Double, signals: [Int: String]) {
        let snap = DailySnapshot(date: Date(), asset: asset, price: price, radarScore: radarScore, signals: signals, imageData: nil)
        snapshots.append(snap)
        if snapshots.count > 365 { snapshots.removeFirst(snapshots.count - 365) }
        save()
    }
    
    private func updateStats(index: Int, direction: SignalDirection, wasCorrect: Bool) {
        if let idx = stats.firstIndex(where: { $0.indicatorIndex == index }) {
            stats[idx].totalSignals += 1
            if direction == .bullish { stats[idx].bullishSignals += 1 }
            else if direction == .bearish { stats[idx].bearishSignals += 1 }
            let isCorrect = (direction == .bullish && wasCorrect) || (direction == .bearish && !wasCorrect)
            if isCorrect { stats[idx].correctPredictions += 1 }
        } else {
            let name = ["", "MACD+RSI Pro", "巴特沃斯谱线", "MTF矩阵", "ORB模型", "自适应S/R"][min(index, 5)]
            var s = SignalStats(indicatorIndex: index, indicatorName: name)
            s.totalSignals = 1
            if direction == .bullish { s.bullishSignals = 1 }
            else if direction == .bearish { s.bearishSignals = 1 }
            let isCorrect = (direction == .bullish && wasCorrect) || (direction == .bearish && !wasCorrect)
            if isCorrect { s.correctPredictions = 1 }
            stats.append(s)
        }
        save()
    }
    
    func resetStats() {
        stats.removeAll()
        lastSignalValues.removeAll()
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "signal_stats") }
        if let data = try? JSONEncoder().encode(snapshots) { defaults.set(data, forKey: "daily_snapshots") }
    }
    
    private func load() {
        if let data = defaults.data(forKey: "signal_stats"),
           let d = try? JSONDecoder().decode([SignalStats].self, from: data) { stats = d }
        if let data = defaults.data(forKey: "daily_snapshots"),
           let d = try? JSONDecoder().decode([DailySnapshot].self, from: data) { snapshots = d }
    }
}
