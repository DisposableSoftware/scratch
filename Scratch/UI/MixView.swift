import SwiftUI

/// One mix: its name and description, Play, Shuffle and the tracks in order (MIX-10). It is pushed
/// onto the Me tab's stack, which gives it the navigation bar and the back button.
struct MixView: View {
    @ObservedObject var viewModel: MixViewModel

    var body: some View {
        List {
            CollectionHeader(
                cover: viewModel.cover,
                title: viewModel.mix.name,
                subtitle: viewModel.mix.description,
                details: viewModel.mix.tracks.count == 1 ? "1 song" : "\(viewModel.mix.tracks.count) songs",
                actionsEnabled: true,
                artworkNeeded: { viewModel.submitAction(.artworkNeeded(pixelSize: $0)) },
                play: { viewModel.submitAction(.playTapped) },
                shuffle: { viewModel.submitAction(.shuffleTapped) }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)

            ForEach(viewModel.rows) { row in
                Button {
                    viewModel.submitAction(.trackTapped(row.id))
                } label: {
                    TrackLine(row: row.line)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle(viewModel.mix.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
