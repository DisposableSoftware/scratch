import SwiftUI
import UIKit
@testable import Scratch

/// Draws a view the way the app would show it, in a real window, so a `List` or a navigation
/// bar is in the picture, which `ImageRenderer` can't do. Needs the app as the test host. With a
/// theme, the view gets the tint, the theme and the light or dark window that RootView gives the
/// app (LOOK-2, LOOK-4).
enum WindowSnapshot {
    static func image<V: View>(of view: V, size: CGSize, theme: Theme? = nil) async -> UIImage? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }

        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: NavigationStack { view }.tint(theme?.accent).environment(\.theme, theme ?? .standard))
        window.overrideUserInterfaceStyle = switch theme?.colorScheme {
        case .light: .light
        case .dark: .dark
        default: .unspecified
        }
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Let the layout and any images settle.
        try? await Task.sleep(for: .milliseconds(800))

        return UIGraphicsImageRenderer(size: size).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
