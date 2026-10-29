import Foundation

/// Where the app keeps what it stores, as the architecture note's `environment`. Tests use their
/// own, so they never see or change the app's.
struct AppEnvironment {
    var defaults: UserDefaults
    var keychainService: String

    static let live = AppEnvironment(defaults: .standard, keychainService: "lol.weston.scratch")
}
