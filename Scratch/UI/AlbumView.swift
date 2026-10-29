import SwiftUI

/// One album: its cover, its info, Play, and the tracks by disc (ALB-9). It is pushed onto the
/// Albums tab's stack, which gives it the navigation bar and the back button.
struct AlbumView: View {
    @ObservedObject var viewModel: AlbumViewModel

    var body: some View {
        List {
            header
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            content
        }
        .listStyle(.plain)
        .navigationTitle(viewModel.album.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.submitAction(.lifecycle(.viewDidAppear)) }
    }

    private var header: some View {
        CollectionHeader(
            cover: viewModel.cover,
            title: viewModel.album.name,
            subtitle: viewModel.album.artist,
            details: viewModel.details,
            actionsEnabled: viewModel.phase == .loaded,
            artworkNeeded: { viewModel.submitAction(.artworkNeeded(pixelSize: $0)) },
            play: { viewModel.submitAction(.playTapped) },
            shuffle: { viewModel.submitAction(.shuffleTapped) }
        )
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)

        case .empty:
            Text("This album has no tracks.")
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
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        Button {
                            viewModel.submitAction(.trackTapped(row.id))
                        } label: {
                            TrackLine(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if let header = section.header {
                        Text(header)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
    }
}

struct TrackLine: View {
    let row: AlbumRow

    var body: some View {
        HStack(spacing: 12) {
            Text(row.number)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).lineLimit(1)

                if let artist = row.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if row.isStarred {
                FavouriteHeart()
            }

            if let duration = row.duration {
                Text(duration)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
