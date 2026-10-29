import FoundationModels
import Testing
@testable import Scratch

struct OnDeviceMixModelGatewayTests {
    // MIX-1: the tab follows the system model's availability. The model itself runs only on a
    // device or Mac with Apple Intelligence, so asking it is a manual check.
    // MIX-6: the shortlist is numbered from 1, one short line per track.
    @Test func theShortlistIsNumberedFromOneWithTheDetailsTheServerHas() {
        let tracks = [
            Track(id: "long-server-id-1", title: "Scars", artist: "Mitsuda", album: "Chrono Cross", duration: 1, coverArtID: nil, year: 2000, genre: "Game"),
            Track(id: "long-server-id-2", title: "Bare", artist: "Nobody", album: "", duration: nil, coverArtID: nil),
        ]

        let prompt = OnDeviceMixModelGateway.prompt(for: tracks)

        #expect(prompt == "1. Scars by Mitsuda (Chrono Cross, 2000, Game)\n2. Bare by Nobody")
        #expect(!prompt.contains("long-server-id"))
    }

    @Test func itIsAvailableWhenTheSystemModelIs() {
        let gateway = OnDeviceMixModelGateway()

        #expect(gateway.isAvailable == (SystemLanguageModel.default.availability == .available))
    }
}
