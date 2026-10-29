import SwiftUI

/// The Playlists tab: a grid of covers with the playlist's name and track count under each.
struct PlaylistsView: View {
    @ObservedObject var viewModel: PlaylistsViewModel

    private let spacing: CGFloat = 16

    /// The host puts this inside the navigation stack that playlists are pushed onto (PLST-6), so
    /// the title and the settings button below belong to that stack's bar.
    var body: some View {
        content
            .navigationTitle("Playlists")
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
            .onAppear { viewModel.submitAction(.lifecycle(.viewDidAppear)) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case .empty:
            List {}
                .overlay {
                    ContentUnavailableView("No playlists", systemImage: "music.note.list", description: Text("The server has no playlists yet."))
                }
                .refreshable { _ = await viewModel.handleAction(.refresh) }

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load the playlists", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { viewModel.submitAction(.retry) }
            }

        case .loaded:
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: viewModel.columns), spacing: spacing) {
                    ForEach(viewModel.playlists) { playlist in
                        PlaylistCell(playlist: playlist, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, spacing)
            }
            .refreshable { _ = await viewModel.handleAction(.refresh) }
        }
    }
}

private struct PlaylistCell: View {
    let playlist: Playlist
    @ObservedObject var viewModel: PlaylistsViewModel
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Button {
            viewModel.submitAction(.playlistTapped(playlist.id))
        } label: {
            label
        }
        .buttonStyle(.plain)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { CoverArt(image: playlist.coverArtID.flatMap { viewModel.artwork[$0] }).accessibilityHidden(true) }

                // The cover is fetched at the width this cell gives it (PLST-5).
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    guard let id = playlist.coverArtID, width > 0 else { return }

                    viewModel.submitAction(.artworkNeeded(coverArtID: id, pixelSize: Int((width * displayScale).rounded())))
                }
            Text(playlist.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(count)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var count: String {
        guard let songs = playlist.songCount else { return "" }

        return songs == 1 ? "1 song" : "\(songs) songs"
    }
}
