//
//  MacSideDockApp.swift
//  MacSideDock
//
//  Created by Rehan on 9/15/26.
//

import SwiftUI
import CoreData

@main
struct MacSideDockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
