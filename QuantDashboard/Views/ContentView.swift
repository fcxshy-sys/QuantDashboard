import SwiftUI

struct ContentView: View {

    @StateObject private var marketVM = MarketViewModel()
    @StateObject private var indicatorVM = IndicatorViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var selectedTab: Tab = .dashboard
    @State private var showAssetPicker = false
    @State private var showLandscape = false
    @State private var showAssetEditor = false
    @State private var selectedAssets: [TradeAsset] = TradeAsset.allCases.filter { $0.assetType == .crypto }
    @State private var selectedTool: ToolType?

    enum Tab: String, CaseIterable {
        case dashboard = "看板"
        case chart = "图表"
        case indicators = "指标"
        case tools = "工具"
        case settings = "设置"
    }

    enum ToolType: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case multiTimeframe = "多周期联动"
        case ranking = "排行榜"
        case priceAlerts = "价格预警"
        case depthChart = "深度图"
        case templates = "指标模板"
        case backtest = "策略回测"
        case signalStats = "信号统计"
        case tradeJournal = "交易记录"
        case snapshots = "每日快照"
        case calculator = "交易计算器"
        case converter = "汇率换算"
        case alertCenter = "通知中心"
        case performance = "绩效追踪"
        case assetDetail = "资产详情"
        case export = "数据导出"

        var icon: String {
            switch self {
            case .multiTimeframe: return "arrow.triangle.2.circlepath"
            case .ranking: return "chart.bar.fill"
            case .priceAlerts: return "bell.badge"
            case .depthChart: return "arrow.left.arrow.right"
            case .templates: return "doc.text"
            case .backtest: return "clock.arrow.circlepath"
            case .signalStats: return "chart.pie"
            case .tradeJournal: return "list.clipboard"
            case .snapshots: return "camera.metering.center.weighted"
            case .calculator: return "number.circle"
            case .converter: return "coloncurrencysign.circle"
            case .alertCenter: return "bell.circle"
            case .performance: return "chart.line.uptrend.xyaxis"
            case .assetDetail: return "info.circle"
            case .export: return "square.and.arrow.up"
            }
        }
    }

    var body: some View {
        ZStack {
            BackgroundImageView()
            LiquidGlassTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topNavigationCapsule

                TabView(selection: $selectedTab) {
                    DashboardView(marketVM: marketVM, indicatorVM: indicatorVM)
                        .tag(Tab.dashboard)

                    KLineChartView(marketVM: marketVM, indicatorVM: indicatorVM)
                        .tag(Tab.chart)

                    IndicatorPanelView(indicatorVM: indicatorVM)
                        .tag(Tab.indicators)

                    toolsGrid
                        .tag(Tab.tools)

                    SettingsView(indicatorVM: indicatorVM)
                        .tag(Tab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomTabBar
            }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            LocalAlertManager.shared.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                marketVM.start()
            }
        }
        .onDisappear { marketVM.stop() }
        .fullScreenCover(isPresented: $showLandscape) {
            LandscapeKLineView(marketVM: marketVM, indicatorVM: indicatorVM)
        }
        .sheet(isPresented: $showAssetEditor) {
            AssetEditorView(selectedAssets: $selectedAssets)
        }
        .sheet(item: $selectedTool) { tool in
            toolSheet(for: tool)
        }
    }

    // MARK: - 工具网格
    private var toolsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    Text("工具")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 20)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(ToolType.allCases, id: \.self) { tool in
                        Button { selectedTool = tool } label: {
                            GlassCard {
                                VStack(spacing: 8) {
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(LiquidGlassTheme.neutralAccent)
                                    Text(tool.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func toolSheet(for tool: ToolType) -> some View {
        NavigationView {
            Group {
                switch tool {
                case .multiTimeframe:
                    MultiTimeframePanelView(indicatorVM: indicatorVM, marketVM: marketVM)
                case .ranking:
                    RankingView(marketVM: marketVM)
                case .priceAlerts:
                    PriceAlertView(marketVM: marketVM)
                case .depthChart:
                    DepthChartView(asset: marketVM.currentAsset)
                case .templates:
                    TemplateView(indicatorVM: indicatorVM)
                case .backtest:
                    BacktestView(marketVM: marketVM, indicatorVM: indicatorVM)
                case .signalStats:
                    SignalStatsView(indicatorVM: indicatorVM)
                case .tradeJournal:
                    TradeJournalView(marketVM: marketVM, indicatorVM: indicatorVM)
                case .snapshots:
                    SnapshotView(marketVM: marketVM, indicatorVM: indicatorVM)
                case .calculator:
                    TradingCalculatorView(marketVM: marketVM)
                case .converter:
                    CurrencyConverterView(marketVM: marketVM)
                case .alertCenter:
                    AlertCenterView(indicatorVM: indicatorVM)
                case .performance:
                    PerformanceTrackerView()
                case .assetDetail:
                    AssetDetailView(marketVM: marketVM, indicatorVM: indicatorVM, asset: marketVM.currentAsset)
                case .export:
                    ExportView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { selectedTool = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 顶部导航胶囊
    private var topNavigationCapsule: some View {
        HStack(spacing: 12) {
            Button { showAssetPicker.toggle() } label: {
                HStack(spacing: 6) {
                    Circle().fill(marketVM.currentAsset.themeColor).frame(width: 8, height: 8)
                    Text(marketVM.currentAsset.rawValue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(LiquidGlassTheme.primaryText)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(marketVM.connectionStatus.contains("已连接") ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(marketVM.connectionStatus)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(LiquidGlassTheme.tertiaryText)

            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.system(size: 9))
                Text("\(Int(marketVM.latency))ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(marketVM.latency < 100
                ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
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
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab
                        ? LiquidGlassTheme.primaryText : LiquidGlassTheme.tertiaryText)
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
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape.fill"
        }
    }
}

struct AssetPickerSheet: View {
    @Binding var selectedAsset: TradeAsset
    let onSelect: (TradeAsset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("贵金属") {
                    ForEach([TradeAsset.xauUSD]) { asset in assetRow(asset) }
                }
                Section("加密货币") {
                    ForEach(TradeAsset.allCases.filter { $0.assetType == .crypto }) { asset in assetRow(asset) }
                }
            }
            .navigationTitle("选择资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func assetRow(_ asset: TradeAsset) -> some View {
        Button {
            selectedAsset = asset; onSelect(asset); dismiss()
        } label: {
            HStack {
                Circle().fill(asset.themeColor).frame(width: 10, height: 10)
                Text(asset.rawValue).foregroundStyle(LiquidGlassTheme.primaryText)
                Spacer()
                if asset == selectedAsset {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LiquidGlassTheme.bullishAccent)
                }
            }
        }
        .listRowBackground(Color.black.opacity(0.3))
    }
}
