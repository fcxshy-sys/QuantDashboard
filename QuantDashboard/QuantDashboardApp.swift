import SwiftUI

private var previousExceptionHandler: NSUncaughtExceptionHandler?

private func crashHandler(_ exception: NSException) {
    let callStack = exception.callStackSymbols.joined(separator: "\n")
    let reason = exception.reason ?? "unknown"
    UserDefaults.standard.set("CRASH: \(exception.name.rawValue) - \(reason)\n\(callStack)", forKey: "lastCrash")
    #if DEBUG
    print("[CRASH] \(exception.name.rawValue): \(reason)")
    #endif
}

@main
struct QuantDashboardApp: App {
    @State private var showSplash = true

    init() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(crashHandler)
        URLCache.shared.removeAllCachedResponses()
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
        }
    }
}
