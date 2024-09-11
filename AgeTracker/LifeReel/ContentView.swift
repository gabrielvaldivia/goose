import PhotosUI
import SwiftUI
import UIKit

// Main ContentView struct
struct ContentView: View {
    // State and ObservedObject properties
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingAddPerson = false
    @State private var showOnboarding = false
    @State private var showPeopleSheet = false
    @State private var selectedTab = 0
    @State private var animationDirection: UIPageViewController.NavigationDirection = .forward
    @State private var showingAddPersonSheet = false
    @State private var showingImagePicker = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedAssets: [PHAsset] = []
    @State private var selectedPhoto: Photo?
    @State private var showingPeopleGrid = false
    @State private var orientation = UIDeviceOrientation.unknown
    @State private var fullScreenPhoto: Photo?
    @State private var isSettingsActive = false

    // Enums
    enum ActiveSheet: Identifiable {
        case settings, shareView, addPerson, addPersonSheet, peopleGrid
        var id: Int { hashValue }
    }

    enum SheetType: Identifiable {
        case addPersonSheet
        case peopleGrid

        var id: Int { hashValue }
    }

    // Main body of the view
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    if viewModel.people.isEmpty {
                        OnboardingView(showOnboarding: .constant(true), viewModel: viewModel)
                    } else {
                        mainView
                    }
                }

                // Navigation Bar
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {

                    // Person Name
                    ToolbarItem(placement: .principal) {
                        Button(action: {
                            showingPeopleGrid = true
                        }) {
                            HStack {
                                Text(
                                    viewModel.selectedPerson?.name ?? viewModel.people.first?.name
                                        ?? "Select Person"
                                )
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 20, height: 20)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }

                    // Settings Button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        settingsButton
                    }
                }
                .background(
                    NavigationLink(
                        destination: settingsView,
                        isActive: $isSettingsActive,
                        label: { EmptyView() }
                    )
                )
            }

            // People Grid Sheet
            .sheet(isPresented: $showingPeopleGrid) {
                peopleGridView
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            // New Life Reel Sheet
            .sheet(isPresented: $showingAddPersonSheet) {
                NewLifeReelView(
                    viewModel: viewModel,
                    isPresented: $showingAddPersonSheet,
                    onboardingMode: false
                )
            }
            .onChange(of: geometry.size) { _, _ in
                let newOrientation = UIDevice.current.orientation
                if newOrientation != orientation {
                    orientation = newOrientation
                }
            }

            // Full Screen Photo View
            .fullScreenCover(item: $fullScreenPhoto) { photo in
                if let selectedPerson = viewModel.selectedPerson {
                    FullScreenPhotoView(
                        viewModel: viewModel,
                        photo: photo,
                        currentIndex: getCurrentPhotos().firstIndex(of: photo) ?? 0,
                        photos: Binding(
                            get: { self.getCurrentPhotos() },
                            set: { newPhotos in
                                self.updatePhotos(newPhotos)
                            }
                        ),
                        onDelete: { photoToDelete in
                            deletePhoto(photoToDelete)
                        },
                        person: getCurrentPersonBinding()
                    )
                } else {
                    Text("No person selected")
                }
            }
            .onChange(of: fullScreenPhoto) { _, newValue in
                print("fullScreenPhoto changed: \(newValue?.id.uuidString ?? "nil")")
                print("Selected person: \(viewModel.selectedPerson?.name ?? "None")")
                print("Total photos for selected person: \(viewModel.selectedPerson?.photos.count ?? 0)")
            }
        }

        // Active Sheet
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .addPerson, .addPersonSheet:
                NewLifeReelView(
                    viewModel: viewModel,
                    isPresented: Binding(
                        get: { activeSheet != nil },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    onboardingMode: false
                )
            case .peopleGrid:
                NavigationView {
                    peopleGridView
                }
            case .shareView:
                if let person = viewModel.selectedPerson {
                    ShareSlideshowView(
                        photos: person.photos,
                        person: person,
                        sectionTitle: "All Photos"
                    )
                } else {
                    Text("No person selected")
                }
            case .settings:
                // We'll keep this case to avoid compilation errors, but it won't be used
                EmptyView()
            }
        }

        // Force view update when selected person changes
        .onChange(of: viewModel.selectedPerson) { _, _ in
            // Force view update when selected person changes
            viewModel.objectWillChange.send()
            // Reset the selected tab to the timeline view
            selectedTab = 0
        }
        .onAppear {
            if viewModel.selectedPerson == nil {
                viewModel.selectedPerson = viewModel.people.first
            }
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    // Main view component
    private var mainView: AnyView {
        if let person = viewModel.selectedPerson ?? viewModel.people.first {
            return AnyView(
                ZStack(alignment: .bottom) {
                    PageViewController(
                        pages: [
                            AnyView(
                                TimelineView(
                                    viewModel: viewModel,
                                    person: viewModel.bindingForPerson(person),
                                    selectedPhoto: $fullScreenPhoto,
                                    forceUpdate: false,
                                    sectionTitle: "All Photos",
                                    showScrubber: true
                                )),
                            AnyView(
                                GridView(
                                    viewModel: viewModel,
                                    person: viewModel.bindingForPerson(person),
                                    selectedPhoto: $fullScreenPhoto,
                                    mode: .milestones,
                                    sectionTitle: nil,
                                    forceUpdate: false,
                                    showAge: true
                                )),
                        ],
                        currentPage: $selectedTab,
                        animationDirection: $animationDirection
                    )
                    .edgesIgnoringSafeArea(.all)

                    BottomControls(
                        shareAction: {
                            viewModel.selectedPerson = person
                            activeSheet = .shareView
                        },
                        addPhotoAction: {
                            viewModel.selectedPerson = person
                            showingImagePicker = true
                        },
                        selectedTab: $selectedTab,
                        animationDirection: $animationDirection,
                        options: ["person.crop.rectangle.stack", "square.grid.2x2"]
                    )
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(
                        selectedAssets: $selectedAssets,
                        isPresented: $showingImagePicker,
                        onSelect: { assets in
                            DispatchQueue.main.async {
                                self.handleSelectedAssetsChange(assets)
                            }
                        }
                    )
                }
                .onChange(of: selectedAssets) { _, newValue in
                    print("selectedAssets changed. New count: \(newValue.count)")
                }
                .onChange(of: viewModel.selectedPerson) { _, _ in
                    viewModel.objectWillChange.send()
                }
                .id(person.id)  // Force view refresh when person changes
            )
        } else {
            return AnyView(
                ZStack {
                    Text("No person selected")
                }
            )
        }
    }

    // People grid view component
    private var peopleGridView: some View {
        VStack {
            Text("Life Reels")
                .font(.headline)
                .padding()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                    ForEach(viewModel.people) { person in
                        PersonGridItem(
                            person: person, viewModel: viewModel,
                            showingPeopleGrid: $showingPeopleGrid)
                    }

                    AddPersonGridItem()
                        .onTapGesture {
                            showingAddPersonSheet = true
                        }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAddPersonSheet) {
            NewLifeReelView(
                viewModel: viewModel,
                isPresented: $showingAddPersonSheet,
                onboardingMode: false
            )
        }
    }

    private func getCurrentPhotos() -> [Photo] {
        guard let selectedPerson = viewModel.selectedPerson else {
            print("No person selected")
            return []
        }
        let photos = selectedPerson.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
        print("Number of photos in getCurrentPhotos(): \(photos.count)")
        print("Selected person: \(selectedPerson.name)")
        print("Total people in viewModel: \(viewModel.people.count)")
        return photos
    }

    private func updatePhotos(_ newPhotos: [Photo]) {
        if let person = viewModel.selectedPerson,
            let personIndex = viewModel.people.firstIndex(where: { $0.id == person.id })
        {
            viewModel.people[personIndex].photos = newPhotos
            viewModel.objectWillChange.send()
        }
    }

    // Delete photo component
    private func deletePhoto(_ photo: Photo) {
        if let person = viewModel.selectedPerson {
            viewModel.deletePhoto(photo, from: person)
        }
    }

    // Get current person binding component
    private func getCurrentPersonBinding() -> Binding<Person> {
        Binding(
            get: {
                self.viewModel.selectedPerson ?? Person(name: "", dateOfBirth: Date())
            },
            set: { newValue in
                if let index = self.viewModel.people.firstIndex(where: { $0.id == newValue.id }) {
                    self.viewModel.people[index] = newValue
                }
            }
        )
    }

    // Settings button component
    private var settingsButton: some View {
        Button(action: {
            isSettingsActive = true
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private var settingsView: some View {
        if let person = viewModel.selectedPerson ?? viewModel.people.first {
            PersonSettingsView(viewModel: viewModel, person: viewModel.bindingForPerson(person))
        } else {
            Text("No person selected")
        }
    }

    // Handle selected assets change
    private func handleSelectedAssetsChange(_ assets: [PHAsset]) {
        print("handleSelectedAssetsChange called. Assets count: \(assets.count)")
        guard !assets.isEmpty else {
            print("No assets selected")
            return
        }

        guard let selectedPerson = viewModel.selectedPerson else {
            print("No person available to add photos to")
            return
        }

        let dispatchGroup = DispatchGroup()
        var addedPhotos: [Photo] = []

        for asset in assets {
            dispatchGroup.enter()
            viewModel.addPhoto(to: selectedPerson, asset: asset) { photo in
                if let photo = photo {
                    addedPhotos.append(photo)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if let latestPhoto = addedPhotos.last {
                self.fullScreenPhoto = latestPhoto
                self.viewModel.objectWillChange.send()
            }
            print("Added \(addedPhotos.count) photos to \(selectedPerson.name)")
        }
    }
}

// PersonGridItem component
struct PersonGridItem: View {
    let person: Person
    @ObservedObject var viewModel: PersonViewModel
    @Binding var showingPeopleGrid: Bool

    var body: some View {
        VStack {
            if let latestPhoto = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first,
                let uiImage = latestPhoto.image
            {
                Image(uiImage: uiImage)
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
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
        .onTapGesture {
            viewModel.selectedPerson = person
            showingPeopleGrid = false
            viewModel.objectWillChange.send()
        }
    }
}

// AddPersonGridItem view
struct AddPersonGridItem: View {
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue)
            }

            Text("New")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}
