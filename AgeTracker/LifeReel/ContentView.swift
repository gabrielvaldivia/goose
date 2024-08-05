//
//  ContentView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PersonViewModel
    
    init(viewModel: PersonViewModel) {
        self.viewModel = viewModel
    }
    
    @State private var showingAddPerson = false
    @State private var dragging: Person?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer(minLength: 0)
                        
                        LazyVStack(spacing: 40) {
                            ForEach(viewModel.people) { person in
                                PersonItemView(person: person, viewModel: viewModel)
                                    .onDrag {
                                        self.dragging = person
                                        return NSItemProvider(object: person.id.uuidString as NSString)
                                    } preview: {
                                        DragPreviewView(person: person)
                                    }
                                    .onDrop(of: [.text], delegate: DropViewDelegate(item: person, items: $viewModel.people, dragging: $dragging))
                            }
                            
                            Button(action: { showingAddPerson = true }) {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "plus")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.blue)
                                    }
                                    Text("Add Reel")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geometry.size.height)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Reels")
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
                if let latestPhoto = person.photos.last {
                    if let image = latestPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 250)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(person.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(person.photos.count) photo\(person.photos.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
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

struct DragPreviewView: View {
    let person: Person
    
    var body: some View {
        VStack {
            if let latestPhoto = person.photos.last?.image {
                Image(uiImage: latestPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            }
            Text(person.name)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: PersonViewModel())
    }
}