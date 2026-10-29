import Foundation
import Testing
@testable import Scratch

struct AppRouterTests {
    private let account = ServerAccount(baseURL: URL(string: "https://music.example.com")!, username: "me")

    private func next(from step: AppStep, account: ServerAccount?) -> AppStep? {
        AppRouter(sessionState: SessionState(account: account)).nextStep(from: step, with: AppFlowData())
    }

    @Test func launchWithoutASavedServerOpensSetup() {
        #expect(next(from: .launch, account: nil) == .setup)
    }

    @Test func launchWithASavedServerOpensTheLibrary() {
        #expect(next(from: .launch, account: account) == .library)
    }

    @Test func setupLeadsToTheLibraryOnceSignedIn() {
        #expect(next(from: .setup, account: account) == .library)
        #expect(next(from: .setup, account: nil) == nil)
    }

    @Test func theLibraryReturnsToSetupWhenSignedOut() {
        #expect(next(from: .library, account: nil) == .setup)
        #expect(next(from: .library, account: account) == nil)
    }
}
