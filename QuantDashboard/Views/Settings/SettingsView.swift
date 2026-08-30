import SwiftUI

struct SettingsView: View {
    @ObservedObject var indicatorVM: IndicatorViewModel

    @State private var editingIndex: Int? = nil
    @State private var editPeriod: Double = 14
    @State private var editThreshold: Double = 70
    @State private var editSensitivity: Double = 1.0
    @State private var editWeight: Double = 0.2

    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var journalManager = TradeJournalManager.shared
    @StateObject private var statsManager = SignalStatsManager.shared
    @State private var showClearConfirm = false
    @State private var showResetIndicatorConfirm = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    Text("设置")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                themeCard

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

                resonanceThresholdCard
                dataManagementCard
                aboutCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var themeCard: some View {
        GlassCard(title: "外观", icon: "paintbrush") {
            VStack(spacing: 10) {
                HStack {
                    Text("深色模式")
                        .font(.system(size: 14))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { themeManager.isDarkMode },
                        set: { _ in themeManager.toggle() }
                    ))
                    .tint(LiquidGlassTheme.neutralAccent)
                    .labelsHidden()
                }
            }
        }
    }

    private func saveConfig(for index: Int) {
        indicatorVM.updateConfig(
            for: index,
            period: Int(editPeriod),
            threshold: editThreshold,
            sensitivity: editSensitivity,
            weight: editWeight
        )
    }

    private func loadConfig(for index: Int) {
        guard let config = indicatorVM.configs[safe: index] else { return }
        editPeriod = Double(config.period)
        editThreshold = config.threshold
        editSensitivity = config.sensitivity
        editWeight = config.weight
    }

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

    private var dataManagementCard: some View {
        GlassCard(title: "数据管理", icon: "externaldrive") {
            VStack(spacing: 10) {
                dataRow(label: "交易记录", count: "\(journalManager.records.count) 条", icon: "list.clipboard")
                dataRow(label: "信号统计", count: "\(statsManager.stats.count) 个指标", icon: "chart.pie")
                dataRow(label: "每日快照", count: "\(statsManager.snapshots.count) 个", icon: "camera")
                Divider().background(Color.white.opacity(0.06))

                HStack(spacing: 10) {
                    Button {
                        showResetIndicatorConfirm = true
                    } label: {
                        Text("重置指标参数")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LiquidGlassTheme.bearishAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(LiquidGlassTheme.bearishAccent.opacity(0.1)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showClearConfirm = true
                    } label: {
                        Text("清除所有数据")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("确认重置指标参数?", isPresented: $showResetIndicatorConfirm) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                statsManager.resetStats()
            }
        } message: {
            Text("将清除所有指标统计数据")
        }
        .alert("确认清除所有数据?", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                statsManager.resetStats()
                statsManager.snapshots.removeAll()
                journalManager.records.removeAll()
                UserDefaults.standard.removeObject(forKey: "price_alerts")
                UserDefaults.standard.removeObject(forKey: "trade_journal")
                UserDefaults.standard.removeObject(forKey: "signal_stats")
                UserDefaults.standard.removeObject(forKey: "daily_snapshots")
            }
        } message: {
            Text("此操作不可撤销，将清除交易记录、信号统计、每日快照和价格预警")
        }
    }

    private func dataRow(label: String, count: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(count)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.primaryText)
        }
    }

    private var aboutCard: some View {
        GlassCard(title: "关于", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("9y看板")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Text("量化交易")
                        .font(.system(size: 14))
                        .foregroundStyle(LiquidGlassTheme.neutralAccent)
                }

                Group {
                    aboutRow("版本", "2.0.0")
                    aboutRow("构建", "2026.08.30")
                    aboutRow("数据源", "Gate.io WebSocket + REST")
                    aboutRow("引擎", "5 大核心指标 · 多空共振雷达")
                    aboutRow("部署", "TrollStore 侧载")
                }

                Divider().background(Color.white.opacity(0.06))

                aboutRow("支持", "BTC · ETH · SOL · BNB · XRP · XAU")
                aboutRow("协议", "MIT License")

                Text("本工具仅供学习研究使用，不构成任何投资建议")
                    .font(.system(size: 10))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
        }
    }
}

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

                    Toggle("", isOn: Binding(
                        get: { config?.isEnabled ?? true },
                        set: { _ in onToggle() }
                    ))
                    .tint(LiquidGlassTheme.bullishAccent)
                    .labelsHidden()

                    Button(action: onEdit) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(isEditing
                                ? LiquidGlassTheme.bullishAccent
                                : LiquidGlassTheme.neutralAccent)
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    Divider().background(Color.white.opacity(0.06))
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

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
