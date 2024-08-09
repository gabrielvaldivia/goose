import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingAddPerson = false
    
    var body: some View {
        NavigationView {
            Group {
                if let firstPerson = viewModel.people.first {
                    PersonDetailView(person: firstPerson, viewModel: viewModel)
                } else {
                    WelcomeView(showingAddPerson: $showingAddPerson)
                }
            }
            .navigationBarItems(trailing: Button(action: { showingAddPerson = true }) {
                Image(systemName: "plus")
            })
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonView(viewModel: viewModel)
        }
    }
}

struct WelcomeView: View {
    @Binding var showingAddPerson: Bool
    
    var body: some View {
        VStack {
            Text("Welcome to Life Reels")
                .font(.largeTitle)
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