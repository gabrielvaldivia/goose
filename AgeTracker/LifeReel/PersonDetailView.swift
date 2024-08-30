//
//  PersonDetailView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos
import UIKit

// Enum for managing different sheet presentations
enum ActiveSheet: Identifiable, Hashable {
    case settings
    case shareView
    case customImagePicker(moment: String, _: (start: Date, end: Date))
    
    var id: Self { self }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .settings:
            hasher.combine(0)
        case .shareView:
            hasher.combine(1)
        case .customImagePicker(let moment, _):
            hasher.combine(3)
            hasher.combine(moment)
        }
    }
    
    static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
        switch (lhs, rhs) {
        case (.settings, .settings),
             (.shareView, .shareView):
            return true
        case let (.customImagePicker(lMoment, _), .customImagePicker(rMoment, _)):
            return lMoment == rMoment
        default:
            return false
        }
    }
}

// UIViewControllerRepresentable for PHPickerViewController
struct ImagePickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let targetDate: Date
    let onPick: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Allow multiple selection
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerRepresentable

        init(_ parent: ImagePickerRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            let assets = (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
            parent.onPick(assets)
        }
    }
}

// Main view struct
struct PersonDetailView: View {
    // State and observed properties
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @State private var showingImagePicker = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var selectedTab = 0 // 0 for Timeline, 1 for Grid
    @State private var activeSheet: ActiveSheet?
    @State private var selectedPhoto: Photo? = nil 
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []
    @State private var showingDatePicker = false
    @State private var selectedPhotoForDateEdit: Photo?
    @State private var editedDate: Date = Date()
    @State private var currentScrollPosition: String?
    @State private var isImagePickerPresented = false
    @State private var currentMoment: String = ""
    @State private var isCustomImagePickerPresented = false
    @State private var customImagePickerTargetDate = Date()
    @State private var birthMonthsDisplay: Person.BirthMonthsDisplay
    @State private var animationDirection: UIPageViewController.NavigationDirection = .forward
    @State private var currentSection: String?
    @State private var forceUpdate: Bool = false
    
    // Add this state variable
    @State private var shouldNavigateBack = false
    @State private var showShareSlideshowOnAppear = false

    // Initializer
    init(person: Binding<Person>, viewModel: PersonViewModel) {
        self._person = person
        self.viewModel = viewModel
        self._birthMonthsDisplay = State(initialValue: person.wrappedValue.birthMonthsDisplay)
    }
    
    // Main body of the view
    var body: some View {
        // ZStack for main content and bottom controls
        ZStack(alignment: .bottom) {
            PageViewController(
                pages: [
                    AnyView(SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, forceUpdate: forceUpdate, sectionTitle: "All Photos", showScrubber: true)),
                    AnyView(StackGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, openImagePickerForMoment: openImagePickerForMoment, forceUpdate: forceUpdate))
                ],
                currentPage: $selectedTab,
                animationDirection: $animationDirection
            )
            .edgesIgnoringSafeArea(.all)

