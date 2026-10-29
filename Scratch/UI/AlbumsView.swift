import SwiftUI

/// The Albums tab. The grid arrives with ALB-2; until then it says so.
struct AlbumsView: View {
    @ObservedObject var viewModel: AlbumsViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Albums", systemImage: "square.grid.2x2", description: Text("The album grid is on its way."))
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
    }
}
