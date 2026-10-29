import SwiftUI

/// The Albums tab: a grid of covers with the album's name and artist under each.
struct AlbumsView: View {
    @ObservedObject var viewModel: AlbumsViewModel

    private let spacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Albums")
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
            ContentUnavailableView("No albums", systemImage: "square.grid.2x2", description: Text("The server has no albums yet."))
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load the albums", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { viewModel.submitAction(.retry) }
            }
        case .loaded:
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: viewModel.columns), spacing: spacing) {
                    if !viewModel.favourites.isEmpty {
                        Section {
                            ForEach(viewModel.favourites) { album in
                                AlbumCell(album: album, viewModel: viewModel)
                            }
                        } header: {
                            SectionHeader(title: "Favourites")
                        }
                    }
                    Section {
                        ForEach(viewModel.albums) { album in
                            AlbumCell(album: album, viewModel: viewModel)
                        }
                    } header: {
                        // The header tells the sections apart, so it needs a section above it, and
                        // albums below it.
                        if !viewModel.favourites.isEmpty && !viewModel.albums.isEmpty {
                            SectionHeader(title: "All Albums")
                        }
                    }
                }
                .padding(.horizontal, spacing)
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let message = viewModel.loadMoreError {
                    VStack(spacing: 8) {
                        Text(message).foregroundStyle(.secondary)
                        Button("Retry") { viewModel.submitAction(.retry) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct AlbumCell: View {
    let album: Album
    @ObservedObject var viewModel: AlbumsViewModel
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { CoverArt(image: album.coverArtID.flatMap { viewModel.artwork[$0] }).accessibilityHidden(true) }
                // The cover is fetched at the width this cell gives it (ALB-7).
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    guard let id = album.coverArtID, width > 0 else { return }
                    viewModel.submitAction(.artworkNeeded(coverArtID: id, pixelSize: Int((width * displayScale).rounded())))
                }
            Text(album.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(album.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .onAppear { viewModel.submitAction(.albumAppeared(album.id)) }
    }
}
