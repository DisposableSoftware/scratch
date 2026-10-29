import SwiftUI
import UIKit

/// Draws a view the way the app would show it, in a real window, so a `List` or a navigation
/// bar is in the picture, which `ImageRenderer` can't do. Needs the app as the test host.
enum WindowSnapshot {
    static func image<V: View>(of view: V, size: CGSize) async -> UIImage? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }

        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: NavigationStack { view })
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Let the layout and any images settle.
        try? await Task.sleep(for: .milliseconds(800))

        return UIGraphicsImageRenderer(size: size).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
