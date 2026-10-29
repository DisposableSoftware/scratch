import SwiftUI

/// The signed-in app's main screen: Albums, Playlists and Songs tabs (ALB-1), with the now-playing bar above
/// the tab bar on both and on every screen pushed from them (PLAY-2).
struct MainView: View {
    /// The now-playing bar's ViewModel.
    @ObservedObject var viewModel: PlayerViewModel

    /// The Albums tab, inside the stack the host keeps for pushed screens.
    let albums: AnyView

    /// The Playlists tab, inside a stack of its own (PLST-6).
    let playlists: AnyView
    let songs: LibraryView

    var body: some View {
        TabView {
            Tab("Albums", systemImage: "square.grid.2x2") { albums }
            Tab("Playlists", systemImage: "music.note.square.stack") { playlists }
            Tab("Songs", systemImage: "music.note.list") { songs }
        }
        .tabViewBottomAccessory(isEnabled: viewModel.track != nil) {
            NowPlayingBar(viewModel: viewModel)
        }
    }
}
