import Foundation
import Combine
import UIKit

class DailySnapshotService: ObservableObject {
    static let shared = DailySnapshotService()
    
    @Published var lastSnapshotDate: Date?
    
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    
    private init() {
        lastSnapshotDate = defaults.object(forKey: "last_snapshot_date") as? Date
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndSnapshot()
        }
    }
    
    func stopMonitoring() { timer?.invalidate() }
    
    func takeManualSnapshot() -> Data? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return nil }
        let layer = window.layer
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { ctx in layer.render(in: ctx.cgContext) }.pngData()
    }
    
    private func checkAndSnapshot() {
        let cal = Calendar.current
        guard let last = lastSnapshotDate, cal.isDate(last, inSameDayAs: Date()) else {
            lastSnapshotDate = Date()
            defaults.set(lastSnapshotDate, forKey: "last_snapshot_date")
        }
    }
}
