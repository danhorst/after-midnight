import XCTest
@testable import AfterMidnightCore

final class DarkroomModeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(atPath: DarkroomMode.stateFilePath)
    }

    override func tearDown() {
        DarkroomMode.disable()
        super.tearDown()
    }

    func testInitialStateIsInactive() {
        XCTAssertFalse(DarkroomMode.isActive)
    }

    func testToggleOnFromInactive() {
        let result = DarkroomMode.toggle()
        XCTAssertTrue(result)
        XCTAssertTrue(DarkroomMode.isActive)
    }

    func testToggleOffFromActive() {
        DarkroomMode.toggle() // ON
        let result = DarkroomMode.toggle() // OFF
        XCTAssertFalse(result)
        XCTAssertFalse(DarkroomMode.isActive)
    }

    func testStateFilePath() {
        XCTAssertTrue(DarkroomMode.stateFilePath.hasSuffix("/.am_active"))
        XCTAssertTrue(DarkroomMode.stateFilePath.hasPrefix(NSTemporaryDirectory()))
    }
}
