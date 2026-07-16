import XCTest

@testable import DiskMeerkatApp

@MainActor
final class ContentViewTests: XCTestCase {
    func testBodyCanBeBuilt() {
        _ = ContentView().body
    }
}
