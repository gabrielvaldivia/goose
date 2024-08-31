import SwiftUI
import UIKit
import PhotosUI

struct ContentView: View {
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

    enum ActiveSheet: Identifiable {
        case settings, shareView
        var id: Int { hashValue }
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding, viewModel: viewModel)
            } else {
                mainView
            }
        }
        .onAppear {
            if viewModel.people.isEmpty && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                showOnboarding = true
            } else if let lastOpenedPersonId = viewModel.lastOpenedPersonId,
                      let lastOpenedPerson = viewModel.people.first(where: { $0.id == lastOpenedPersonId }) {
                viewModel.selectedPerson = lastOpenedPerson
            } else if !viewModel.people.isEmpty {
                viewModel.selectedPerson = viewModel.people[0]
            }
        }
    }
    
    private var mainView: some View {
        NavigationView {
            ZStack {
                if let person = viewModel.selectedPerson {
                    personDetailView(for: person)
                } else {
                    Text("Add someone to get started")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        showPeopleSheet = true
                    }) {
                        Text(viewModel.selectedPerson?.name ?? "Select Person")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showPeopleSheet) {
                peopleGridView
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView(
                    viewModel: viewModel,
                    isPresented: $showingAddPerson,
                    onboardingMode: false,
                    currentStep: .constant(1)
                )
            }
        }
    }
    
    private var peopleGridView: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(viewModel.people) { person in
                            PersonGridItem(person: person)
                                .onTapGesture {
                                    viewModel.selectedPerson = person
                                    showPeopleSheet = false
                                }
                        }
                        
                        AddPersonGridItem()
                            .onTapGesture {
                                showingAddPersonSheet = true
                            }
                    }
                    .padding()
                }
                .navigationTitle("People")
                .navigationBarTitleDisplayMode(.inline)
            }
            
            if showingAddPersonSheet {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingAddPersonSheet = false
                    }
            }
        }
    }
    
    private func personDetailView(for person: Person) -> some View {
        ZStack(alignment: .bottom) {
            PageViewController(
                pages: [
                    AnyView(SharedTimelineView(viewModel: viewModel, person: viewModel.bindingForPerson(person), selectedPhoto: .constant(nil), forceUpdate: false, sectionTitle: "All Photos", showScrubber: true)),
                    AnyView(StackGridView(viewModel: viewModel, person: viewModel.bindingForPerson(person), selectedPhoto: .constant(nil), openImagePickerForMoment: { _, _ in }, forceUpdate: false))
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
            ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
        }
        .sheet(item: $activeSheet) { (item: ActiveSheet) in
            switch item {
            case .shareView:
                if let person = viewModel.selectedPerson {
                    ShareSlideshowView(photos: person.photos, person: person, sectionTitle: "All Photos")
                }
            case .settings:
                if let selectedPerson = viewModel.selectedPerson {
                    PersonSettingsView(viewModel: viewModel, person: Binding(
                        get: { selectedPerson },
                        set: { newValue in
                            viewModel.updatePerson(newValue)
                        }
                    ))
                }
            }
        }
        .onChange(of: selectedAssets) { _, _ in
            handleSelectedAssetsChange()
        }
    }
    
    private func bottomControls(for person: Person) -> some View {
        BottomControls(
            shareAction: {
                activeSheet = .shareView
            },
            addPhotoAction: {
                showingImagePicker = true
            },
            selectedTab: $selectedTab,
            animationDirection: $animationDirection,
            options: ["person.crop.rectangle.stack", "square.grid.2x2"]
        )
    }
    
    private func settingsButton(for person: Person) -> some View {
        Button(action: {
            showingPersonSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $showingPersonSettings) {
            if let index = viewModel.people.firstIndex(where: { $0.id == person.id }) {
                PersonSettingsView(viewModel: viewModel, person: $viewModel.people[index])
            }
        }
    }

    private func handleSelectedAssetsChange() {
        guard !selectedAssets.isEmpty, let person = viewModel.selectedPerson else { return }
        
        for asset in selectedAssets {
            viewModel.addPhotoToSelectedPerson(asset: asset)
        }
        
        selectedAssets.removeAll()
    }
}

struct PersonGridItem: View {
    let person: Person
    
    var body: some View {
        VStack {
            if let latestPhoto = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first,
               let uiImage = latestPhoto.image {
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

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index == 0 {
                return nil // Return nil instead of the last controller
            }
            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index + 1 == controllers.count {
                return nil // Return nil instead of the first controller
            }
            return controllers[index + 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController) {
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
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
            }
            
            Text("Add Person")
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}