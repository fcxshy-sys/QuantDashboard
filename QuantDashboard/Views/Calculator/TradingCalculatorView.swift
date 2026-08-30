import SwiftUI

struct TradingCalculatorView: View {
    @ObservedObject var marketVM: MarketViewModel

    @State private var calculatorMode: CalcMode = .positionSize
    @State private var entryPrice: String = ""
    @State private var exitPrice: String = ""
    @State private var stopLoss: String = ""
    @State private var accountBalance: String = "10000"
    @State private var riskPercent: String = "2"
    @State private var leverage: String = "1"
    @State private var quantity: String = ""
    @State private var side: TradeSide = .long

    enum CalcMode: String, CaseIterable {
        case positionSize = "仓位计算"
        case pnl = "盈亏计算"
        case riskReward = "风险回报"
        case fibonacci = "斐波那契"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("交易计算器")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                modeSelector

                switch calculatorMode {
                case .positionSize: positionSizeCalc
                case .pnl: pnlCalc
                case .riskReward: riskRewardCalc
                case .fibonacci: fibonacciCalc
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CalcMode.allCases, id: \.self) { mode in
                    Button { calculatorMode = mode } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(calculatorMode == mode ? .white : LiquidGlassTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(calculatorMode == mode ? LiquidGlassTheme.neutralAccent : Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Position Size Calculator
    private var positionSizeCalc: some View {
        VStack(spacing: 14) {
            GlassCard(title: "仓位计算", icon: "number") {
                VStack(spacing: 10) {
                    sidePicker
                    inputField(label: "账户余额 ($)", text: $accountBalance)
                    inputField(label: "风险比例 (%)", text: $riskPercent)
                    inputField(label: "入场价格", text: $entryPrice, placeholder: marketVM.formattedPrice)
                    inputField(label: "止损价格", text: $stopLoss)
                    inputField(label: "杠杆倍数", text: $leverage)
                }
            }

            if let result = calculatedPositionSize {
                GlassCard(title: "计算结果", icon: "checkmark.circle") {
                    VStack(spacing: 8) {
                        resultRow("建议仓位", String(format: "$%.2f", result.positionValue))
                        resultRow("开仓数量", String(format: "%.6f", result.quantity))
                        resultRow("所需保证金", String(format: "$%.2f", result.margin))
                        resultRow("最大亏损", String(format: "$%.2f", result.maxLoss))
                        resultRow("止损幅度", String(format: "%.2f%%", result.stopPercent))
                    }
                }
            }
        }
    }

    // MARK: - P&L Calculator
    private var pnlCalc: some View {
        VStack(spacing: 14) {
            GlassCard(title: "盈亏计算", icon: "dollarsign.circle") {
                VStack(spacing: 10) {
                    sidePicker
                    inputField(label: "入场价格", text: $entryPrice, placeholder: marketVM.formattedPrice)
                    inputField(label: "出场价格", text: $exitPrice)
                    inputField(label: "数量", text: $quantity)
                    inputField(label: "杠杆倍数", text: $leverage)
                }
            }

            if let result = calculatedPnL {
                GlassCard(title: "盈亏结果", icon: "chart.line.uptrend.xyaxis") {
                    VStack(spacing: 8) {
                        resultRow("盈亏金额", String(format: "$%.2f", result.pnl), color: result.pnl >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                        resultRow("盈亏比例", String(format: "%.2f%%", result.pnlPercent), color: result.pnl >= 0 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                        resultRow("ROI", String(format: "%.2f%%", result.roi))
                        resultRow("名义价值", String(format: "$%.2f", result.notionalValue))
                    }
                }
            }
        }
    }

    // MARK: - Risk/Reward Calculator
    private var riskRewardCalc: some View {
        VStack(spacing: 14) {
            GlassCard(title: "风险回报", icon: "scalemass") {
                VStack(spacing: 10) {
                    sidePicker
                    inputField(label: "入场价格", text: $entryPrice, placeholder: marketVM.formattedPrice)
                    inputField(label: "止盈价格", text: $exitPrice)
                    inputField(label: "止损价格", text: $stopLoss)
                }
            }

            if let result = calculatedRiskReward {
                GlassCard(title: "风险回报结果", icon: "arrow.triangle.2.circlepath") {
                    VStack(spacing: 8) {
                        resultRow("风险回报比", String(format: "1 : %.2f", result.ratio), color: result.ratio >= 2 ? LiquidGlassTheme.bullishAccent : result.ratio >= 1 ? LiquidGlassTheme.neutralAccent : LiquidGlassTheme.bearishAccent)
                        resultRow("潜在盈利", String(format: "$%.2f", result.reward))
                        resultRow("潜在亏损", String(format: "$%.2f", result.risk))
                        resultRow("建议", result.ratio >= 2 ? "值得交易" : result.ratio >= 1 ? "可考虑" : "风险过高", color: result.ratio >= 2 ? LiquidGlassTheme.bullishAccent : LiquidGlassTheme.bearishAccent)
                    }
                }
            }
        }
    }

    // MARK: - Fibonacci Calculator
    private var fibonacciCalc: some View {
        VStack(spacing: 14) {
            GlassCard(title: "斐波那契回撤", icon: "function") {
                VStack(spacing: 10) {
                    inputField(label: "高点价格", text: $entryPrice, placeholder: "最近高点")
                    inputField(label: "低点价格", text: $stopLoss, placeholder: "最近低点")
                }
            }

            if let levels = calculatedFibonacci {
                GlassCard(title: "回撤水平", icon: "list.number") {
                    VStack(spacing: 6) {
                        ForEach(levels, id: \.level) { fib in
                            HStack {
                                Text(String(format: "%.1f%%", fib.level * 100))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                    .frame(width: 50, alignment: .leading)
                                Text(fib.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(LiquidGlassTheme.secondaryText)
                                Spacer()
                                Text(String(format: "$%.2f", fib.price))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LiquidGlassTheme.primaryText)
                            }
                            if fib.level != levels.last?.level {
                                Divider().background(Color.white.opacity(0.04))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared Components
    private var sidePicker: some View {
        HStack(spacing: 12) {
            Button { side = .long } label: {
                Text("做多")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(side == .long ? .white : LiquidGlassTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(side == .long ? LiquidGlassTheme.bullishAccent : Color.gray.opacity(0.2)))
            }
            Button { side = .short } label: {
                Text("做空")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(side == .short ? .white : LiquidGlassTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(side == .short ? LiquidGlassTheme.bearishAccent : Color.gray.opacity(0.2)))
            }
        }
    }

    private func inputField(label: String, text: Binding<String>, placeholder: String = "0") -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    private func resultRow(_ label: String, _ value: String, color: Color = LiquidGlassTheme.primaryText) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    // MARK: - Calculation Logic
    private struct PositionResult {
        let positionValue: Double
        let quantity: Double
        let margin: Double
        let maxLoss: Double
        let stopPercent: Double
    }

    private struct PnLResult {
        let pnl: Double
        let pnlPercent: Double
        let roi: Double
        let notionalValue: Double
    }

    private struct RiskRewardResult {
        let ratio: Double
        let reward: Double
        let risk: Double
    }

    private struct FibLevel {
        let level: Double
        let label: String
        let price: Double
    }

    private var calculatedPositionSize: PositionResult? {
        guard let balance = Double(accountBalance), let risk = Double(riskPercent),
              let entry = Double(entryPrice), let sl = Double(stopLoss),
              let lev = Double(leverage), balance > 0, entry > 0, sl > 0, lev > 0 else { return nil }
        let riskAmount = balance * risk / 100
        let stopDistance = abs(entry - sl)
        guard stopDistance > 0 else { return nil }
        let quantityVal = riskAmount / stopDistance
        let positionValue = quantityVal * entry
        let margin = positionValue / lev
        let stopPercent = stopDistance / entry * 100
        return PositionResult(positionValue: positionValue, quantity: quantityVal, margin: margin, maxLoss: riskAmount, stopPercent: stopPercent)
    }

    private var calculatedPnL: PnLResult? {
        guard let ep = Double(entryPrice), let xp = Double(exitPrice),
              let qty = Double(quantity), let lev = Double(leverage),
              ep > 0, qty > 0, lev > 0 else { return nil }
        let mult = side == .long ? 1.0 : -1.0
        let pnlVal = (xp - ep) * qty * mult
        let notional = ep * qty
        let pnlPct = ep > 0 ? (xp - ep) / ep * mult * 100 : 0
        let roiVal = notional > 0 ? pnlVal / (notional / lev) * 100 : 0
        return PnLResult(pnl: pnlVal, pnlPercent: pnlPct, roi: roiVal, notionalValue: notional)
    }

    private var calculatedRiskReward: RiskRewardResult? {
        guard let ep = Double(entryPrice), let tp = Double(exitPrice), let sl = Double(stopLoss),
              ep > 0 else { return nil }
        let mult = side == .long ? 1.0 : -1.0
        let rewardVal = abs(tp - ep) * mult
        let riskVal = abs(sl - ep) * mult
        guard riskVal > 0 else { return nil }
        return RiskRewardResult(ratio: rewardVal / riskVal, reward: rewardVal, risk: riskVal)
    }

    private var calculatedFibonacci: [FibLevel]? {
        guard let high = Double(entryPrice), let low = Double(stopLoss), high > low else { return nil }
        let diff = high - low
        let levels: [(Double, String)] = [
            (0.0, "0% (低点)"), (0.236, "23.6%"), (0.382, "38.2%"),
            (0.5, "50%"), (0.618, "61.8%"), (0.786, "78.6%"), (1.0, "100% (高点)")
        ]
        return levels.map { FibLevel(level: $0.0, label: $0.1, price: high - diff * $0.0) }
    }
}