            bottomControls
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Navigation bar configuration
            ToolbarItem(placement: .principal) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
        }
        .edgesIgnoringSafeArea(.top)
        .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
            // Various sheet presentations
            ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
                .edgesIgnoringSafeArea(.all)
                .presentationDetents([.large])
        }
        .sheet(item: $activeSheet) { item in
            sheetContent(item)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityViewController(activityItems: activityItems)
        }
        .onChange(of: selectedAssets) { oldValue, newValue in
            // Event handlers and lifecycle methods
            handleSelectedAssetsChange(oldValue: oldValue, newValue: newValue)
        }
        .onAppear(perform: handleOnAppear)
        .alert(isPresented: $showingDeleteAlert, content: deletePhotoAlert)
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                currentIndex: person.photos.firstIndex(of: photo) ?? 0,
                photos: person.photos,
                onDelete: deletePhoto,
                person: person,
                viewModel: viewModel 
            )
        }
        .sheet(isPresented: $showingDatePicker, content: photoDatePickerSheet)
        .onAppear {
            viewModel.setLastOpenedPerson(person)
            if viewModel.newlyAddedPerson?.id == person.id {
                showShareSlideshowOnAppear = true
                viewModel.newlyAddedPerson = nil
            }
        }
        .onChange(of: showShareSlideshowOnAppear) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    activeSheet = .shareView
                    showShareSlideshowOnAppear = false
                }
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            if let section = currentSection {
                CustomImagePicker(
                    viewModel: viewModel,
                    person: $person,
                    sectionTitle: section,
                    isPresented: $isImagePickerPresented,
                    onPhotosAdded: { newPhotos in
                        viewModel.updatePerson(person)
                    }
                )
            }
        }
        .sheet(isPresented: $isCustomImagePickerPresented) {
            CustomImagePicker(
                viewModel: viewModel,
                person: $person,
                sectionTitle: currentMoment,
                isPresented: $isCustomImagePickerPresented,
                onPhotosAdded: { newPhotos in
                    // Handle newly added photos
                    viewModel.updatePerson(person)
                }
            )
        }
        .onChange(of: person.birthMonthsDisplay) { oldValue, newValue in
            birthMonthsDisplay = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Force view update on orientation change
            viewModel.objectWillChange.send()
        }
        // Add this modifier
        .onChange(of: shouldNavigateBack) { _, newValue in
            if newValue {
                viewModel.navigationPath.removeLast(viewModel.navigationPath.count)
            }
        }
    }

    // Bottom controls view
    private var bottomControls: some View {
        let options = ["person.crop.rectangle.stack", "square.grid.2x2"]
        return BottomControls(
            shareAction: {
                if !person.photos.isEmpty {
                    activeSheet = .shareView
                } else {
                    print("No photos available to share")
                }
            },
            addPhotoAction: {
                showingImagePicker = true
            },
            selectedTab: $selectedTab,
            animationDirection: $animationDirection,
            options: options
        )
    }

    // Function to open image picker for a specific moment
    private func openImagePickerForMoment(_ section: String, _ dateRange: (Date, Date)) {
        currentSection = section
        currentMoment = section
        isImagePickerPresented = true
    }

    // Image loading function
    func loadImage() {
        guard !selectedAssets.isEmpty else { 
            print("No assets to load")
            return 
        }
        
        let dispatchGroup = DispatchGroup()
        
        for asset in selectedAssets {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                if let newPhoto = Photo(asset: asset) {
                    DispatchQueue.main.async {
                        self.viewModel.addPhoto(to: &self.person, asset: asset)
                        print("Added photo with date: \(newPhoto.dateTaken) and identifier: \(newPhoto.assetIdentifier)")
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.viewModel.updatePerson(self.person)
            print("All photos have been added")
            self.forceUpdate.toggle()
            self.viewModel.objectWillChange.send()
        }
    }

    // Function to delete a photo
    func deletePhoto(_ photo: Photo) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos.remove(at: index)
            viewModel.updatePerson(person)
        }
    }
    
    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Function to update photo date
    private func updatePhotoDate(_ photo: Photo, newDate: Date) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos[index].dateTaken = newDate
            viewModel.updatePerson(person)
        }
    }

    // Handler for selected assets change
    private func handleSelectedAssetsChange(oldValue: [PHAsset], newValue: [PHAsset]) {
        if !newValue.isEmpty {
            print("Assets selected: \(newValue)")
            loadImage()
        } else {
            print("No assets selected")
        }
    }

    // Handler for view appearance
    private func handleOnAppear() {
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
        }
    }

    // Alert for photo deletion confirmation
    private func deletePhotoAlert() -> Alert {
        Alert(
            title: Text("Delete Photo"),
            message: Text("Are you sure you want to delete this photo?"),
            primaryButton: .destructive(Text("Delete")) {
                if let photoToDelete = photoToDelete {
                    deletePhoto(photoToDelete)
                }
            },
            secondaryButton: .cancel()
        )
    }

    // Sheet for photo date picker
    private func photoDatePickerSheet() -> some View {
        PhotoDatePickerSheet(date: $editedDate, isPresented: $showingDatePicker) {
            if let photoToUpdate = selectedPhotoForDateEdit {
                updatePhotoDate(photoToUpdate, newDate: editedDate)
            }
        }
        .presentationDetents([.height(300)])
    }

    // Function to update scroll position
    private func updateScrollPosition(_ value: CGPoint) {
        let sections = sortedGroupedPhotosForAll().map { $0.0 }
        if let index = sections.firstIndex(where: { section in
            let sectionY = value.y + UIScreen.main.bounds.height / 2
            return sectionY >= 0 && sectionY <= UIScreen.main.bounds.height
        }) {
            currentScrollPosition = sections[index]
        }
    }

    // Function to scroll to stored position
    private func scrollToStoredPosition(proxy: ScrollViewProxy, section: String? = nil) {
        let positionToScroll = section ?? currentScrollPosition
        if let position = positionToScroll {
            withAnimation {
                proxy.scrollTo(position, anchor: .top)
            }
        }
    }

    // Functions for sorting and grouping photos
    private func sortedGroupedPhotosForAll() -> [(String, [Photo])] {
        return PhotoUtils.sortedGroupedPhotosForAll(person: person, viewModel: viewModel)
    }

    private func groupAndSortPhotos(forYearView: Bool) -> [(String, [Photo])] {
        return PhotoUtils.groupAndSortPhotos(for: person)
    }

    // Settings button view
    private var settingsButton: some View {
        Button(action: {
            activeSheet = .settings
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
    }

    // Content for different sheet presentations
    @ViewBuilder
    private func sheetContent(_ item: ActiveSheet) -> some View {
        switch item {
        case .settings:
            NavigationView {
                PersonSettingsView(viewModel: viewModel, person: $person)
            }
        case .shareView:
            ShareSlideshowView(
                photos: person.photos,
                person: person,
                sectionTitle: "All Photos"
            )
        case .customImagePicker(let moment, let dateRange):
            NavigationView {
                CustomImagePicker(
                    viewModel: viewModel,
                    person: $person,
                    sectionTitle: moment,
                    isPresented: Binding(
                        get: { self.activeSheet != nil },
                        set: { if !$0 { self.activeSheet = nil } }
                    ),
                    onPhotosAdded: { newPhotos in
                        // Handle newly added photos
                        viewModel.updatePerson(person)
                    }
                )
            }
        }
    }

    // Content for image picker
    private func imagePickerContent() -> some View {
        CustomImagePicker(
            viewModel: viewModel,
            person: $person,
            sectionTitle: currentMoment,
            isPresented: $isImagePickerPresented,
            onPhotosAdded: { newPhotos in
                // Handle newly added photos
                viewModel.updatePerson(person)
            }
        )
    }

    // Function to delete a person
    private func deletePerson() {
        viewModel.deletePerson(person)
        shouldNavigateBack = true
    }
}

// Preference key for scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

// View modifier to track scroll position
struct ScrollOffsetModifier: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGPoint

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named(coordinateSpace)).origin)
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

// Extension for easier use of scroll tracking
extension View {
    func trackScrollOffset(coordinateSpace: String, offset: Binding<CGPoint>) -> some View {
        modifier(ScrollOffsetModifier(coordinateSpace: coordinateSpace, offset: offset))
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
