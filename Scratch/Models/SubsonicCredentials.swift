import CryptoKit
import Foundation

/// Subsonic token authentication (SRV-4): the server checks `md5(password + salt) == token`, so a
/// fixed salt and token pair signs every request and the password itself is never kept.
struct SubsonicCredentials: Equatable {
    var username: String
    var salt: String
    var token: String

    static func derive(username: String, password: String, salt: String = randomSalt()) -> SubsonicCredentials {
        let digest = Insecure.MD5.hash(data: Data((password + salt).utf8))
        let token = digest.map { String(format: "%02x", $0) }.joined()
        return SubsonicCredentials(username: username, salt: salt, token: token)
    }

    static func randomSalt() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }
}
