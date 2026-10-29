/// A server the app is signed in to, with what it needs to sign requests.
struct SavedServer: Equatable {
    var account: ServerAccount
    var credentials: SubsonicCredentials
}
