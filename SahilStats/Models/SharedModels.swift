// File: SahilStats/Models/SharedModels.swift

import Foundation
import SwiftUI

// MARK: - Game Configuration
struct GameConfig {
    var teamName = ""
    var opponent = ""
    var location = ""
    var date = Date()
    var gameFormat = GameFormat.halves
    var quarterLength = 20
}

enum GameSubmissionMode {
    case live
    case postGame
}

