import Combine

/// The mixes made so far, and whether the on-device model can make more. MixUseCase fills it; the
/// Me tab shows it (MIX-1, MIX-9).
final class MixesState: ObservableObject {
    @Published var isModelAvailable = false
    @Published var mixes: [Mix] = []
}
