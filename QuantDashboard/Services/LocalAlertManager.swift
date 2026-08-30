// ============================================================
// LocalAlertManager.swift
// QuantDashboard - 本地告警管理器（含通知与触感反馈）
// ============================================================

import Foundation
import UserNotifications
import CoreHaptics

// MARK: - 本地告警管理器
/// 管理指标告警的本地通知推送和触感反馈
class LocalAlertManager: NSObject {

    // MARK: - 单例
    static let shared = LocalAlertManager()

    // MARK: - Haptic 引擎
    private var hapticEngine: CHHapticEngine?

    // MARK: - 初始化
    private override init() {
        super.init()
        setupNotifications()
        setupHapticEngine()
    }

    // MARK: - 通知权限申请
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            if let error = error {
                #if DEBUG
                print("[Alert] 通知权限申请失败: \(error.localizedDescription)")
                #endif
            }
            #if DEBUG
            print("[Alert] 通知权限: \(granted ? "已授予" : "被拒绝")")
            #endif
        }
    }

    // MARK: - 配置通知中心
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 创建告警通知类别（支持快速操作）
        let alertCategory = UNNotificationCategory(
            identifier: "INDICATOR_ALERT",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "查看详情",
                    options: .foreground
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "忽略",
                    options: .destructive
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        center.setNotificationCategories([alertCategory])
    }

    // MARK: - 触感引擎
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.stoppedHandler = { [weak self] reason in
                #if DEBUG
                print("[Haptic] 引擎停止: \(reason.rawValue)")
                #endif
                self?.restartHapticEngine()
            }
            hapticEngine?.resetHandler = { [weak self] in
                self?.restartHapticEngine()
            }
            try hapticEngine?.start()
        } catch {
            #if DEBUG
            print("[Haptic] 引擎启动失败: \(error.localizedDescription)")
            #endif
        }
    }

    private func restartHapticEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            #if DEBUG
            print("[Haptic] 引擎重启失败: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - 触发告警
    func triggerAlert(for event: AlertEvent) {
        // 1. 发送本地通知
        sendNotification(for: event)

        // 2. 触发触感反馈
        playHaptic(for: event.strength)
    }

    // MARK: - 发送本地通知
    private func sendNotification(for event: AlertEvent) {
        let content = UNMutableNotificationContent()
        content.title = "⚡ \(event.asset.shortName) \(event.direction.rawValue)信号"
        content.body = event.message
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "INDICATOR_ALERT"
        content.badge = 1

        // 附加数据
        content.userInfo = [
            "asset": event.asset.rawValue,
            "indicator": event.indicatorName,
            "direction": event.direction.rawValue,
            "strength": event.strength.rawValue
        ]

        // 立即触发
        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("[Alert] 通知发送失败: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - 触感反馈
    func playHaptic(for strength: SignalStrength) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let intensity: Float
        let sharpness: Float
        let duration: TimeInterval

        switch strength {
        case .weak:
            intensity = 0.3; sharpness = 0.5; duration = 0.1
        case .moderate:
            intensity = 0.5; sharpness = 0.7; duration = 0.2
        case .strong:
            intensity = 0.8; sharpness = 0.9; duration = 0.3
        case .extreme:
            intensity = 1.0; sharpness = 1.0; duration = 0.5
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: duration
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
            print("[Haptic] 播放失败: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - 强信号连续触感（共振触发时使用）
    func playResonanceAlert() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            var events: [CHHapticEvent] = []
            for i in 0..<3 {
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: Double(i) * 0.15,
                    duration: 0.1
                )
                events.append(event)
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            #if DEBUG
            print("[Haptic] 共振触感失败: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension LocalAlertManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 前台也显示通知横幅
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionIdentifier {
        case "VIEW_DETAILS":
            #if DEBUG
            print("[Alert] 用户点击查看详情: \(userInfo)")
            #endif
        case "DISMISS":
            #if DEBUG
            print("[Alert] 用户忽略告警")
            #endif
        default:
            break
        }
        completionHandler()
    }
}
