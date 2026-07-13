import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.075), radius: 16, y: 10)
    }
}
