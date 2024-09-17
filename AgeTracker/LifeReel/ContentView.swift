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

                        VStack {
                            Spacer()
                            Button(action: {
                                showingSlideshowSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Slideshow")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }

                // Navigation Bar
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingPeopleGrid = true
                        }) {
                            HStack(spacing: 4) {
                                Text(
                                    viewModel.selectedPerson?.name ?? viewModel.people.first?.name
                                        ?? "Select Person"
                                )
                                .font(.title2)
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
                                systemName: "gearshape.fill",
                                action: {
                                    isSettingsActive = true
                                },
                                size: 32,
                                backgroundColor: Color.gray.opacity(0.2),
                                iconColor: .primary,
                                blurEffect: false
                            )

                            CircularButton(
                                systemName: "plus",
                                action: {
                                    showingImagePicker = true
                                },
                                size: 32,
                                backgroundColor: Color.gray.opacity(0.2),
                                iconColor: .primary,
                                blurEffect: false
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
                        let width = geometry.size.width
                        let itemWidth = (width - 48) / 2  // 48 = 3 * 16 (left, middle, and right padding)

                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.fixed(itemWidth), spacing: 16),
                                    GridItem(.fixed(itemWidth), spacing: 16),
                                ],
                                spacing: 24
                            ) {
                                ForEach(getMilestones(for: person), id: \.0) { milestone, photos in
                                    NavigationLink(
                                        destination: MilestoneDetailView(
                                            viewModel: viewModel,
                                            person: viewModel.bindingForPerson(person),
                                            sectionTitle: milestone
                                        )
                                    ) {
                                        MilestoneTile(
                                            milestone: milestone,
                                            photos: photos,
                                            person: person,
                                            width: itemWidth,
                                            isEmpty: photos.isEmpty
                                        )
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .id(person.id)  // Force view refresh when person changes
            )
        } else {
            AnyView(
                Text("No person selected")
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
}

// PersonGridItem component
struct PersonGridItem: View {
    let person: Person
    @ObservedObject var viewModel: PersonViewModel
    @Binding var showingPeopleGrid: Bool

    var body: some View {
        VStack (spacing: 12) {
            if let latestPhoto = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first,
                let uiImage = latestPhoto.image
            {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 85, height: 85)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)
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
        VStack (spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 85, height: 85)

                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }

            Text("New")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
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
    private let scaleFactor: CGFloat = 0.95

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isEmpty {
                    emptyTileContent
                } else {
                    Group {
                        if photos.count >= 3 {
                            // Bottom layer (third most recent photo)
                            photoLayer(at: 2, rotation: 6, scale: scaleFactor * scaleFactor)
                        }
                        
                        if photos.count >= 2 {
                            // Middle layer (second most recent photo)
                            photoLayer(at: 1, rotation: 3, scale: scaleFactor)
                        }

                        // Top layer (most recent photo)
                        filledTileContent
                            .frame(width: width, height: width * 4 / 3)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .frame(width: width, height: width * 4 / 3)
        }
        .frame(width: width)
    }

    private func photoLayer(at index: Int, rotation: Double, scale: CGFloat) -> some View {
        let sortedPhotos = photos.sorted(by: { $0.dateTaken > $1.dateTaken })
        if sortedPhotos.indices.contains(index), let image = sortedPhotos[index].image {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width * scale, height: width * 4 / 3 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .rotationEffect(Angle(degrees: rotation), anchor: .bottomLeading)
                    .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
            )
        }
        return AnyView(EmptyView())
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
                Spacer()

                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .overlay(
                    VStack(spacing: 2) {
                        Text(milestone)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .foregroundColor(.white)
                        
                        // Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                        //     .font(.caption)
                        //     .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                )
            }
        }
        .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
    }
}
