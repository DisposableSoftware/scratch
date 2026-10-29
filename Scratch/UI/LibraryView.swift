import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    /// The now-playing bar (PLAY-2), which has its own ViewModel.
    let nowPlaying: NowPlayingBar

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .safeAreaInset(edge: .bottom, spacing: 0) { nowPlaying }
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

/// A cover, or a placeholder until it arrives or when there is none.
struct CoverArt: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
