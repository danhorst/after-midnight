import Foundation
import Darwin

struct HoldSession {
    let stateFilePath: String
    let pidFilePath: String

    func withLock<T>(_ action: () throws -> T) throws -> T {
        let fd = open(pidFilePath + ".lock", O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        while flock(fd, LOCK_EX) != 0 {
            if errno != EINTR { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        return try action()
    }

    func toggle(invert: Bool, keepActive: Bool, executable: String) throws -> Bool {
        try withLock {
            let next = keepActive || !FileManager.default.fileExists(atPath: stateFilePath)
            try stop()
            try clearActiveMarker()
            if next { try start(invert: invert, executable: executable) }
            return next
        }
    }

    func clearActiveMarker() throws {
        do {
            try FileManager.default.removeItem(atPath: stateFilePath)
        } catch CocoaError.fileNoSuchFile {}
    }

    func start(invert: Bool, executable: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = invert ? ["--hold", "--invert"] : ["--hold"]
        task.standardInput  = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try task.run()
        do {
            guard let info = try processInfo(task.processIdentifier) else { throw POSIXError(.ESRCH) }
            let record = "\(task.processIdentifier) \(birthTime(info))"
            try record.write(toFile: pidFilePath, atomically: true, encoding: .utf8)
            try DarkroomMode.stateContent(invert: invert).write(toFile: stateFilePath, atomically: true, encoding: .utf8)
        } catch {
            if task.isRunning { task.terminate() }
            task.waitUntilExit()
            try? FileManager.default.removeItem(atPath: pidFilePath)
            throw error
        }
    }

    func stop() throws {
        let raw: String
        do {
            raw = try String(contentsOfFile: pidFilePath)
        } catch CocoaError.fileReadNoSuchFile {
            return
        }
        let fields = raw.split(whereSeparator: { $0.isWhitespace })
        if let first = fields.first, let pid = pid_t(first), pid > 1,
           var info = try processInfo(pid) {
            let birth = birthTime(info)
            // Older releases recorded only a PID. Restrict those records to am.
            let matches = fields.count == 1
                ? withUnsafeBytes(of: &info.pbi_comm) { $0.prefix(while: { $0 != 0 }).elementsEqual("am".utf8) }
                : fields.count == 2 && fields[1] == birth
            if matches {
                if kill(pid, SIGTERM) != 0 && errno != ESRCH {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                // A replacement CLI or the app isn't the helper's parent.
                let deadline = DispatchTime.now() + .seconds(3)
                while let live = try processInfo(pid), birthTime(live) == birth, live.pbi_status != SZOMB {
                    guard DispatchTime.now() < deadline else { throw POSIXError(.ETIMEDOUT) }
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
        }
        try FileManager.default.removeItem(atPath: pidFilePath)
    }

    private func processInfo(_ pid: pid_t) throws -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout.size(ofValue: info))
        if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size { return info }
        if errno == ESRCH { return nil }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    private func birthTime(_ info: proc_bsdinfo) -> String {
        "\(info.pbi_start_tvsec).\(info.pbi_start_tvusec)"
    }
}
