//
//  ChartDataModels.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//

// File: SahilStats/Models/ChartDataModels.swift

import Foundation

// MARK: - Data Models for Charts and Graphs

struct StatGraphData {
    let title: String
    let data: [StatDataPoint]
}

struct StatDataPoint {
    let value: Double
    let date: String
    let label: String
}

// MARK: - Points Breakdown Data

struct PointsBreakdown {
    let twoPointers: Int
    let threePointers: Int
    let freeThrows: Int
    let total: Int
    
    init(from game: Game) {
        self.twoPointers = game.fg2m * 2
        self.threePointers = game.fg3m * 3
        self.freeThrows = game.ftm
        self.total = game.points
    }
}
