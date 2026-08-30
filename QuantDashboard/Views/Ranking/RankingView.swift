import SwiftUI

struct RankingView: View {
    @ObservedObject var marketVM: MarketViewModel
    @State private var rankings: [AssetRanking] = []
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("排行榜")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Text("实时")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
                .padding(.horizontal, 4)
                
                ForEach(rankings) { item in
                    GlassCard {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(item.asset.themeColor.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(Text(item.asset.shortName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(item.asset.themeColor))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.asset.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                                Text(formatVolume(item.volume24h))
                                    .font(.system(size: 10))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatPrice(item.price))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                                Text(String(format: "%+.2f%%", item.changePercent))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.isUp ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear { loadRankings() }
    }
    
    private func loadRankings() {
        let assets: [TradeAsset] = [.btcUSDT, .ethUSDT, .solUSDT, .bnbUSDT, .xrpUSDT]
        rankings = assets.map { AssetRanking(asset: $0, price: 0, changePercent: Double.random(in: -5...5), volume24h: Double.random(in: 1_000_000...500_000_000)) }
    }
    
    private func formatPrice(_ p: Double) -> String {
        p >= 1000 ? String(format: "$%.2f", p) : String(format: "$%.4f", p)
    }
    
    private func formatVolume(_ v: Double) -> String {
        if v >= 1_000_000_000 { return String(format: "%.1fB", v / 1_000_000_000) }
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        return String(format: "%.0f", v)
    }
}
