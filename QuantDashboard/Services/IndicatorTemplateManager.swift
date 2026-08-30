import Foundation
import Combine

class IndicatorTemplateManager: ObservableObject {
    static let shared = IndicatorTemplateManager()
    
    @Published var templates: [IndicatorTemplate] = []
    
    private let defaults = UserDefaults.standard
    private let key = "indicator_templates"
    
    private init() {
        load()
        if templates.isEmpty {
            templates = defaultTemplates()
            save()
        }
    }
    
    func saveTemplate(name: String, configs: [IndicatorConfig]) {
        let t = IndicatorTemplate(name: name, configs: configs)
        templates.append(t)
        save()
    }
    
    func deleteTemplate(_ template: IndicatorTemplate) {
        templates.removeAll { $0.id == template.id }
        save()
    }
    
    func applyTemplate(_ template: IndicatorTemplate, engine: IndicatorEngine) {
        for (i, config) in template.configs.enumerated() {
            engine.updateConfig(for: i, config: config)
        }
    }
    
    private func defaultTemplates() -> [IndicatorTemplate] {
        [
            IndicatorTemplate(name: "默认", configs: [
                IndicatorConfig(name: "MACD+RSI Pro", index: 1, period: 12, threshold: 26, sensitivity: 1.0, isEnabled: true, weight: 0.2),
                IndicatorConfig(name: "巴特沃斯谱线", index: 2, period: 20, threshold: 32, sensitivity: 0.55, isEnabled: true, weight: 0.2),
                IndicatorConfig(name: "MTF矩阵", index: 3, period: 9, threshold: 55, sensitivity: 1.0, isEnabled: true, weight: 0.2),
                IndicatorConfig(name: "ORB模型", index: 4, period: 14, threshold: 70, sensitivity: 1.0, isEnabled: true, weight: 0.2),
                IndicatorConfig(name: "自适应S/R", index: 5, period: 50, threshold: 70, sensitivity: 1.5, isEnabled: true, weight: 0.2)
            ], isDefault: true),
            IndicatorTemplate(name: "短线快攻", configs: [
                IndicatorConfig(name: "MACD+RSI Pro", index: 1, period: 8, threshold: 17, sensitivity: 1.5, isEnabled: true, weight: 0.3),
                IndicatorConfig(name: "巴特沃斯谱线", index: 2, period: 10, threshold: 20, sensitivity: 0.8, isEnabled: true, weight: 0.15),
                IndicatorConfig(name: "MTF矩阵", index: 3, period: 5, threshold: 35, sensitivity: 1.2, isEnabled: true, weight: 0.2),
                IndicatorConfig(name: "ORB模型", index: 4, period: 7, threshold: 50, sensitivity: 1.5, isEnabled: true, weight: 0.25),
                IndicatorConfig(name: "自适应S/R", index: 5, period: 30, threshold: 50, sensitivity: 2.0, isEnabled: true, weight: 0.1)
            ]),
            IndicatorTemplate(name: "趋势跟踪", configs: [
                IndicatorConfig(name: "MACD+RSI Pro", index: 1, period: 15, threshold: 30, sensitivity: 0.8, isEnabled: true, weight: 0.15),
                IndicatorConfig(name: "巴特沃斯谱线", index: 2, period: 30, threshold: 50, sensitivity: 0.4, isEnabled: true, weight: 0.25),
                IndicatorConfig(name: "MTF矩阵", index: 3, period: 12, threshold: 70, sensitivity: 0.8, isEnabled: true, weight: 0.3),
                IndicatorConfig(name: "ORB模型", index: 4, period: 20, threshold: 80, sensitivity: 0.8, isEnabled: true, weight: 0.1),
                IndicatorConfig(name: "自适应S/R", index: 5, period: 60, threshold: 80, sensitivity: 1.2, isEnabled: true, weight: 0.2)
            ])
        ]
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(templates) {
            defaults.set(data, forKey: key)
        }
    }
    
    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([IndicatorTemplate].self, from: data) else { return }
        templates = decoded
    }
}
