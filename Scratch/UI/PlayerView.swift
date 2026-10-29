import SwiftUI

/// The bar above the tab bar while a track is loaded (PLAY-2). It sits in the tab view's bottom
/// accessory, which draws its own background. Tapping it opens the player.
struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.displayScale) private var displayScale
    @Environment(\.theme) private var theme

    private static let artSide: CGFloat = 40

    var body: some View {
        if let track = viewModel.track {
            HStack(spacing: 12) {
                Button {
                    viewModel.submitAction(.barTapped)
                } label: {
                    HStack(spacing: 12) {
                        CoverArt(image: viewModel.artwork[pixelSize])
                            .frame(width: Self.artSide, height: Self.artSide)
                            .onAppear { viewModel.submitAction(.artworkNeeded(pixelSize: pixelSize)) }
                            .onChange(of: track.id) { viewModel.submitAction(.artworkNeeded(pixelSize: pixelSize)) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).lineLimit(1)
                            Text(viewModel.status == .failed ? "Couldn't play this track" : track.artist)
                                .font(.subheadline)
                                .foregroundStyle(viewModel.status == .failed ? theme.error : .secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the player")
                Button {
                    viewModel.submitAction(.playPause)
                } label: {
                    Image(systemName: playPauseSymbol(viewModel))
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(playPauseLabel(viewModel))
            }
            .padding(.horizontal)
        }
    }

    private var pixelSize: Int { Int((Self.artSide * displayScale).rounded()) }
}

/// The player sheet (PLAY-3).
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale

    private static let artSide: CGFloat = 300

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            Spacer(minLength: 0)
            CoverArt(image: viewModel.artwork[pixelSize])
                .frame(width: Self.artSide, height: Self.artSide)
                .shadow(radius: 12, y: 6)
                .onAppear { viewModel.submitAction(.artworkNeeded(pixelSize: pixelSize)) }
                .onChange(of: viewModel.track?.id) { viewModel.submitAction(.artworkNeeded(pixelSize: pixelSize)) }
            VStack(spacing: 4) {
                Text(viewModel.track?.title ?? "").font(.title2.bold()).lineLimit(2)
                Text(viewModel.track?.artist ?? "").foregroundStyle(.secondary)
                Text(viewModel.track?.album ?? "").font(.subheadline).foregroundStyle(.secondary)

                if let quality = viewModel.quality {
                    Text(quality.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .padding(.top, 4)
                        .accessibilityLabel("Quality: \(quality.label)")
                }
            }
            .multilineTextAlignment(.center)

            if viewModel.status == .failed {
                Label("Couldn't play this track. Press play to try again.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(theme.error)
            }

            VStack(spacing: 4) {
                Slider(
                    value: viewModel.binding(\.position, to: { .scrubbed($0) }),
                    in: 0...max(viewModel.duration ?? 0, 1)
                ) { editing in
                    if !editing { viewModel.submitAction(.scrubEnded) }
                }
                .disabled(viewModel.duration == nil || viewModel.status == .failed)
                HStack {
                    Text(viewModel.position.clock)
                    Spacer()

                    if let duration = viewModel.duration {
                        Text("-" + max(duration - viewModel.position, 0).clock)
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 48) {
                Button { viewModel.submitAction(.previous) } label: {
                    Image(systemName: "backward.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous")
                Button { viewModel.submitAction(.playPause) } label: {
                    Image(systemName: playPauseSymbol(viewModel)).font(.system(size: 56))
                }
                .accessibilityLabel(playPauseLabel(viewModel))
                Button { viewModel.submitAction(.next) } label: {
                    Image(systemName: "forward.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next")
            }
            .font(.title)
            .tint(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.bottom)
        .onDisappear { viewModel.submitAction(.scrubCancelled) }
    }

    private var pixelSize: Int { Int((Self.artSide * displayScale).rounded()) }
}

private func playPauseLabel(_ viewModel: PlayerViewModel) -> String {
    switch viewModel.status {
    case .playing, .loading: "Pause"
    case .failed: "Try again"
    case .paused, .stopped: "Play"
    }
}

private func playPauseSymbol(_ viewModel: PlayerViewModel) -> String {
    switch viewModel.status {
    case .playing, .loading: "pause.fill"
    case .failed: "arrow.clockwise"
    case .paused, .stopped: "play.fill"
    }
}

extension StreamQuality {
    /// As the player shows it (TRANS-6): "MP3 · 192 kbps", "AAC", "Original".
    var label: String {
        guard let maxBitRate else { return format.label }

        return "\(format.label) · \(maxBitRate) kbps"
    }
}

extension TimeInterval {
    /// m:ss, as player times are shown.
    var clock: String {
        Duration.seconds(Int(self.rounded(.down))).formatted(.time(pattern: .minuteSecond))
    }
}
