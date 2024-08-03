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
    @State private var dragging: Person?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.people) { person in
                        PersonItemView(person: person, viewModel: viewModel)
                            .onDrag {
                                self.dragging = person
                                return NSItemProvider(object: person.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: DropViewDelegate(item: person, items: $viewModel.people, dragging: $dragging))
                    }
                    
                    Button(action: { showingAddPerson = true }) {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            Text("Add Person")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Age Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(viewModel: viewModel)
        }
    }
}

struct PersonItemView: View {
    let person: Person
    let viewModel: PersonViewModel
    
    var body: some View {
        NavigationLink(destination: PersonDetailView(person: person, viewModel: viewModel)) {
            VStack {
                if let latestPhoto = person.photos.last?.image {
                    Image(uiImage: latestPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                }
                Text(person.name)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: Person
    @Binding var items: [Person]
    @Binding var dragging: Person?
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragging = self.dragging else { return }
        
        if dragging != item {
            let from = items.firstIndex(of: dragging)!
            let to = items.firstIndex(of: item)!
            if items[to] != dragging {
                items.move(fromOffsets: IndexSet(integer: from),
                           toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}