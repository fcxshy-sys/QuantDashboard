import Foundation
import Combine

class TradeJournalManager: ObservableObject {
    static let shared = TradeJournalManager()
    
    @Published var records: [TradeRecord] = []
    
    private let defaults = UserDefaults.standard
    private let key = "trade_journal"
    
    private init() { load() }
    
    func addRecord(_ record: TradeRecord) {
        records.insert(record, at: 0)
        save()
    }
    
    func closeRecord(id: UUID, exitPrice: Double) {
        if let idx = records.firstIndex(where: { $0.id == id }) {
            records[idx].exitPrice = exitPrice
            records[idx].exitDate = Date()
            save()
        }
    }
    
    func deleteRecord(_ record: TradeRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }
    
    var openRecords: [TradeRecord] { records.filter { $0.isOpen } }
    var closedRecords: [TradeRecord] { records.filter { !$0.isOpen } }
    
    var totalProfitLoss: Double {
        closedRecords.compactMap { $0.profitLoss }.reduce(0, +)
    }
    
    var overallWinRate: Double {
        let closed = closedRecords
        guard !closed.isEmpty else { return 0 }
        let wins = closed.filter { ($0.profitLoss ?? 0) > 0 }.count
        return Double(wins) / Double(closed.count) * 100
    }
    
    var todayRecords: [TradeRecord] {
        let cal = Calendar.current
        return records.filter { cal.isDateInToday($0.entryDate) }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
    
    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TradeRecord].self, from: data) else { return }
        records = decoded
    }
}
