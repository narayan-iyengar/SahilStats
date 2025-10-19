//
//  DebugLogger.swift
//  SahilStats
//
//  Global logging utility that respects verbose logging settings
//

import Foundation

/// Global logging function that only prints when verbose logging is enabled
/// Uses UserDefaults directly to avoid circular dependency with SettingsManager
/// - Parameters:
///   - items: Items to print
///   - separator: String to use as separator between items (default: space)
///   - terminator: String to print at the end (default: newline)
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    // Check UserDefaults directly to avoid circular dependency
    guard UserDefaults.standard.bool(forKey: "verboseLoggingEnabled") else { return }

    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
}

/// Force print regardless of verbose logging setting (use sparingly for critical errors)
/// - Parameters:
///   - items: Items to print
///   - separator: String to use as separator between items (default: space)
///   - terminator: String to print at the end (default: newline)
func forcePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
}
