// ============================================================
// ContentView.swift
// QuantDashboard - 主导航容器
// ============================================================

import SwiftUI

// MARK: - 主视图容器
struct ContentView: View {

    @StateObject private var marketVM = MarketViewModel()
    @StateObject private var indicatorVM = IndicatorViewModel()

    @State private var selectedTab: Tab = .dashboard
    @State private var showAssetPicker = false

    enum Tab: String, CaseIterable {
        case dashboard = "看板"
        case chart = "图表"
        case indicators = "指标"
        case settings = "设置"
    }

    var body: some View {
        ZStack {
            // 底层背景
            LiquidGlassTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航胶囊
                topNavigationCapsule

                // 主内容区
                TabView(selection: $selectedTab) {
                    DashboardView(marketVM: marketVM, indicatorVM: indicatorVM)
                        .tag(Tab.dashboard)

                    KLineChartView(marketVM: marketVM, indicatorVM: indicatorVM)
                        .tag(Tab.chart)

                    IndicatorPanelView(indicatorVM: indicatorVM)
                        .tag(Tab.indicators)

                    SettingsView(indicatorVM: indicatorVM)
                        .tag(Tab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 底部 Tab 栏
                bottomTabBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            LocalAlertManager.shared.requestPermission()
            marketVM.start()
        }
        .onDisappear {
            marketVM.stop()
        }
    }

    // MARK: - 顶部导航胶囊
    private var topNavigationCapsule: some View {
        HStack(spacing: 12) {
            // 资产切换按钮
            Button {
                showAssetPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(marketVM.currentAsset.themeColor)
                        .frame(width: 8, height: 8)
                    Text(marketVM.currentAsset.rawValue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(LiquidGlassTheme.primaryText)
            }

            Spacer()

            // 连接状态
            HStack(spacing: 4) {
                Circle()
                    .fill(marketVM.connectionStatus.contains("已连接")
                        ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(marketVM.connectionStatus)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(LiquidGlassTheme.tertiaryText)

            // 网络延迟
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                Text("\(Int(marketVM.latency))ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(marketVM.latency < 100
                ? LiquidGlassTheme.bullishAccent
                : LiquidGlassTheme.bearishAccent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 0, fillOpacity: 0.03)
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(selectedAsset: $marketVM.currentAsset) { asset in
                marketVM.switchAsset(to: asset)
            }
        }
    }

    // MARK: - 底部 Tab 栏
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab
                        ? LiquidGlassTheme.primaryText
                        : LiquidGlassTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .liquidGlass(cornerRadius: 0, fillOpacity: 0.03)
    }

    private func iconName(for tab: Tab) -> String {
        switch tab {
        case .dashboard: return "chart.bar.fill"
        case .chart: return "chart.xyaxis.line"
        case .indicators: return "waveform.path.ecg"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - 资产选择器弹窗
struct AssetPickerSheet: View {

    @Binding var selectedAsset: TradeAsset
    let onSelect: (TradeAsset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("贵金属") {
                    ForEach([TradeAsset.xauUSD]) { asset in
                        assetRow(asset)
                    }
                }
                Section("加密货币") {
                    ForEach(TradeAsset.allCases.filter { $0.assetType == .crypto }) { asset in
                        assetRow(asset)
                    }
                }
            }
            .navigationTitle("选择资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func assetRow(_ asset: TradeAsset) -> some View {
        Button {
            selectedAsset = asset
            onSelect(asset)
            dismiss()
        } label: {
            HStack {
                Circle()
                    .fill(asset.themeColor)
                    .frame(width: 10, height: 10)
                Text(asset.rawValue)
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                Spacer()
                if asset == selectedAsset {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LiquidGlassTheme.bullishAccent)
                }
            }
        }
        .listRowBackground(Color.black.opacity(0.3))
    }
}
