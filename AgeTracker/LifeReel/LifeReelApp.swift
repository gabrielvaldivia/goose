//
//  AgeTrackerApp.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import SwiftUI
import BackgroundTasks

@main
struct LifeReelApp: App {
    @StateObject private var personViewModel = PersonViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: personViewModel)
            .onAppear {
                if let lastOpenedPersonIdString = UserDefaults.standard.string(forKey: "lastOpenedPersonId"),
                   let lastOpenedPersonId = UUID(uuidString: lastOpenedPersonIdString),
                   let lastOpenedPerson = personViewModel.people.first(where: { $0.id == lastOpenedPersonId }) {
                    personViewModel.setLastOpenedPerson(lastOpenedPerson)
                }
            }
        }
    }
}