//
//  AppLogger.swift
//  SahilStats
//
//  Dual console + disk logging
//  Writes to Documents/recorder.txt or Documents/controller.txt
//

import Foundation

class AppLogger {
    static let shared = AppLogger()

    private var logFile: URL?
    private let queue = DispatchQueue(label: "com.sahilstats.logger", qos: .utility)
    private var fileHandle: FileHandle?

    private init() {
        setupLogFile()
    }

    deinit {
        fileHandle?.closeFile()
    }

    private func setupLogFile() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Documents directory for logging")
            return
        }

        // Determine filename based on multipeer role
        let role = MultipeerConnectivityManager.shared.savedDeviceRole
        let filename: String

        switch role {
        case .recordingDevice:
            filename = "recorder.txt"
        case .controlDevice:
            filename = "controller.txt"
        case .none:
            filename = "app.txt"  // Fallback if role not set yet
        }

        logFile = docs.appendingPathComponent(filename)

        // Create or truncate file at startup
        if let logFile = logFile {
            let header = """
            ================================
            SahilStats Log - \(filename)
            Started: \(Date().formatted(date: .complete, time: .standard))
            Device: \(UIDevice.current.name)
            Role: \(role?.rawValue ?? "unknown")
            ================================

            """

            try? header.write(to: logFile, atomically: true, encoding: .utf8)

            // Open file handle for appending
            if let handle = try? FileHandle(forWritingTo: logFile) {
                fileHandle = handle
                handle.seekToEndOfFile()
            }

            print("📝 Logging to: \(logFile.path)")
        }
    }

    /// Log message to both console and disk
    func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let logLine = "[\(timestamp)] \(message)\n"

        // Always print to console for real-time monitoring
        print(message)

        // Append to disk file asynchronously
        queue.async { [weak self] in
            guard let self = self,
                  let handle = self.fileHandle,
                  let data = logLine.data(using: .utf8) else { return }

            handle.write(data)
        }
    }

    /// Get path to current log file for sharing/debugging
    func getLogFilePath() -> String? {
        return logFile?.path
    }
}

// Global convenience function to replace print()
func logPrint(_ message: String) {
    AppLogger.shared.log(message)
}
