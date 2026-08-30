import Foundation
import UIKit
import UserNotifications
import Combine

class PriceAlertManager: ObservableObject {
    static let shared = PriceAlertManager()
    
    @Published var alerts: [PriceAlert] = []
    
    private var checkTimer: Timer?
    private let defaults = UserDefaults.standard
    private let key = "price_alerts"
    
    private init() {
        load()
    }
    
    func add(_ alert: PriceAlert) {
        alerts.append(alert)
        save()
    }
    
    func remove(_ alert: PriceAlert) {
        alerts.removeAll { $0.id == alert.id }
        save()
    }
    
    func toggle(_ alert: PriceAlert) {
        if let idx = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[idx].isEnabled.toggle()
            save()
        }
    }
    
    func checkPrices(pipeline: DataPipeline) {
        for i in alerts.indices {
            guard alerts[i].isEnabled, alerts[i].triggeredAt == nil else { continue }
            let price = pipeline.latestPrice
            if alerts[i].checkPrice(price) {
                alerts[i].triggeredAt = Date()
                sendNotification(alert: alerts[i], currentPrice: price)
            }
        }
        save()
    }
    
    private func sendNotification(alert: PriceAlert, currentPrice: Double) {
        let content = UNMutableNotificationContent()
        content.title = "9y看板 价格预警"
        content.body = "\(alert.message)\n当前: $\(String(format: "%.2f", currentPrice))"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: key)
        }
    }
    
    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) else { return }
        alerts = decoded
    }
}
