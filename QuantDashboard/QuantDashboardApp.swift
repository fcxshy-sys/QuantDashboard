import SwiftUI
import AVFoundation

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

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LocalAlertManager.shared.requestPermission()
        configureBackgroundAudio()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("[App] 进入后台，WebSocket 保持连接")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("[App] 回到前台")
    }

    private func configureBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[App] 音频会话配置失败: \(error.localizedDescription)")
        }
    }
}
