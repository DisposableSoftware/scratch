import SwiftUI

/// The Me tab: a card for each mix, with the model's name for it and a line about it (MIX-2).
struct MixesView: View {
    @ObservedObject var viewModel: MixesViewModel

    /// The host puts this inside the navigation stack that mixes are pushed onto (MIX-10), so the
    /// title and the settings button below belong to that stack's bar.
    var body: some View {
        content
            .navigationTitle("Me")
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
        if !viewModel.mixes.isEmpty {
            List {
                ForEach(viewModel.mixes) { mix in
                    MixCard(mix: mix, viewModel: viewModel)
                }

                if viewModel.isMaking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { _ = await viewModel.handleAction(.refresh) }
        } else {
            switch viewModel.phase {
            case .loading, .loaded:
                ProgressView()
            case .empty:
                List {}
                    .overlay {
                        ContentUnavailableView("Nothing to mix yet", systemImage: "person.crop.circle", description: Text("Heart some songs and play some music, and your mixes will turn up here."))
                    }
                    .refreshable { _ = await viewModel.handleAction(.refresh) }

            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't make your mixes", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { viewModel.submitAction(.retry) }
                }
            }
        }
    }
}

private struct MixCard: View {
    let mix: Mix
    @ObservedObject var viewModel: MixesViewModel
    @Environment(\.displayScale) private var displayScale

    private static let side: CGFloat = 72

    var body: some View {
        Button {
            viewModel.submitAction(.mixTapped(mix.kind))
        } label: {
            HStack(spacing: 12) {
                CoverArt(image: mix.tracks.first?.coverArtID.flatMap { viewModel.artwork[$0] })
                    .frame(width: Self.side, height: Self.side)
                    .accessibilityHidden(true)
                    .onAppear {
                        if let id = mix.tracks.first?.coverArtID {
                            viewModel.submitAction(.artworkNeeded(coverArtID: id, pixelSize: Int((Self.side * displayScale).rounded())))
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(mix.name).font(.headline).lineLimit(1)
                    Text(mix.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(mix.tracks.count == 1 ? "1 song" : "\(mix.tracks.count) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
