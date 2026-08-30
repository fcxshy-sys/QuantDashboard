import SwiftUI

struct SnapshotView: View {
    @StateObject private var snapshotService = DailySnapshotService.shared
    @StateObject private var statsManager = SignalStatsManager.shared
    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel
    @State private var showShare = false
    @State private var snapshotImage: UIImage?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("每日快照")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button { takeSnapshot() } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                }
                .padding(.horizontal, 4)
                
                GlassCard(title: "快照服务", icon: "camera.metering.center.weighted") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("上次快照")
                                .foregroundStyle(LiquidGlassTheme.secondaryText)
                            Spacer()
                            Text(snapshotService.lastSnapshotDate?.formatted(date: .abbreviated, time: .shortened) ?? "从未")
                                .foregroundStyle(LiquidGlassTheme.primaryText)
                        }
                        Text("每天自动保存当日行情截图")
                            .font(.system(size: 11))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if !statsManager.snapshots.isEmpty {
                    GlassCard(title: "历史快照", icon: "photo.stack") {
                        ForEach(statsManager.snapshots.suffix(10).reversed()) { snap in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11))
                                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                                    Text(snap.asset)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(LiquidGlassTheme.primaryText)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", snap.price))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                                Text(String(format: "R:%.0f", snap.radarScore))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(snap.radarScore > 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            }
                            if snap.id != statsManager.snapshots.suffix(10).last?.id {
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    private func takeSnapshot() {
        var signals: [Int: String] = [:]
        for (i, r) in indicatorVM.indicatorResults { signals[i] = r.description }
        statsManager.takeSnapshot(asset: marketVM.currentAsset, price: marketVM.latestPrice, radarScore: indicatorVM.radarScore?.score ?? 0, signals: signals)
        
        if let imgData = snapshotService.takeManualSnapshot() {
            snapshotImage = UIImage(data: imgData)
            showShare = true
        }
    }
}
