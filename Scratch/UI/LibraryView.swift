import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Songs")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.submitAction(.settingsTapped)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
        }
        .onAppear { viewModel.submitAction(.lifecycle(.viewDidAppear)) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .empty:
            List {}
                .overlay {
                    ContentUnavailableView("No tracks", systemImage: "music.note.list", description: Text("The server has no songs yet."))
                }
                .refreshable { _ = await viewModel.handleAction(.refresh) }

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load the library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { viewModel.submitAction(.retry) }
            }

        case .loaded:
            List {
                ForEach(viewModel.tracks) { track in
                    Button {
                        viewModel.submitAction(.trackTapped(track.id))
                    } label: {
                        TrackRow(track: track, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                    .onAppear { viewModel.submitAction(.rowAppeared(track.id)) }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let message = viewModel.loadMoreError {
                    VStack(spacing: 8) {
                        Text(message).foregroundStyle(.secondary)
                        Button("Retry") { viewModel.submitAction(.retry) }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .refreshable { _ = await viewModel.handleAction(.refresh) }
        }
    }
}

private struct TrackRow: View {
    let track: Track
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.displayScale) private var displayScale

    private static let artSide: CGFloat = 48

    var body: some View {
        HStack(spacing: 12) {
            CoverArt(image: image)
                .frame(width: Self.artSide, height: Self.artSide)
                .onAppear {
                    if let id = track.coverArtID {
                        viewModel.submitAction(.artworkNeeded(coverArtID: id, pixelSize: pixelSize))
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).lineLimit(1)
                Text("\(track.artist) · \(track.album)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if track.isStarred {
                FavouriteHeart()
            }

            if let duration = track.duration {
                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pixelSize: Int { Int((Self.artSide * displayScale).rounded()) }

    private var image: UIImage? {
        track.coverArtID.flatMap { viewModel.artwork[$0] }
    }
}

/// A cover, or the fallback until it arrives or when there is none: a tile in the accent colour
/// with a music note in its label colour, about half the tile wide (LOOK-10).
struct CoverArt: View {
    let image: UIImage?

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                GeometryReader { proxy in
                    ZStack {
                        theme.accent

                        // The note's glyph is drawn narrower than its font size.
                        Image(systemName: "music.note")
                            .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.85))
                            .foregroundStyle(theme.onAccent)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
