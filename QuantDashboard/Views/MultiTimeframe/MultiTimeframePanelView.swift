import SwiftUI

struct MultiTimeframePanelView: View {
    @ObservedObject var indicatorVM: IndicatorViewModel
    @ObservedObject var marketVM: MarketViewModel
    
    private let timeframes: [KLineInterval] = [.m1, .m15, .h1, .h4]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("多周期联动")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Text(marketVM.currentAsset.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 4)
                
                ForEach(1...5, id: \.self) { index in
                    GlassCard(title: "M\(index) \(indicatorVM.result(for: index)?.indicatorName ?? "指标\(index)")", icon: "waveform") {
                        HStack(spacing: 4) {
                            ForEach(timeframes, id: \.self) { tf in
                                VStack(spacing: 4) {
                                    Text(tf.displayName)
                                        .font(.system(size: 9))
                                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                    signalBadge(for: tf, indicatorIndex: index)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                resonanceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    @ViewBuilder
    private func signalBadge(for interval: KLineInterval, indicatorIndex: Int) -> some View {
        let result = indicatorVM.result(for: indicatorIndex)
        let direction = result?.signal ?? .neutral
        
        switch direction {
        case .bullish:
            Text("多")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.bullishAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.bullishAccent.opacity(0.15)))
        case .bearish:
            Text("空")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.bearishAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.bearishAccent.opacity(0.15)))
        case .neutral:
            Text("中")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.neutralAccent)
                .frame(width: 32, height: 22)
                .background(Capsule().fill(LiquidGlassTheme.neutralAccent.opacity(0.1)))
        }
    }
    
    private var resonanceCard: some View {
        GlassCard(title: "多周期共振", icon: "arrow.triangle.2.circlepath") {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    resonanceStat(label: "多头共振", count: bullishCount, color: LiquidGlassTheme.bullishAccent)
                    resonanceStat(label: "空头共振", count: bearishCount, color: LiquidGlassTheme.bearishAccent)
                    resonanceStat(label: "无共振", count: neutralCount, color: LiquidGlassTheme.neutralAccent)
                }
                
                let total = 5
                if bullishCount >= 3 || bearishCount >= 3 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(bullishCount >= 3 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                        Text(bullishCount >= 3 ? "强多头共振信号" : "强空头共振信号")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(bullishCount >= 3 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                    }
                    .padding(.vertical, 4)
                }
                
                Text("共振度 \(resonancePercent)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
        }
    }
    
    private var bullishCount: Int {
        (1...5).filter { indicatorVM.result(for: $0)?.signal == .bullish }.count
    }
    
    private var bearishCount: Int {
        (1...5).filter { indicatorVM.result(for: $0)?.signal == .bearish }.count
    }
    
    private var neutralCount: Int {
        (1...5).filter { indicatorVM.result(for: $0)?.signal == .neutral }.count
    }
    
    private var resonancePercent: Int {
        let dominant = max(bullishCount, bearishCount, neutralCount)
        return dominant * 20
    }
    
    private func resonanceStat(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
