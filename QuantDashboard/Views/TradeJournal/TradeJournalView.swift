import SwiftUI

struct TradeJournalView: View {
    @StateObject private var journal = TradeJournalManager.shared
    @ObservedObject var marketVM: MarketViewModel
    @ObservedObject var indicatorVM: IndicatorViewModel
    
    @State private var showNewTrade = false
    @State private var newSide: TradeSide = .long
    @State private var newPrice = ""
    @State private var newQuantity = ""
    @State private var newNotes = ""
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("交易记录")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button { showNewTrade = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                }
                .padding(.horizontal, 4)
                
                summaryCard
                
                if !journal.openRecords.isEmpty {
                    sectionHeader("持仓中")
                    ForEach(journal.openRecords) { record in
                        tradeCard(record, isOpen: true)
                    }
                }
                
                if !journal.closedRecords.isEmpty {
                    sectionHeader("已平仓")
                    ForEach(journal.closedRecords.prefix(20)) { record in
                        tradeCard(record, isOpen: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showNewTrade) { newTradeSheet }
    }
    
    private var summaryCard: some View {
        GlassCard(title: "交易统计", icon: "chart.bar.fill") {
            HStack(spacing: 16) {
                summaryStat("总盈亏", String(format: "$%.2f", journal.totalProfitLoss), journal.totalProfitLoss >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                summaryStat("胜率", String(format: "%.0f%%", journal.overallWinRate), LiquidGlassTheme.neutralAccent)
                summaryStat("持仓", "\(journal.openRecords.count)", LiquidGlassTheme.primaryText)
                summaryStat("总笔", "\(journal.closedRecords.count)", LiquidGlassTheme.primaryText)
            }
        }
    }
    
    private func summaryStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(LiquidGlassTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LiquidGlassTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
    
    private func tradeCard(_ record: TradeRecord, isOpen: Bool) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(record.side == .long ? "多" : "空")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(record.side == .long ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((record.side == .long ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent).opacity(0.15)))
                        
                        Text(record.asset.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LiquidGlassTheme.primaryText)
                    }
                    
                    Text("入场 \(String(format: "%.2f", record.entryPrice))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                    
                    if let exit = record.exitPrice {
                        Text("出场 \(String(format: "%.2f", exit))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LiquidGlassTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                if let pl = record.profitLossPercent {
                    Text(String(format: "%+.2f%%", pl))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(pl > 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                } else if isOpen {
                    Button("平仓") {
                        journal.closeRecord(id: record.id, exitPrice: marketVM.latestPrice)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
                }
            }
        }
    }
    
    private var newTradeSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("\(marketVM.currentAsset.rawValue) 当前: \(marketVM.formattedPrice)")
                    .font(.system(size: 14))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                
                HStack(spacing: 12) {
                    Button { newSide = .long } label: {
                        Text("做多").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(newSide == .long ? .white : LiquidGlassTheme.secondaryText)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(newSide == .long ? LiquidGlassTheme.bullishAccent : Color.gray.opacity(0.2)))
                    }
                    Button { newSide = .short } label: {
                        Text("做空").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(newSide == .short ? .white : LiquidGlassTheme.secondaryText)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(newSide == .short ? LiquidGlassTheme.bearishAccent : Color.gray.opacity(0.2)))
                    }
                }
                
                TextField("入场价格", text: $newPrice).keyboardType(.decimalPad)
                    .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                TextField("数量", text: $newQuantity).keyboardType(.decimalPad)
                    .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                TextField("备注 (可选)", text: $newNotes)
                    .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                
                Button("记录交易") {
                    if let price = Double(newPrice), let qty = Double(newQuantity) {
                        var signals: [String] = []
                        for (_, r) in indicatorVM.indicatorResults { if r.signal != .neutral { signals.append("\(r.indicatorName):\(r.signal.rawValue)") } }
                        journal.addRecord(TradeRecord(asset: marketVM.currentAsset, side: newSide, entryPrice: price, quantity: qty, notes: newNotes, indicatorSignals: signals))
                        showNewTrade = false; newPrice = ""; newQuantity = ""; newNotes = ""
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
                .disabled(newPrice.isEmpty || newQuantity.isEmpty)
                
                Spacer()
            }
            .padding(20).background(Color.black.ignoresSafeArea())
            .navigationTitle("新建记录").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showNewTrade = false } } }
        }
        .preferredColorScheme(.dark)
    }
}
