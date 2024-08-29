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
    
    init() {
        registerBackgroundTasks()
    }
    
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
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourcompany.agetracker.syncAlbums", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        personViewModel.syncAlbums { success in
            task.setTaskCompleted(success: success)
        }
        
        scheduleAppRefresh()
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.yourcompany.agetracker.syncAlbums")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}