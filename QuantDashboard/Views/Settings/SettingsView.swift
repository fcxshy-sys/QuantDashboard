// ============================================================
// SettingsView.swift
// QuantDashboard - 设置视图
// ============================================================

import SwiftUI

// MARK: - 设置视图
struct SettingsView: View {

    @ObservedObject var indicatorVM: IndicatorViewModel

    @State private var editingIndex: Int? = nil
    @State private var editPeriod: Double = 14
    @State private var editThreshold: Double = 70
    @State private var editSensitivity: Double = 1.0
    @State private var editWeight: Double = 0.2

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Text("指标配置")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // 指标参数配置卡片
                ForEach(1...5, id: \.self) { index in
                    IndicatorConfigCard(
                        index: index,
                        config: indicatorVM.configs[safe: index - 1],
                        isEditing: editingIndex == index,
                        editPeriod: $editPeriod,
                        editThreshold: $editThreshold,
                        editSensitivity: $editSensitivity,
                        editWeight: $editWeight,
                        onToggle: {
                            indicatorVM.updateConfig(
                                for: index - 1,
                                isEnabled: !(indicatorVM.configs[safe: index - 1]?.isEnabled ?? true)
                            )
                        },
                        onEdit: {
                            withAnimation(.spring(response: 0.3)) {
                                if editingIndex == index {
                                    saveConfig(for: index - 1)
                                    editingIndex = nil
                                } else {
                                    loadConfig(for: index - 1)
                                    editingIndex = index
                                }
                            }
                        }
                    )
                }

                // 共振阈值设置
                resonanceThresholdCard

                // 关于信息
                aboutCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - 保存配置
    private func saveConfig(for index: Int) {
        indicatorVM.updateConfig(
            for: index,
            period: Int(editPeriod),
            threshold: editThreshold,
            sensitivity: editSensitivity,
            weight: editWeight
        )
    }

    // MARK: - 加载配置到编辑器
    private func loadConfig(for index: Int) {
        guard let config = indicatorVM.configs[safe: index] else { return }
        editPeriod = Double(config.period)
        editThreshold = config.threshold
        editSensitivity = config.sensitivity
        editWeight = config.weight
    }

    // MARK: - 共振阈值卡片
    private var resonanceThresholdCard: some View {
        GlassCard(title: "共振阈值", icon: "target") {
            VStack(spacing: 12) {
                Text("当 \(Int(editThreshold)) 个或以上指标同向时触发强信号告警")
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("阈值")
                        .font(.system(size: 13))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Slider(value: $editThreshold, in: 2...5, step: 1)
                        .tint(LiquidGlassTheme.neutralAccent)
                    Text("\(Int(editThreshold))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                        .frame(width: 20)
                }
            }
        }
    }

    // MARK: - 关于信息
    private var aboutCard: some View {
        GlassCard(title: "关于", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("QuantDashboard 量化看板")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                Text("版本 1.0.0")
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                Text("TrollStore 免签部署版本")
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
        }
    }
}

// MARK: - 指标配置卡片
struct IndicatorConfigCard: View {

    let index: Int
    let config: IndicatorConfig?
    let isEditing: Bool
    @Binding var editPeriod: Double
    @Binding var editThreshold: Double
    @Binding var editSensitivity: Double
    @Binding var editWeight: Double
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        GlassCard(direction: .neutral) {
            VStack(spacing: 10) {
                // 顶行
                HStack {
                    ZStack {
                        Circle()
                            .fill(LiquidGlassTheme.neutralAccent.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("M\(index)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config?.name ?? "指标 \(index)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LiquidGlassTheme.primaryText)
                        Text("周期: \(config?.period ?? 14) | 权重: \(String(format: "%.0f", (config?.weight ?? 0.2) * 100))%")
                            .font(.system(size: 10))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    }

                    Spacer()

                    // 开关
                    Toggle("", isOn: Binding(
                        get: { config?.isEnabled ?? true },
                        set: { _ in onToggle() }
                    ))
                    .tint(LiquidGlassTheme.bullishAccent)
                    .labelsHidden()

                    // 编辑按钮
                    Button(action: onEdit) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(isEditing
                                ? LiquidGlassTheme.bullishAccent
                                : LiquidGlassTheme.neutralAccent)
                    }
                    .buttonStyle(.plain)
                }

                // 编辑滑块区
                if isEditing {
                    Divider()
                        .background(Color.white.opacity(0.06))

                    VStack(spacing: 10) {
                        sliderRow(label: "周期", value: $editPeriod, range: 5...100, step: 1, format: "%.0f")
                        sliderRow(label: "阈值", value: $editThreshold, range: 10...100, step: 5, format: "%.0f")
                        sliderRow(label: "敏感度", value: $editSensitivity, range: 0.1...3.0, step: 0.1, format: "%.1f")
                        sliderRow(label: "权重", value: $editWeight, range: 0.05...1.0, step: 0.05, format: "%.0f%%", multiplier: 100)
                    }
                }
            }
        }
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, format: String, multiplier: Double = 1.0) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
                .frame(width: 40, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .tint(LiquidGlassTheme.neutralAccent)
            Text(String(format: format, value.wrappedValue * multiplier))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(LiquidGlassTheme.primaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Array 安全下标扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
