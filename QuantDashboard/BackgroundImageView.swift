import SwiftUI

struct BackgroundImageView: View {
    var body: some View {
        GeometryReader { geo in
            Image("bg_1")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .opacity(0.3)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
