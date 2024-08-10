import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingAddPerson = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if !viewModel.people.isEmpty {
                    List(viewModel.people) { person in
                        NavigationLink(value: person) {
                            Text(person.name)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else {
                    WelcomeView(showingAddPerson: $showingAddPerson)
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("People")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPerson = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person, viewModel: viewModel)
            }
        }
        .environmentObject(viewModel)
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(viewModel: viewModel)
        }
        .onAppear {
            if let lastOpenedPersonId = viewModel.lastOpenedPersonId,
               let lastOpenedPerson = viewModel.people.first(where: { $0.id == lastOpenedPersonId }) {
                navigationPath.append(lastOpenedPerson)
            }
        }
    }
}

struct WelcomeView: View {
    @Binding var showingAddPerson: Bool
    
    var body: some View {
        VStack {
            Text("Welcome to LifeReel")
                .font(.title3)
                .fontWeight(.bold)
                .padding()
            
            Text("Add someone to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddPerson = true }) {
                Text("Add Someone")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: PersonViewModel())
    }
}