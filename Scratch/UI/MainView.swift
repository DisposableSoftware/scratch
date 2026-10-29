import SwiftUI

/// The signed-in app's main screen: Albums, Playlists, Songs and Me tabs (ALB-1, MIX-1), with the
/// now-playing bar above the tab bar on all of them and on every screen pushed from them (PLAY-2).
struct MainView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// The Albums tab, inside the stack the host keeps for pushed screens.
    let albums: AnyView

    /// The Playlists tab, inside a stack of its own (PLST-6).
    let playlists: AnyView
    let songs: LibraryView

    /// The Me tab, inside a stack of its own (MIX-10). It shows only while the model is available.
    let me: AnyView

    var body: some View {
        TabView {
            Tab("Albums", systemImage: "square.grid.2x2") { albums }
            Tab("Playlists", systemImage: "music.note.square.stack") { playlists }
            Tab("Songs", systemImage: "music.note.list") { songs }

            if viewModel.showsMe {
                Tab("Me", systemImage: "person.crop.circle") { me }
            }
        }
        .tabViewBottomAccessory(isEnabled: viewModel.hasTrack) {
            NowPlayingBar(viewModel: viewModel.player)
        }
        .onAppear { viewModel.submitAction(.lifecycle(.viewDidAppear)) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.submitAction(.appBecameActive) }
        }
    }
}
