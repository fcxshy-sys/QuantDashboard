# QuantDashboard - 量化交易看板

## 项目概述

基于 SwiftUI 构建的高性能量化交易看板 App，专为 TrollStore（巨魔商店）免签部署设计。

### 核心特性

- **多资产监控**: 现货黄金 (XAU/USD) + 主流加密货币 (BTC/ETH/SOL/BNB/XRP)
- **实时行情**: Binance WebSocket 推流 + 黄金 REST 轮询
- **5 大指标引擎**: 模块化指标计算框架，预留 5 个自定义指标槽位
- **多空共振雷达**: 动态加权评分系统，3+ 指标共振自动告警
- **Liquid Glass UI**: GitHub 开源液态毛玻璃设计系统，OLED 深邃背景
- **后台驻留**: TrollStore 权限加持，WebSocket 长连接不中断
- **本地告警**: 共振信号触发即时通知 + CoreHaptics 触感反馈

## 项目结构

```
QuantDashboard/
├── QuantDashboard/
│   ├── QuantDashboardApp.swift      # App 入口
│   ├── Info.plist                   # 应用配置
│   ├── Entitlements.plist           # TrollStore 权限声明
│   ├── Models/                      # 数据模型层
│   │   ├── AssetModels.swift        # 资产/交易对/周期定义
│   │   ├── CandleData.swift         # K线蜡烛数据 + 实时成交
│   │   └── IndicatorModels.swift    # 指标结果/信号/雷达评分
│   ├── IndicatorEngine/            # 量化指标计算引擎
│   │   ├── IndicatorProtocol.swift  # 指标计算协议 + 基类
│   │   ├── IndicatorSlots.swift     # 5 个指标槽位（待填入）
│   │   ├── SignalRadarEngine.swift  # 多空共振评分雷达
│   │   └── IndicatorEngine.swift    # 指标引擎总调度器
│   ├── Network/                     # 网络/WebSocket 层
│   │   ├── BinanceWebSocketManager.swift  # Binance WS 引擎
│   │   ├── GoldDataProvider.swift   # 黄金行情数据源
│   │   └── DataPipeline.swift       # 数据管道调度层
│   ├── Services/                    # 系统服务
│   │   └── LocalAlertManager.swift  # 本地通知 + Haptic 触感
│   ├── LiquidGlassUI/               # 液态毛玻璃组件库
│   │   ├── LiquidGlassTheme.swift   # 主题配置
│   │   ├── LiquidGlassModifier.swift # ViewModifier 核心
│   │   ├── GlassCard.swift          # 玻璃卡片/按钮/标签
│   │   └── RadarView.swift          # 雷达评分仪表盘
│   ├── ViewModels/                  # 视图模型层
│   │   ├── MarketViewModel.swift    # 行情状态管理
│   │   └── IndicatorViewModel.swift # 指标状态管理
│   └── Views/                       # 视图层
│       ├── ContentView.swift        # 主导航容器
│       ├── LaunchScreen.swift       # 启动画面
│       ├── Dashboard/DashboardView.swift    # 主看板
│       ├── Charts/KLineChartView.swift      # K线图表
│       ├── Panels/IndicatorPanelView.swift  # 指标面板
│       └── Settings/SettingsView.swift      # 设置页
├── QuantDashboard.xcodeproj/        # Xcode 工程文件
├── build_trollstore.sh              # TrollStore 打包脚本
└── README.md
```

## 快速开始

### 1. 打开项目
```bash
open QuantDashboard.xcodeproj
```

### 2. 配置签名
- 在 Xcode 中选择 QuantDashboard target
- Signing & Capabilities → 选择你的开发者团队
- 或使用 Automatic Signing

### 3. 编译运行
- 选择模拟器或真机目标
- Cmd+R 运行

### 4. TrollStore 打包
```bash
chmod +x build_trollstore.sh
./build_trollstore.sh
```
生成的 `.tipa` 文件可通过 TrollStore 安装到设备。

## 填入自定义指标

在 `IndicatorEngine/IndicatorSlots.swift` 中，找到 5 个指标类的 `【指标 N 填入点】` 标记，填入你的具体算法逻辑。

每个指标类需要实现：
1. `calculate(candles:)` - 计算指标时间序列
2. `generateSignal(candles:)` - 生成多空信号

## 网络数据源配置

### Binance WebSocket（加密货币）
无需配置，直接使用公开 API：
- K线推送: `wss://stream.binance.com:9443/ws/{symbol}@kline_{interval}`
- 逐笔成交: `wss://stream.binance.com:9443/ws/{symbol}@trade`

### 黄金行情（XAU/USD）
在 `GoldDataProvider.swift` 中替换 API Key：
- Finnhub: `YOUR_FINNHUB_API_KEY`
- Alpha Vantage: `YOUR_ALPHA_VANTAGE_KEY`

## 技术栈

- **UI**: SwiftUI + Canvas 自绘 + Liquid Glass 设计系统
- **响应式**: Combine 框架
- **网络**: URLSessionWebSocketTask (WebSocket) + URLSession (REST)
- **图表**: Swift Canvas API 自绘 K 线
- **触感**: CoreHaptics
- **通知**: UserNotifications (本地推送)
- **架构**: MVVM + 组合模式

## 系统要求

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- TrollStore（用于免签部署）
