import SwiftUI

struct PriceAlertView: View {
    @ObservedObject var marketVM: MarketViewModel
    @StateObject private var alertManager = PriceAlertManager.shared
    
    @State private var showNewAlert = false
    @State private var targetPrice: String = ""
    @State private var isAbove = true
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("价格预警")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button { showNewAlert = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                }
                .padding(.horizontal, 4)
                
                if alertManager.alerts.isEmpty {
                    emptyState
                } else {
                    ForEach(alertManager.alerts) { alert in
                        alertCard(alert)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showNewAlert) { newAlertSheet }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 40))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text("暂无预警")
                .font(.system(size: 14))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Text("点击右上角 + 添加价格预警")
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func alertCard(_ alert: PriceAlert) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(alert.isEnabled ? (alert.isAbove ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent) : LiquidGlassTheme.neutralAccent.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.asset.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Text(alert.message)
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", alert.targetPrice))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    if alert.triggeredAt != nil {
                        Text("已触发")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(LiquidGlassTheme.bullishAccent)
                    }
                }
                
                Button { alertManager.toggle(alert) } label: {
                    Image(systemName: alert.isEnabled ? "bell.fill" : "bell.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(alert.isEnabled ? LiquidGlassTheme.neutralAccent : LiquidGlassTheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var newAlertSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("当前价格: \(marketVM.formattedPrice)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                
                HStack(spacing: 12) {
                    Button { isAbove = true } label: {
                        Text("突破")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isAbove ? .white : LiquidGlassTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(isAbove ? LiquidGlassTheme.bullishAccent : Color.gray.opacity(0.2)))
                    }
                    Button { isAbove = false } label: {
                        Text("跌破")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(!isAbove ? .white : LiquidGlassTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(!isAbove ? LiquidGlassTheme.bearishAccent : Color.gray.opacity(0.2)))
                    }
                }
                
                TextField("目标价格", text: $targetPrice)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                
                Button("添加预警") {
                    if let price = Double(targetPrice) {
                        alertManager.add(PriceAlert(asset: marketVM.currentAsset, targetPrice: price, isAbove: isAbove))
                        showNewAlert = false
                        targetPrice = ""
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
                .disabled(targetPrice.isEmpty)
                
                Spacer()
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("新建预警")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showNewAlert = false } } }
        }
        .preferredColorScheme(.dark)
    }
}
