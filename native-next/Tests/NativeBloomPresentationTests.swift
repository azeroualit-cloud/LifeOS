import XCTest
@testable import LifeOSProbe

final class NativeBloomPresentationTests: XCTestCase {
    func testNoteAndCategoryRowsRetainDistinctUUIDsAcrossContentUpdates() {
        let ids = [UUID().uuidString, UUID().uuidString]
        let rows = ids.map { NativeBloomRow(["id": .string($0), "title": .string("Titolo")]) }
        XCTAssertEqual(rows.map(\.id), ids)
        XCTAssertEqual(Set(rows.map(\.id)).count, 2)
        var edited = rows[0].value; edited["title"] = .string("Modificato")
        XCTAssertEqual(NativeBloomRow(edited).id, ids[0])
    }
    func testMarkdownPreservesTablesCodeAndCompactTitleOnlyContent() {
        let blocks = NativeBloomMarkdownBlock.parse("# Titolo\n\n| A | B |\n| --- | --- |\n| Uno | Due |\n\n```swift\nlet n = 1\n```")
        XCTAssertEqual(blocks.count, 3)
        if case .table(let headers, let rows) = blocks[1].kind { XCTAssertEqual(headers, ["A", "B"]); XCTAssertEqual(rows, [["Uno", "Due"]]) }
        else { XCTFail("Table must remain structured") }
        if case .code = blocks[2].kind { XCTAssertEqual(blocks[2].text, "let n = 1") }
        else { XCTFail("Code block missing") }
    }
    func testRediscoveryIsStableBoundedAndExcludesTrash() {
        let ids = (0..<40).map { _ in UUID() }
        let candidates = ids.enumerated().map { index, id in NativeBloomRediscoveryCandidate(id: id, kind: index.isMultiple(of: 2) ? "text" : "link", collectionID: nil, host: nil, isArchived: index == 0) }
        let first = NativeBloomRediscoveryPlanner.select(candidates, day: 100, round: 2)
        XCTAssertEqual(first.count, 30); XCTAssertEqual(Set(first).count, 30)
        XCTAssertFalse(first.contains(ids[0]))
        XCTAssertEqual(first, NativeBloomRediscoveryPlanner.select(candidates, day: 100, round: 2))
        XCTAssertNotEqual(first, NativeBloomRediscoveryPlanner.select(candidates, day: 100, round: 3))
    }
    func testUnknownPlaceKindKeepsLocation() throws {
        let data = Data("{\"name\":\"Luogo\",\"latitude\":43.0,\"longitude\":11.0,\"kind\":\"future-kind\"}".utf8)
        let place = try JSONDecoder().decode(NativeBloomPlace.self, from: data)
        XCTAssertTrue(place.isValid); XCTAssertEqual(place.resolvedKind, .other)
    }
}
