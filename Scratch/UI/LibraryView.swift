import SwiftUI

/// The library screen. Its contents arrive with LIB-1; for now it is the step the Router
/// leads to once signed in.
struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("No tracks yet", systemImage: "music.note.list")
                .navigationTitle("Library")
        }
    }
}
