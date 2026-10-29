import Foundation

/// The server the user is signed in to.
struct ServerAccount: Equatable {
    var baseURL: URL
    var username: String
}
