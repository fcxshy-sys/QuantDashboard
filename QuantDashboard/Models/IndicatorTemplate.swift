// IndicatorTemplate.swift - 指标组合模板
import Foundation

struct IndicatorTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var configs: [IndicatorConfig]
    var createdAt: Date
    var isDefault: Bool
    
    init(name: String, configs: [IndicatorConfig], isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.configs = configs
        self.createdAt = Date()
        self.isDefault = isDefault
    }
}
