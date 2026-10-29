import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let account = viewModel.account {
                    Section("Server") {
                        LabeledContent("Address", value: account.baseURL.absoluteString)
                        LabeledContent("Username", value: account.username)
                        Button("Sign Out", role: .destructive) { viewModel.submitAction(.signOut) }
                    }
                }

                Section("Albums") {
                    Picker("Albums per row", selection: viewModel.binding(\.albumsPerRow, to: { .albumsPerRowChanged($0) })) {
                        ForEach(AlbumsPerRow.range, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Appearance") {
                    Picker("Flavour", selection: viewModel.binding(\.flavour, to: { .flavourChanged($0) })) {
                        ForEach(Flavour.allCases, id: \.self) { flavour in
                            Text(flavour.label).tag(flavour)
                        }
                    }

                    accentSwatches
                }

                qualitySection(.wifi, title: "On Wi-Fi", quality: viewModel.transcoding.wifi)
                qualitySection(.cellular, title: "On cellular", quality: viewModel.transcoding.cellular)
                Section {
                } footer: {
                    Text("Changes apply from the next track. Only MP3 and AAC can be capped, and the server does the transcoding, so it needs them set up.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.submitAction(.done) }
                }
            }
        }
    }

    /// The accents, each drawn as the chosen flavour draws it (LOOK-5).
    private var accentSwatches: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
            ForEach(Accent.allCases, id: \.self) { accent in
                let chosen = accent == viewModel.accent

                Button { viewModel.submitAction(.accentChanged(accent)) } label: {
                    Circle()
                        .fill(Color(accent, in: viewModel.flavour))
                        .frame(width: 28, height: 28)
                        .overlay { if chosen { Circle().stroke(.primary, lineWidth: 2).padding(-4) } }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.label)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }

    private func qualitySection(_ network: NetworkKind, title: String, quality: StreamQuality) -> some View {
        Section(title) {
            Picker("Format", selection: viewModel.binding(formatPath(network), to: { .formatChanged(network, $0) })) {
                ForEach(StreamQuality.Format.allCases, id: \.self) { format in
                    Text(format.label).tag(format)
                }
            }

            Picker("Maximum bitrate", selection: viewModel.binding(bitRatePath(network), to: { .maxBitRateChanged(network, $0) })) {
                Text("Unlimited").tag(Int?.none)
                ForEach(StreamQuality.bitRates, id: \.self) { rate in
                    Text("\(rate) kbps").tag(Int?.some(rate))
                }
            }

            // TRANS-2: the server can't cap the original file.
            .disabled(quality.format == .original)
        }
    }

    private func formatPath(_ network: NetworkKind) -> KeyPath<SettingsViewModel, StreamQuality.Format> {
        switch network {
        case .wifi: \.transcoding.wifi.format
        case .cellular: \.transcoding.cellular.format
        }
    }

    private func bitRatePath(_ network: NetworkKind) -> KeyPath<SettingsViewModel, Int?> {
        switch network {
        case .wifi: \.transcoding.wifi.maxBitRate
        case .cellular: \.transcoding.cellular.maxBitRate
        }
    }
}

extension StreamQuality.Format {
    var label: String {
        switch self {
        case .original: "Original"
        case .mp3: "MP3"
        case .aac: "AAC"
        }
    }
}
