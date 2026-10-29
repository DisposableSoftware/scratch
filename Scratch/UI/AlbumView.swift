import SwiftUI

/// One album: its cover, its info, Play, and the tracks by disc (ALB-9). It is pushed onto the
/// Albums tab's stack, which gives it the navigation bar and the back button.
struct AlbumView: View {
    @ObservedObject var viewModel: AlbumViewModel
    @Environment(\.displayScale) private var displayScale

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
        VStack(spacing: 16) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { CoverArt(image: viewModel.cover).accessibilityHidden(true) }
                .frame(maxWidth: 360)
                // The cover is fetched at the width it is shown at.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    guard width > 0 else { return }
                    viewModel.submitAction(.artworkNeeded(pixelSize: Int((width * displayScale).rounded())))
                }
            VStack(spacing: 4) {
                Text(viewModel.album.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if !viewModel.album.artist.isEmpty {
                    Text(viewModel.album.artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.details.isEmpty {
                    Text(viewModel.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    viewModel.submitAction(.playTapped)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    viewModel.submitAction(.shuffleTapped)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(viewModel.phase != .loaded)
        }
        .frame(maxWidth: .infinity)
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

private struct TrackLine: View {
    let row: AlbumRow

    var body: some View {
        HStack(spacing: 12) {
            Text(row.number)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
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
            if let duration = row.duration {
                Text(duration)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
