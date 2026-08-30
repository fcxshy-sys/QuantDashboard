import SwiftUI

// MARK: - Global Crash Handler
private var crashLog: String = ""
private var crashTimestamp: String = ""

private func installCrashHandlers() {
    // NSException handler (ObjC crashes)
    NSSetUncaughtExceptionHandler { exception in
        let info = "\(exception.name.rawValue): \(exception.reason ?? "unknown")\n\(exception.callStackSymbols.joined(separator: "\n"))"
        saveCrashLog(info)
    }

    // Signal handlers (Swift runtime crashes: SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL)
    let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL]
    for sig in signals {
        signal(sig) { s in
            let info = "Signal \(s) received\nThread: \(Thread.callStackSymbols.joined(separator: "\n"))"
            saveCrashLog(info)
            _exit(s)
        }
    }
}

private func saveCrashLog(_ info: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    UserDefaults.standard.set("[\(ts)] \(info)", forKey: "lastCrashLog")
    UserDefaults.standard.synchronize()
}

@main
struct QuantDashboardApp: App {
    @State private var showSplash = true
    @State private var showCrashLog = false
    @State private var lastCrashInfo: String = ""

    init() {
        installCrashHandlers()
        URLCache.shared.removeAllCachedResponses()

        // Check for previous crash
        if let log = UserDefaults.standard.string(forKey: "lastCrashLog"), !log.isEmpty {
            lastCrashInfo = log
            showCrashLog = true
            UserDefaults.standard.removeObject(forKey: "lastCrashLog")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(.dark)

                if showSplash {
                    LaunchScreenView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                _ = LocalAlertManager.shared
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
            .alert("上次崩溃日志", isPresented: $showCrashLog) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(lastCrashInfo)
                    .font(.system(size: 10, design: .monospaced))
            }
        }
    }
}
