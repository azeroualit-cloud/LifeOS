import XCTest
@testable import LifeOSProbe

final class NativeBloomAutoFilterTests: XCTestCase {
    private func link(_ url: String) -> Record { ["id": .string(UUID().uuidString), "kind": .string("link"), "urlString": .string(url)] }

    func testSourceIsReadFromTheSavedLinkIncludingSubdomains() {
        XCTAssertTrue(NativeBloomAutoFilter.instagram.matches(link("https://www.instagram.com/reel/abc")))
        XCTAssertTrue(NativeBloomAutoFilter.youtube.matches(link("https://youtu.be/abc")))
        XCTAssertTrue(NativeBloomAutoFilter.youtube.matches(link("https://m.youtube.com/watch?v=abc")))
        XCTAssertTrue(NativeBloomAutoFilter.tiktok.matches(link("https://vm.tiktok.com/abc")))
        XCTAssertTrue(NativeBloomAutoFilter.web.matches(link("https://example.org/articolo")))
        XCTAssertFalse(NativeBloomAutoFilter.web.matches(link("https://www.instagram.com/p/abc")))
        XCTAssertFalse(NativeBloomAutoFilter.instagram.matches(link("https://notinstagram.com/p/abc")))
    }

    func testNotesAndPlacesAreSeparateFromLinks() {
        let note: Record = ["id": .string(UUID().uuidString), "kind": .string("text"), "text": .string("Idea")]
        var place = note
        place["place"] = .object(["name": .string("Bar"), "latitude": .number(43.7), "longitude": .number(10.9)])
        XCTAssertTrue(NativeBloomAutoFilter.notes.matches(note))
        XCTAssertFalse(NativeBloomAutoFilter.notes.matches(place))
        XCTAssertTrue(NativeBloomAutoFilter.places.matches(place))
        XCTAssertFalse(NativeBloomAutoFilter.notes.matches(link("https://example.org")))
        let noteWithLink: Record = ["id": .string(UUID().uuidString), "kind": .string("text"), "noteLinks": .array([.string("https://www.tiktok.com/@a/video/1")])]
        XCTAssertTrue(NativeBloomAutoFilter.tiktok.matches(noteWithLink))
    }

    func testOnlyFiltersWithContentAreOffered() {
        XCTAssertEqual(NativeBloomAutoFilter.available(in: []), [.all])
        let rows = [link("https://www.youtube.com/watch?v=1"), link("https://example.org")]
        XCTAssertEqual(NativeBloomAutoFilter.available(in: rows), [.all, .youtube, .web])
        for row in rows { XCTAssertTrue(NativeBloomAutoFilter.all.matches(row)) }
    }
}
