import SwiftUI

// MARK: - Global Crash Handler (async-signal-safe)
private func saveCrashLogAsyncSafe(_ text: String) {
    // Use POSIX write() — the ONLY async-signal-safe I/O function
    let path = NSTemporaryDirectory() + "/crash_log.txt"
    let fd = path.withCString { open($0, O_WRONLY | O_CREAT | O_TRUNC, 0o644) }
    if fd >= 0 {
        text.withCString { ptr in
            _ = write(fd, ptr, strlen(ptr))
        }
        _ = close(fd)
    }
}

@main
struct QuantDashboardApp: App {
    @State private var showSplash = true
    @State private var showCrashLog = false
    @State private var lastCrashInfo: String = ""

    init() {
        // NSUncaughtExceptionHandler — catches ObjC exceptions (async-signal-safe for single-thread)
        NSSetUncaughtExceptionHandler { exception in
            let info = "\(exception.name.rawValue): \(exception.reason ?? "unknown")\n\(exception.callStackSymbols.joined(separator: "\n"))"
            saveCrashLogAsyncSafe(info)
        }

        // NO signal() handlers — they deadlock on UserDefaults and cause SIGKILL
        // iOS generates .ips crash reports automatically in Settings > Privacy > Analytics

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Check for previous crash (from NSSetUncaughtExceptionHandler)
        let crashPath = NSTemporaryDirectory() + "/crash_log.txt"
        if let data = FileManager.default.contents(atPath: crashPath),
           let log = String(data: data, encoding: .utf8), !log.isEmpty {
            lastCrashInfo = log
            showCrashLog = true
            try? FileManager.default.removeItem(atPath: crashPath)
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
            .alert("崩溃日志", isPresented: $showCrashLog) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(lastCrashInfo)
                    .font(.system(size: 10, design: .monospaced))
            }
        }
    }
}
