import DiskMeerkatApp
import XCTest

@MainActor
final class ContentViewTests: XCTestCase {
    func testBodyCanBeBuilt() {
        _ = ContentView().body
    }
}
