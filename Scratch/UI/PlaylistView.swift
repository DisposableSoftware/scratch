import SwiftUI

/// One playlist: its cover, its info, Play, and the tracks in order (PLST-7). It is pushed onto the
/// Playlists tab's stack, which gives it the navigation bar and the back button.
struct PlaylistView: View {
    @ObservedObject var viewModel: PlaylistViewModel

    var body: some View {
        List {
            CollectionHeader(
                cover: viewModel.cover,
                title: viewModel.playlist.name,
                subtitle: "",
                details: viewModel.details,
                actionsEnabled: viewModel.phase == .loaded,
                artworkNeeded: { viewModel.submitAction(.artworkNeeded(pixelSize: $0)) },
                play: { viewModel.submitAction(.playTapped) },
                shuffle: { viewModel.submitAction(.shuffleTapped) }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)

            content
        }
        .listStyle(.plain)
        .navigationTitle(viewModel.playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.submitAction(.lifecycle(.viewDidAppear)) }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)

        case .empty:
            Text("This playlist has no tracks.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)

        case .failed(let message):
            VStack(spacing: 8) {
                Text(message).foregroundStyle(.secondary)
                Button("Retry") { viewModel.submitAction(.retry) }
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)

        case .loaded:
            ForEach(viewModel.rows) { row in
                Button {
                    viewModel.submitAction(.trackTapped(row.id))
                } label: {
                    TrackLine(row: row.line)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
