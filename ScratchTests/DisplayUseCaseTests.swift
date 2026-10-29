import Testing
@testable import Scratch

struct DisplayUseCaseTests {
    private let gateway = SettingsGatewayMock()
    private let state = DisplayState()
    private var useCase: DefaultDisplayUseCase { DefaultDisplayUseCase(settingsGateway: gateway, displayState: state) }

    @Test func twoPerRowUntilTheUserSaysOtherwise() {
        _ = useCase
        #expect(state.albumsPerRow == 2 && AlbumsPerRow.default == 2)
    }

    @Test func theRangeIsOneToFive() {
        #expect(Array(AlbumsPerRow.range) == [1, 2, 3, 4, 5])
    }

    @Test func aSavedChoiceComesBackAtStart() {
        gateway.savedAlbumsPerRow = 4
        _ = useCase
        #expect(state.albumsPerRow == 4)
    }

    @Test(arguments: [(0, 1), (-3, 1), (6, 5), (99, 5)])
    func aSavedValueOutOfRangeIsBroughtIn(saved: Int, expected: Int) {
        gateway.savedAlbumsPerRow = saved
        _ = useCase
        #expect(state.albumsPerRow == expected)
    }

    @Test func aChoiceIsSavedAndAppliedAtOnce() {
        let useCase = useCase

        useCase.setAlbumsPerRow(5)

        #expect(state.albumsPerRow == 5 && gateway.savedAlbumsPerRow == 5)
        #expect(DefaultDisplayUseCase(settingsGateway: gateway, displayState: DisplayState()).state.albumsPerRow == 5)
    }

    @Test(arguments: [(0, 1), (7, 5)])
    func aChoiceOutOfRangeIsBroughtIn(asked: Int, expected: Int) {
        let useCase = useCase
        useCase.setAlbumsPerRow(asked)
        #expect(state.albumsPerRow == expected && gateway.savedAlbumsPerRow == expected)
    }

    @Test func nothingReadableSavedMeansTheDefault() {
        gateway.savedAlbumsPerRow = nil
        _ = useCase
        #expect(state.albumsPerRow == AlbumsPerRow.default)
    }
}
