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
    @State private var showingAddPersonSheet = false
    @State private var showingImagePicker = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedAssets: [PHAsset] = []
    @State private var selectedPhoto: Photo?
    @State private var showingPeopleGrid = false
    @State private var orientation = UIDeviceOrientation.unknown
    @State private var fullScreenPhoto: Photo?
    @State private var isSettingsActive = false
    @State private var selectedMilestone: String?
    @State private var showingSlideshowSheet = false
    @State private var isLoading = false
    @State private var currentPage = 0
    @State private var photosPerPage = 20  // Adjust this number based on performance testing

    // Enums
    enum ActiveSheet: Identifiable {
        case settings, shareView, addPerson, addPersonSheet
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
                    ToolbarItem(placement: .navigationBarLeading) {
                        CircularButton(
                            systemName: "gearshape.fill",
                            action: {
                                isSettingsActive = true
                            },
                            size: 32,
                            backgroundColor: Color.gray.opacity(0.2),
                            iconColor: .primary,
                            blurEffect: false,
                            iconSize: nil
                        )
                    }

                    ToolbarItem(placement: .principal) {
                        Menu {
                            ForEach(viewModel.people) { person in
                                Button(person.name) {
                                    viewModel.selectedPerson = person
                                }
                            }

                            Divider()

                            Button {
                                showingAddPersonSheet = true
                            } label: {
                                HStack {
                                    Text("New Life Reel")
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(
                                    viewModel.selectedPerson?.name ?? viewModel.people.first?.name
                                        ?? "Select Person"
                                )
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            CircularButton(
                                systemName: "square.and.arrow.up",
                                action: {
                                    showingSlideshowSheet = true
                                },
                                size: 32,
                                backgroundColor: Color.gray.opacity(0.2),
                                iconColor: .primary,
                                blurEffect: false,
                                iconSize: 11
                            )

                            CircularButton(
                                systemName: "plus",
                                action: {
                                    showingImagePicker = true
                                },
                                size: 32,
                                backgroundColor: Color.gray.opacity(0.2),
                                iconColor: .primary,
                                blurEffect: false,
                                iconSize: nil
                            )
                        }
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
                        currentIndex: selectedPerson.photos.firstIndex(of: photo) ?? 0,
                        photos: Binding(
                            get: { selectedPerson.photos },
                            set: { newPhotos in
                                if let index = viewModel.people.firstIndex(where: {
                                    $0.id == selectedPerson.id
                                }) {
                                    viewModel.people[index].photos = newPhotos
                                }
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
                // print("fullScreenPhoto changed: \(newValue?.id.uuidString ?? "nil")")
                // print("Selected person: \(viewModel.selectedPerson?.name ?? "None")")
                // print(
                //     "Total photos for selected person: \(viewModel.selectedPerson?.photos.count ?? 0)"
                // )
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

        .sheet(isPresented: $showingSlideshowSheet) {
            if let person = viewModel.selectedPerson {
                ShareSlideshowView(
                    photos: person.photos,
                    person: person,
                    sectionTitle: "All Photos"
                )
            } else {
                Text("No person selected")
            }
        }

        // Force view update when selected person changes
        .onChange(of: viewModel.selectedPerson) { _, _ in
            // Force view update when selected person changes
            viewModel.objectWillChange.send()
        }
        .onAppear {
            if viewModel.selectedPerson == nil {
                viewModel.selectedPerson = viewModel.people.first
            }
        }

        // ImagePicker sheet
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                selectedAssets: $selectedAssets,
                isPresented: $showingImagePicker,
                onSelect: { assets in
                    handleSelectedAssetsChange(assets)
                }
            )
            .edgesIgnoringSafeArea(.all)
        }
    }

    // Main view component
    private var mainView: some View {
        if let person = viewModel.selectedPerson ?? viewModel.people.first {
            AnyView(
                NavigationStack {
                    GeometryReader { geometry in
                        GridView(
                            viewModel: viewModel,
                            person: viewModel.bindingForPerson(person),
                            selectedPhoto: $fullScreenPhoto,
                            sectionTitle: nil,
                            forceUpdate: false,
                            showAge: true,
                            showMilestoneScroll: true
                        )
                        .frame(minHeight: geometry.size.height)
                        .onAppear {
                            loadInitialPhotos(for: person)
                        }
                        .onChange(of: person.id) { _, _ in
                            resetPagination()
                            loadInitialPhotos(for: person)
                        }
                    }
                }
                .id(person.id)
            )
        } else {
            AnyView(
                Text("No person selected")
            )
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
        // print("handleSelectedAssetsChange called. Assets count: \(assets.count)")
        guard !assets.isEmpty else {
            // print("No assets selected")
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

    private func resetPagination() {
        currentPage = 0
        isLoading = false
    }

    private func loadInitialPhotos(for person: Person) {
        guard !isLoading else { return }
        isLoading = true
        
        // Load first batch of photos
        viewModel.loadPhotos(for: person, page: currentPage, perPage: photosPerPage) { success in
            isLoading = false
            if success {
                currentPage += 1
            }
        }
    }

    private func loadMorePhotos() {
        guard !isLoading, let person = viewModel.selectedPerson else { return }
        isLoading = true
        
        viewModel.loadPhotos(for: person, page: currentPage, perPage: photosPerPage) { success in
            isLoading = false
            if success {
                currentPage += 1
            }
        }
    }
}

private func getMilestones(for person: Person) -> [(String, [Photo])] {
    let allMilestones = PhotoUtils.getAllMilestones(for: person)
    let groupedPhotos = Dictionary(grouping: person.photos) { photo in
        PhotoUtils.sectionForPhoto(photo, person: person)
    }

    return allMilestones.reversed().compactMap { milestone in
        let photos = groupedPhotos[milestone] ?? []
        if person.pregnancyTracking == .none {
            let isPregnancyMilestone =
                milestone.lowercased().contains("pregnancy")
                || milestone.lowercased().contains("trimester")
                || milestone.lowercased().contains("week")
            if isPregnancyMilestone {
                return nil
            }
        }

        if !photos.isEmpty || person.showEmptyStacks {
            return (milestone, photos)
        }
        return nil
    }
}

struct MilestoneTile: View {
    let milestone: String
    let photos: [Photo]
    let person: Person
    let width: CGFloat
    let isEmpty: Bool

    private let shadowColor = Color.black.opacity(0.1)
    private let shadowRadius: CGFloat = 4
    private let shadowX: CGFloat = 0
    private let shadowY: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isEmpty {
                    emptyTileContent
                } else {
                    filledTileContent
                }
            }
            .frame(width: width, height: width * 4 / 3)
        }
        .frame(width: width)
    }

    private var emptyTileContent: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)

            VStack {
                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary)

                Spacer()

                Text(milestone)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var filledTileContent: some View {
        ZStack {
            if let latestPhoto = photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first,
                let image = latestPhoto.image
            {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: width * 4 / 3)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }

            VStack {
                HStack {
                    Spacer()
                    Text("\(photos.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(8)
                }
                Spacer()

                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .overlay(
                    Text(milestone)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
    }
}
