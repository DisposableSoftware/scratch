import SwiftUI

/// The top of an album's or a playlist's screen: its cover, name, info, and the Play and Shuffle
/// actions (ALB-9, PLST-7). The Play label reads on the accent (LOOK-9).
struct CollectionHeader: View {
    let cover: UIImage?
    let title: String
    let subtitle: String
    let details: String
    let actionsEnabled: Bool

    /// Told the width in pixels the cover is shown at, so it is fetched at that size.
    let artworkNeeded: (Int) -> Void
    let play: () -> Void
    let shuffle: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { CoverArt(image: cover).accessibilityHidden(true) }
                .frame(maxWidth: 360)

                // The cover is fetched at the width it is shown at.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    guard width > 0 else { return }

                    artworkNeeded(Int((width * displayScale).rounded()))
                }
            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button(action: play) {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
                Button(action: shuffle) {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(!actionsEnabled)
        }
        .frame(maxWidth: .infinity)
    }
}
