// ============================================================
// ThemeManager.swift
// QuantDashboard - 主题管理器（深色/浅色切换）
// ============================================================

import SwiftUI

// MARK: - 主题管理器
class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    @Published var isDarkMode: Bool = true {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "darkMode")
        }
    }

    private init() {
        if UserDefaults.standard.object(forKey: "darkMode") != nil {
            isDarkMode = UserDefaults.standard.bool(forKey: "darkMode")
        } else {
            isDarkMode = true
        }
    }

    func toggle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }
}
