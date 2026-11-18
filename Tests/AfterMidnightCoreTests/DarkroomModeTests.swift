import XCTest
@testable import AfterMidnightCore

final class DarkroomModeTests: XCTestCase {
    private var directory: URL!
    private var session: HoldSession!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        session = HoldSession(stateFilePath: directory.appendingPathComponent("active").path,
                              pidFilePath: directory.appendingPathComponent("pid").path)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testFailedLaunchLeavesSessionInactive() {
        XCTAssertThrowsError(try session.toggle(invert: false, keepActive: false, executable: directory.appendingPathComponent("missing").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.stateFilePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.pidFilePath))
    }

    func testStaleRecordsLeaveUnrelatedProcessRunning() throws {
        let other = Process()
        other.executableURL = URL(fileURLWithPath: "/bin/sleep")
        other.arguments = ["30"]
        try other.run()
        defer {
            if other.isRunning { other.terminate() }
            other.waitUntilExit()
        }
        for record in ["\(other.processIdentifier) 0.0", "\(other.processIdentifier)"] {
            try record.write(toFile: session.pidFilePath, atomically: true, encoding: .utf8)
            try session.stop()
            XCTAssertTrue(other.isRunning)
            XCTAssertFalse(FileManager.default.fileExists(atPath: session.pidFilePath))
        }
    }

    func testHandoffWaitsUntilOutgoingHelperFinishesCleanup() throws {
        let helper = directory.appendingPathComponent("helper")
        let ready = directory.appendingPathComponent("ready")
        let restored = directory.appendingPathComponent("restored")
        let script = """
        #!/bin/sh
        cd "$(dirname "$0")" || exit 1
        trap 'sleep 0.2; touch restored; exit 0' TERM
        touch ready
        while true; do sleep 0.05; done
        """
        try script.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        XCTAssertTrue(try session.toggle(invert: true, keepActive: false, executable: helper.path))
        XCTAssertEqual(try String(contentsOfFile: session.stateFilePath), "invert")
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: ready.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: ready.path))
        XCTAssertFalse(try session.toggle(invert: false, keepActive: false, executable: helper.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.stateFilePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.pidFilePath))
    }
}
