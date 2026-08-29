// ============================================================
// QuantDashboardApp.swift
// QuantDashboard - App 入口
// ============================================================

import SwiftUI

@main
struct QuantDashboardApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - UIApplication 代理（后台驻留配置）
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 申请通知权限
        LocalAlertManager.shared.requestPermission()

        // 配置后台音频会话（用于保持 WebSocket 连接）
        configureBackgroundAudio()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[App] 进入后台，WebSocket 保持连接")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[App] 回到前台")
    }

    // MARK: - 后台音频保活配置
    private func configureBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("[App] 后台音频会话已配置")
        } catch {
            print("[App] 音频会话配置失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 导入 AVFoundation（用于后台音频保活）
import AVFoundation
