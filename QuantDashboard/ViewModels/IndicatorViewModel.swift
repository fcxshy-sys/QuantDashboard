// ============================================================
// IndicatorViewModel.swift
// QuantDashboard - 指标视图模型
// ============================================================

import Foundation
import Combine

// MARK: - 指标视图模型
/// 管理 5 个指标的计算状态、参数配置和结果展示
class IndicatorViewModel: ObservableObject {

    // MARK: - Published 状态
    @Published var indicatorResults: [Int: IndicatorResult] = [:]
    @Published var indicatorTimeSeries: [Int: [IndicatorTimePoint]] = [:]
    @Published var radarScore: RadarScore?
    @Published var alertHistory: [AlertEvent] = []
    @Published var configs: [IndicatorConfig] = []

    // MARK: - 组件引用
    private let indicatorEngine = IndicatorEngine.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    init() {
        setupBindings()
        loadConfigs()
    }

    // MARK: - 绑定指标引擎
    private func setupBindings() {
        indicatorEngine.$latestResults
            .receive(on: DispatchQueue.main)
            .assign(to: &$indicatorResults)

        indicatorEngine.$timeSeries
            .receive(on: DispatchQueue.main)
            .assign(to: &$indicatorTimeSeries)

        indicatorEngine.$radarScore
            .receive(on: DispatchQueue.main)
            .assign(to: &$radarScore)

        indicatorEngine.radarEngine.$alertHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$alertHistory)
    }

    // MARK: - 加载配置
    private func loadConfigs() {
        configs = indicatorEngine.allConfigs()
    }

    // MARK: - 更新指标参数
    func updateConfig(for index: Int, period: Int? = nil,
                      threshold: Double? = nil, sensitivity: Double? = nil,
                      isEnabled: Bool? = nil, weight: Double? = nil) {
        guard index >= 0 && index < configs.count else { return }
        var config = configs[index]
        if let p = period { config.period = p }
        if let t = threshold { config.threshold = t }
        if let s = sensitivity { config.sensitivity = s }
        if let e = isEnabled { config.isEnabled = e }
        if let w = weight { config.weight = w }

        configs[index] = config
        indicatorEngine.updateConfig(for: index, config: config)
    }

    // MARK: - 获取指标结果（安全访问）
    func result(for index: Int) -> IndicatorResult? {
        indicatorResults[index]
    }

    // MARK: - 获取指标时间序列（安全访问）
    func timeSeries(for index: Int) -> [IndicatorTimePoint] {
        indicatorTimeSeries[index] ?? []
    }

    // MARK: - 清除告警历史
    func clearAlerts() {
        alertHistory.removeAll()
    }
}
