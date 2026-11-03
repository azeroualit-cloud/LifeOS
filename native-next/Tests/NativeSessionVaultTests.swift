import XCTest
import Foundation
import Security
@testable import LifeOSProbe

@MainActor final class NativeSessionVaultTests: XCTestCase {
    private let fixtureOrigin = "https://release-startup.lifeos.invalid"
    private func cookie(value: String, expires: Date) throws -> HTTPCookie {
        try XCTUnwrap(HTTPCookie(properties: [.name: "liquidita_session", .value: value,
            .domain: "release-startup.lifeos.invalid", .path: "/", .secure: "TRUE", .expires: expires]))
    }
    private func remove(_ origin: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "LifeOS.session.v1", kSecAttrAccount as String: origin] as CFDictionary)
    }
    func testRestoreKeepsFutureCookieAndDropsExpiredCookie() throws {
        let origin = "https://session-test-" + UUID().uuidString.lowercased() + ".invalid"
        defer { remove(origin) }
        let future = try cookie(value: "synthetic-valid", expires: Date().addingTimeInterval(3600))
        let past = try cookie(value: "synthetic-expired", expires: Date().addingTimeInterval(-3600))
        XCTAssertTrue(SessionVault.save([future, past], origin: origin))
        let restored = SessionVault.load(origin: origin)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.value, "synthetic-valid")
    }
    func testPrepareSyntheticSavedSessionForReleaseStartup() throws {
        #if targetEnvironment(simulator)
        // The following Release smoke run restores this reserved-domain fixture.
        // No user credentials or real server are used; the CI simulator is ephemeral.
        remove(fixtureOrigin)
        XCTAssertTrue(SessionVault.save([try cookie(value: "release-startup-fixture", expires: Date().addingTimeInterval(86400))], origin: fixtureOrigin))
        XCTAssertEqual(SessionVault.load(origin: fixtureOrigin).count, 1)
        #else
        throw XCTSkip("Synthetic release-launch fixture is simulator-only")
        #endif
    }
}
