//
//  LogoBank.swift
//  SahilStats
//
//  Logo Bank system for team logos
//

import Foundation
import FirebaseFirestore

// MARK: - Logo Bank Item

struct LogoBankItem: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var teamName: String
    var logoURL: String // Firebase Storage URL
    var category: LogoCategory
    var uploadedBy: String? // User email who uploaded (for custom logos)
    var isPublic: Bool // Whether logo is visible to all users
    @ServerTimestamp var createdAt: Date?

    enum LogoCategory: String, Codable, CaseIterable {
        case aau = "AAU Teams"
        case localLeague = "Local Leagues"
        case school = "Schools"
        case custom = "Custom"

        var displayName: String { rawValue }
    }

    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case teamName, logoURL, category, uploadedBy, isPublic, createdAt
    }

    init(teamName: String, logoURL: String, category: LogoCategory, uploadedBy: String? = nil, isPublic: Bool = true) {
        self.teamName = teamName
        self.logoURL = logoURL
        self.category = category
        self.uploadedBy = uploadedBy
        self.isPublic = isPublic
        self.createdAt = Date()
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        teamName = try container.decode(String.self, forKey: .teamName)
        logoURL = try container.decode(String.self, forKey: .logoURL)
        category = try container.decode(LogoCategory.self, forKey: .category)
        uploadedBy = try container.decodeIfPresent(String.self, forKey: .uploadedBy)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true

        // Handle createdAt timestamp
        if let createdAtData = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = createdAtData.dateValue()
        } else if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: createdAtString)
        } else if let createdAtDouble = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: createdAtDouble)
        } else {
            createdAt = Date()
        }
    }
}

// MARK: - Logo Bank Extension for Firestore

extension LogoBankItem {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "teamName": teamName,
            "logoURL": logoURL,
            "category": category.rawValue,
            "isPublic": isPublic
        ]

        if let uploadedBy = uploadedBy {
            data["uploadedBy"] = uploadedBy
        }

        if let createdAt = createdAt {
            data["createdAt"] = Timestamp(date: createdAt)
        }

        return data
    }
}

// MARK: - Logo Recommendations

extension LogoBankItem {
    /// Recommended logo specifications
    static let recommendedSize = 512 // 512x512px square
    static let maxFileSizeMB: Double = 5.0
    static let supportedFormats = ["PNG", "JPG", "JPEG"]

    /// Firebase Storage path for logos
    static func storagePath(for logoId: String) -> String {
        return "logos/\(logoId).png"
    }
}
