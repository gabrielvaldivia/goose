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
    @State private var showingPersonSettings = false
    @State private var showingImagePicker = false
    @State private var activeSheet: ActiveSheet?
    @State private var selectedAssets: [PHAsset] = []
    @State private var selectedPhoto: Photo?
    @State private var showingPeopleGrid = false
    @State private var orientation = UIDeviceOrientation.unknown
    @State private var fullScreenPhoto: Photo?

    // Enums
    enum ActiveSheet: Identifiable {
        case settings, shareView, addPerson, addPersonSheet, peopleGrid
        var id: Int { hashValue }
    }

    enum SheetType: Identifiable {
        case addPerson
        case addPersonSheet
        case peopleGrid

        var id: Int { hashValue }
    }

    // Grid layout
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    // Main body of the view
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                ZStack {
                    if viewModel.people.isEmpty {
                        OnboardingView(showOnboarding: .constant(true), viewModel: viewModel)
                    } else {
                        mainView
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(isPresented: $showingPeopleGrid) {
                peopleGridView
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddPersonSheet) {
                AddPersonView(
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
            .fullScreenCover(item: $fullScreenPhoto) { photo in
                FullScreenPhotoView(
                    photo: photo,
                    currentIndex: getCurrentIndex(for: photo),
                    photos: Binding(
                        get: { getCurrentPhotos() },
                        set: { newPhotos in
                            updatePhotos(newPhotos)
                        }
                    ),
                    onDelete: { photoToDelete in
                        deletePhoto(photoToDelete)
                    },
                    person: getCurrentPersonBinding(),
                    viewModel: viewModel
                )
            }
            .onChange(of: fullScreenPhoto) { _, newValue in
                print("fullScreenPhoto changed: \(newValue?.id.uuidString ?? "nil")")
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .addPerson, .addPersonSheet:
                AddPersonView(
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
    }

    // Main view component
    private var mainView: some View {
        ZStack {
            if let person = viewModel.selectedPerson ?? viewModel.people.first {
                personDetailView(for: person)
            } else {
                Text("No person selected")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            AddPersonView(
                viewModel: viewModel,
                isPresented: $showingAddPersonSheet,
                onboardingMode: false
            )
        }
    }

    // Person detail view component
    private func personDetailView(for person: Person) -> some View {
        ZStack(alignment: .bottom) {
            PageViewController(
                pages: [
                    AnyView(sharedTimelineView(for: person)),
                    AnyView(milestonesView(for: person))
                ],
                currentPage: $selectedTab,
                animationDirection: $animationDirection
            )
            .edgesIgnoringSafeArea(.all)

            bottomControls(for: person)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton(for: person)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                selectedAssets: $selectedAssets,
                isPresented: $showingImagePicker,
                onSelect: { assets in
                    print("ImagePicker onSelect called with \(assets.count) assets")
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
    }

    private func sharedTimelineView(for person: Person) -> some View {
        SharedTimelineView(
            viewModel: viewModel,
            person: viewModel.bindingForPerson(person),
            selectedPhoto: Binding(
                get: { self.fullScreenPhoto },
                set: { 
                    print("Setting fullScreenPhoto: \($0?.id.uuidString ?? "nil")")
                    self.viewModel.selectedPerson = person
                    self.fullScreenPhoto = $0 
                }
            ),
            forceUpdate: false,
            sectionTitle: "All Photos",
            showScrubber: true
        )
    }

    private func milestonesView(for person: Person) -> some View {
        MilestonesView(
            viewModel: viewModel,
            person: viewModel.bindingForPerson(person),
            selectedPhoto: Binding(
                get: { self.fullScreenPhoto },
                set: { 
                    print("Setting fullScreenPhoto: \($0?.id.uuidString ?? "nil")")
                    self.viewModel.selectedPerson = person
                    self.fullScreenPhoto = $0 
                }
            ),
            openImagePickerForMoment: { _, _ in },
            forceUpdate: false
        )
    }

    private func getCurrentIndex(for photo: Photo) -> Int {
        let currentPhotos = getCurrentPhotos()
        return currentPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0
    }

    private func getCurrentPhotos() -> [Photo] {
        return viewModel.selectedPerson?.photos.sorted(by: { $0.dateTaken > $1.dateTaken }) ?? []
    }

    private func updatePhotos(_ newPhotos: [Photo]) {
        if let person = viewModel.selectedPerson,
           let personIndex = viewModel.people.firstIndex(where: { $0.id == person.id }) {
            viewModel.people[personIndex].photos = newPhotos
            viewModel.objectWillChange.send()
        }
    }

    private func deletePhoto(_ photo: Photo) {
        if let person = viewModel.selectedPerson {
            viewModel.deletePhoto(photo, from: person)
        }
    }

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

    // Bottom controls component
    private func bottomControls(for person: Person) -> some View {
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

    // Settings button component
    private func settingsButton(for person: Person) -> some View {
        NavigationLink(
            destination: PersonSettingsView(
                viewModel: viewModel, person: viewModel.bindingForPerson(person))
        ) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
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

        for asset in assets {
            print("Adding asset: \(asset.localIdentifier)")
            viewModel.addPhotoToSelectedPerson(asset: asset)
        }


        print("handleSelectedAssetsChange completed")
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
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
            }

            Text(person.name)
                .font(.caption)
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

// Custom PageViewController for swipe navigation
struct PageViewController: UIViewControllerRepresentable {
    var pages: [AnyView]
    @Binding var currentPage: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        pageViewController.setViewControllers(
            [context.coordinator.controllers[currentPage]],
            direction: animationDirection,
            animated: true)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageViewController
        var controllers = [UIViewController]()

        init(_ pageViewController: PageViewController) {
            parent = pageViewController
            controllers = parent.pages.map { UIHostingController(rootView: $0) }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index == 0 {
                return nil  // Return nil instead of the last controller
            }
            return controllers[index - 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index + 1 == controllers.count {
                return nil  // Return nil instead of the first controller
            }
            return controllers[index + 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController], transitionCompleted completed: Bool
        ) {
            if completed,
                let visibleViewController = pageViewController.viewControllers?.first,
                let index = controllers.firstIndex(of: visibleViewController)
            {
                parent.currentPage = index
            }
        }
    }
}

// New AddPersonGridItem view
struct AddPersonGridItem: View {
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue)
            }

            Text("New Life Reel")
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}
