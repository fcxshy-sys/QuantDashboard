import SwiftUI

struct CurrencyConverterView: View {
    @ObservedObject var marketVM: MarketViewModel

    @State private var fromCurrency = "USD"
    @State private var toCurrency = "CNY"
    @State private var amount: String = "1"
    @State private var convertedAmount: Double = 0

    private let rates: [String: (rate: Double, symbol: String)] = [
        "USD": (1.0, "$"), "CNY": (7.25, "¥"), "EUR": (0.92, "€"),
        "GBP": (0.79, "£"), "JPY": (149.5, "¥"), "KRW": (1320, "₩"),
        "BTC": (0.0000146, "₿"), "ETH": (0.00028, "Ξ"),
        "USDT": (1.0, "₮"), "XAU": (0.00029, "Au")
    ]

    private let currencyNames: [String: String] = [
        "USD": "美元", "CNY": "人民币", "EUR": "欧元", "GBP": "英镑",
        "JPY": "日元", "KRW": "韩元", "BTC": "比特币", "ETH": "以太坊",
        "USDT": "泰达币", "XAU": "黄金"
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("汇率换算")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 4)

                converterCard

                quickReference

                metalPrices
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear { convert() }
    }

    private var converterCard: some View {
        GlassCard(title: "汇率转换", icon: "arrow.left.arrow.right") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    currencyButton(currency: $fromCurrency, label: "从")
                    Button { swapCurrencies() } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                    .buttonStyle(.plain)
                    currencyButton(currency: $toCurrency, label: "到")
                }

                TextField("金额", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .onChange(of: amount) { _ in convert() }

                HStack {
                    Text(rates[fromCurrency]?.symbol ?? "")
                        .font(.system(size: 16))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Text(amount.isEmpty ? "0" : amount)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Text(fromCurrency)
                        .font(.system(size: 14))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                    Text("=")
                        .font(.system(size: 16))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Text(rates[toCurrency]?.symbol ?? "")
                        .font(.system(size: 16))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                    Text(String(format: "%.4f", convertedAmount))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(LiquidGlassTheme.bullishAccent)
                    Text(toCurrency)
                        .font(.system(size: 14))
                        .foregroundStyle(LiquidGlassTheme.secondaryText)
                }

                if let fromName = currencyNames[fromCurrency], let toName = currencyNames[toCurrency] {
                    Text("1 \(fromCurrency) = \(String(format: "%.6f", convertRate(from: fromCurrency, to: toCurrency))) \(toCurrency)")
                        .font(.system(size: 11))
                        .foregroundStyle(LiquidGlassTheme.tertiaryText)
                }
            }
        }
    }

    private func currencyButton(currency: Binding<String>, label: String) -> some View {
        Menu {
            ForEach(Array(rates.keys.sorted()), id: \.self) { key in
                Button {
                    currency.wrappedValue = key
                    convert()
                } label: {
                    HStack {
                        Text(key)
                        if let name = currencyNames[key] {
                            Text(name)
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                Text(currency.wrappedValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LiquidGlassTheme.primaryText)
                Text(currencyNames[currency.wrappedValue] ?? "")
                    .font(.system(size: 9))
                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        }
    }

    private func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        convert()
    }

    private func convertRate(from: String, to: String) -> Double {
        guard let fromRate = rates[from]?.rate, let toRate = rates[to]?.rate, fromRate > 0 else { return 0 }
        return toRate / fromRate
    }

    private func convert() {
        guard let amt = Double(amount) else { convertedAmount = 0; return }
        convertedAmount = amt * convertRate(from: fromCurrency, to: toCurrency)
    }

    private var quickReference: some View {
        GlassCard(title: "常用汇率", icon: "tablecells") {
            VStack(spacing: 6) {
                refRow(from: "USD", to: "CNY")
                refRow(from: "EUR", to: "CNY")
                refRow(from: "GBP", to: "CNY")
                refRow(from: "JPY", to: "CNY")
                refRow(from: "BTC", to: "USD")
                refRow(from: "ETH", to: "USD")
            }
        }
    }

    private func refRow(from: String, to: String) -> some View {
        HStack {
            Text("\(from)/\(to)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(String(format: "%.4f", convertRate(from: from, to: to)))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.primaryText)
        }
    }

    private var metalPrices: some View {
        GlassCard(title: "贵金属参考", icon: "circle.fill") {
            VStack(spacing: 6) {
                metalRow(name: "黄金 (XAU/USD)", price: marketVM.currentAsset == .xauUSD ? marketVM.latestPrice : 2400)
                metalRow(name: "黄金 克/人民币", price: (marketVM.currentAsset == .xauUSD ? marketVM.latestPrice : 2400) * convertRate(from: "USD", to: "CNY") / 31.1035)
                metalRow(name: "白银 (参考)", price: 28.5)
            }
        }
    }

    private func metalRow(name: String, price: Double) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(LiquidGlassTheme.secondaryText)
            Spacer()
            Text(String(format: "$%.2f", price))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(LiquidGlassTheme.primaryText)
        }
    }
}
