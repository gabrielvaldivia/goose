//
//  ContentView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PersonViewModel()
    @State private var showingAddPerson = false
    
    var body: some View {
        NavigationView {
            List(viewModel.people) { person in
                NavigationLink(destination: PersonDetailView(person: person, viewModel: viewModel)) {
                    Text(person.name)
                }
            }
            .navigationTitle("Age Tracker")
            .toolbar {
                Button(action: { showingAddPerson = true }) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(viewModel: viewModel)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}