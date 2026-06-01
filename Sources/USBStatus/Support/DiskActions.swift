import AppKit
import Foundation

enum DiskActionError: LocalizedError {
    case missingMountPoint
    case unmountFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingMountPoint:
            "Volume is not mounted."
        case .unmountFailed(let message):
            message.isEmpty ? "Unmount failed." : message
        }
    }
}

enum DiskActions {
    @MainActor
    static func revealInFinder(_ volume: USBVolume) throws {
        guard let mountPoint = volume.mountPoint, !mountPoint.isEmpty else {
            throw DiskActionError.missingMountPoint
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: mountPoint)])
    }

    static func unmount(_ volume: USBVolume) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["unmount", volume.deviceIdentifier]
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw DiskActionError.unmountFailed(message)
            }
        }.value
    }
}
