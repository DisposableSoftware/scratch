import Foundation
import Testing
@testable import Scratch

struct AppRouterTests {
    private let account = SavedServer.sample

    private func next(from step: AppStep, account: SavedServer?) -> AppStep? {
        AppRouter(sessionState: SessionState(server: account)).nextStep(from: step, with: AppFlowData())
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
