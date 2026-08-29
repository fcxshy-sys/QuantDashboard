// ============================================================
// BackgroundImageView.swift
// QuantDashboard - 动态背景图视图
// ============================================================

import SwiftUI

// MARK: - 背景图视图
struct BackgroundImageView: View {

    @State private var currentImageIndex = 0
    private let imageNames = ["bg_1", "bg_2", "bg_3", "bg_4"]

    var body: some View {
        GeometryReader { geo in
            Image(imageNames[currentImageIndex])
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .opacity(0.15)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.5), value: currentImageIndex)
                .onAppear {
                    startSlideshow()
                }
        }
    }

    private func startSlideshow() {
        Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            withAnimation {
                currentImageIndex = (currentImageIndex + 1) % imageNames.count
            }
        }
    }
}
