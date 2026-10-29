import SwiftUI

/// The signed-in app's main screen: Albums and Songs tabs (ALB-1), with the now-playing bar above
/// the tab bar on both and on every screen pushed from them (PLAY-2).
struct MainView: View {
    /// The now-playing bar's ViewModel.
    @ObservedObject var viewModel: PlayerViewModel
    /// The Albums tab, inside the stack the host keeps for pushed screens.
    let albums: AnyView
    let songs: LibraryView

    var body: some View {
        TabView {
            Tab("Albums", systemImage: "square.grid.2x2") { albums }
            Tab("Songs", systemImage: "music.note.list") { songs }
        }
        .tabViewBottomAccessory(isEnabled: viewModel.track != nil) {
            NowPlayingBar(viewModel: viewModel)
        }
    }
}
