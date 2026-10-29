import SwiftUI

/// The mark on a track the user has starred on the server, left of its duration (LIB-7, ALB-20).
/// It only shows the star, so it isn't a button.
struct FavouriteHeart: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.subheadline)
            .foregroundStyle(.tint)
            .accessibilityLabel("Favourite")
    }
}
