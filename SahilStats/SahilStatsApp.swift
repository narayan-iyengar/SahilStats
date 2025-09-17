//
//  SahilStatsApp.swift
//  SahilStats
//
//  Created by Narayan Iyengar on 9/17/25.
//

import SwiftUI
import CoreData

@main
struct SahilStatsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
