// ============================================================
// AssetModels.swift
// QuantDashboard - 资产数据模型
// ============================================================

import Foundation

// MARK: - 资产类型枚举
enum AssetType: String, CaseIterable, Codable, Identifiable {
    case crypto = "加密货币"
    case preciousMetal = "贵金属"

    var id: String { rawValue }
}

// MARK: - 交易对/资产定义
enum TradeAsset: String, CaseIterable, Codable, Identifiable {
    // 加密货币
    case btcUSDT = "BTC/USDT"
    case ethUSDT = "ETH/USDT"
    case solUSDT = "SOL/USDT"
    case bnbUSDT = "BNB/USDT"
    case xrpUSDT = "XRP/USDT"

    // 贵金属
    case xauUSD = "XAU/USD"

    var id: String { rawValue }

    /// 资产类型
    var assetType: AssetType {
        switch self {
        case .btcUSDT, .ethUSDT, .solUSDT, .bnbUSDT, .xrpUSDT:
            return .crypto
        case .xauUSD:
            return .preciousMetal
        }
    }

    /// Binance WebSocket 流名称（仅加密资产使用）
    var binanceStreamName: String? {
        switch self {
        case .btcUSDT: return "btcusdt"
        case .ethUSDT: return "ethusdt"
        case .solUSDT: return "solusdt"
        case .bnbUSDT: return "bnbusdt"
        case .xrpUSDT: return "xrpusdt"
        case .xauUSD: return nil
        }
    }

    /// 显示用简称
    var shortName: String {
        switch self {
        case .btcUSDT: return "BTC"
        case .ethUSDT: return "ETH"
        case .solUSDT: return "SOL"
        case .bnbUSDT: return "BNB"
        case .xrpUSDT: return "XRP"
        case .xauUSD: return "XAU"
        }
    }

    /// 图标颜色名称（用于 UI）
    var colorName: String {
        switch self {
        case .btcUSDT: return "assetBTC"
        case .ethUSDT: return "assetETH"
        case .solUSDT: return "assetSOL"
        case .bnbUSDT: return "assetBNB"
        case .xrpUSDT: return "assetXRP"
        case .xauUSD: return "assetXAU"
        }
    }
}

// MARK: - K线周期
enum KLineInterval: String, CaseIterable, Codable, Identifiable {
    case m1 = "1m"
    case m5 = "5m"
    case m15 = "15m"
    case h1 = "1h"
    case h4 = "4h"
    case d1 = "1D"

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .m1: return "1分钟"
        case .m5: return "5分钟"
        case .m15: return "15分钟"
        case .h1: return "1小时"
        case .h4: return "4小时"
        case .d1: return "日线"
        }
    }

    /// Binance REST API interval 参数
    var binanceParameter: String { rawValue }

    /// 对应秒数（用于时间轴计算）
    var intervalSeconds: TimeInterval {
        switch self {
        case .m1: return 60
        case .m5: return 300
        case .m15: return 900
        case .h1: return 3600
        case .h4: return 14400
        case .d1: return 86400
        }
    }
}
