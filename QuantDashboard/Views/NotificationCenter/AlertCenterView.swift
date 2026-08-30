import SwiftUI

struct AlertCenterView: View {
    @ObservedObject var indicatorVM: IndicatorViewModel
    @State private var filter: AlertFilter = .all

    enum AlertFilter: String, CaseIterable {
        case all = "全部"
        case bullish = "看多"
        case bearish = "看空"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("通知中心")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    if !indicatorVM.alertHistory.isEmpty {
                        Button("清空") { indicatorVM.clearAlerts() }
                            .font(.system(size: 12))
                            .foregroundStyle(LiquidGlassTheme.bearishAccent)
                    }
                }
                .padding(.horizontal, 4)

                filterPicker

                if filteredAlerts.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredAlerts) { alert in
                        alertCard(alert)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(AlertFilter.allCases, id: \.self) { f in
                Button { filter = f } label: {
                    Text(f.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(filter == f ? .white : LiquidGlassTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(filter == f ? LiquidGlassTheme.neutralAccent : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
            Text("暂无通知")
                .font(.system(size: 14))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Text("指标共振触发强信号时会在此显示")
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func alertCard(_ alert: AlertEvent) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(alert.direction == .bullish ? LiquidGlassTheme.bullishAccent : alert.direction == .bearish ? LiquidGlassTheme.bearishAccent : LiquidGlassTheme.neutralAccent)
                        .frame(width: 8, height: 8)
                    Text(alert.asset.shortName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Text(alert.direction.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(alert.direction == .bullish ? LiquidGlassTheme.bullishAccent : alert.direction == .bearish ? LiquidGlassTheme.bearishAccent : LiquidGlassTheme.neutralAccent)
                    Spacer()
                    Text(alert.strength.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.neutralAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LiquidGlassTheme.neutralAccent.opacity(0.15)))
                }

                Text(alert.message)
                    .font(.system(size: 12))
                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                    .lineLimit(3)

                HStack {
                    Text(alert.indicatorName)
                        .font(.system(size: 10))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Spacer()
                    Text(alert.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
            }
        }
    }

    private var filteredAlerts: [AlertEvent] {
        switch filter {
        case .all: return indicatorVM.alertHistory
        case .bullish: return indicatorVM.alertHistory.filter { $0.direction == .bullish }
        case .bearish: return indicatorVM.alertHistory.filter { $0.direction == .bearish }
        }
    }
}
