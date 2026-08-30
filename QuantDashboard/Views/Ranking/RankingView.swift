import SwiftUI

struct RankingView: View {
    @ObservedObject var marketVM: MarketViewModel
    @State private var rankings: [AssetRanking] = []
    @State private var isLoading = true
    @State private var sortBy: SortField = .change
    
    enum SortField: String, CaseIterable {
        case change = "涨跌幅"
        case volume = "成交量"
        case price = "价格"
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("排行榜")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button { refreshRankings() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                sortPicker
                
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(LiquidGlassTheme.neutralAccent)
                        Text("正在获取行情数据...")
                            .font(.system(size: 12))
                            .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(sortedRankings) { item in
                        Button { 
                            marketVM.switchAsset(to: item.asset) 
                        } label: {
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
                                        Text("Vol: \(formatVolume(item.volume24h))")
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
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear { 
            if rankings.isEmpty { refreshRankings() }
        }
    }
    
    private var sortPicker: some View {
        HStack(spacing: 8) {
            ForEach(SortField.allCases, id: \.self) { field in
                Button { sortBy = field } label: {
                    Text(field.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(sortBy == field ? .white : LiquidGlassTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(sortBy == field ? LiquidGlassTheme.neutralAccent : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var sortedRankings: [AssetRanking] {
        switch sortBy {
        case .change: return rankings.sorted { abs($0.changePercent) > abs($1.changePercent) }
        case .volume: return rankings.sorted { $0.volume24h > $1.volume24h }
        case .price: return rankings.sorted { $0.price > $1.price }
        }
    }
    
    private func refreshRankings() {
        isLoading = true
        let assets: [TradeAsset] = [.btcUSDT, .ethUSDT, .solUSDT, .bnbUSDT, .xrpUSDT, .xauUSD]
        
        let group = DispatchGroup()
        var results: [AssetRanking] = []
        let lock = NSLock()
        
        for asset in assets {
            guard let name = asset.gateIOName else {
                if asset == .xauUSD {
                    lock.lock()
                    results.append(AssetRanking(
                        asset: asset, 
                        price: marketVM.currentAsset == .xauUSD ? marketVM.latestPrice : 2400,
                        changePercent: Double.random(in: -2...2), 
                        volume24h: 0
                    ))
                    lock.unlock()
                }
                continue
            }
            
            group.enter()
            let urlString = "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=\(name)"
            guard let url = URL(string: urlString) else { group.leave(); continue }
            
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let ticker = json.first else { return }
                
                let lastStr = "\(ticker["last"] ?? "0")"
                let highStr = "\(ticker["high_24h"] ?? "0")"
                let lowStr = "\(ticker["low_24h"] ?? "0")"
                let volStr = "\(ticker["base_volume_24h"] ?? "0")"
                let pctStr = "\(ticker["change_percentage"] ?? "0")"
                
                let price = Double(lastStr) ?? 0
                let changePct = Double(pctStr) ?? 0
                let vol = Double(volStr) ?? 0
                
                lock.lock()
                results.append(AssetRanking(asset: asset, price: price, changePercent: changePct, volume24h: vol))
                lock.unlock()
            }.resume()
        }
        
        group.notify(queue: .main) {
            rankings = results
            isLoading = false
        }
    }
    
    private func formatPrice(_ p: Double) -> String {
        p >= 1000 ? String(format: "$%.2f", p) : p > 0 ? String(format: "$%.4f", p) : "---"
    }
    
    private func formatVolume(_ v: Double) -> String {
        if v >= 1_000_000_000 { return String(format: "%.1fB", v / 1_000_000_000) }
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        return String(format: "%.0f", v)
    }
}
