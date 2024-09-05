//
//  TimelineView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/4/24.
//

import Foundation
import SwiftUI

// Main view struct for displaying photos in a timeline format
struct TimelineView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let forceUpdate: Bool
    let sectionTitle: String?
    let showScrubber: Bool
    @State private var photoUpdateTrigger = UUID()
    @State private var photosUpdateTrigger = UUID()
    @State private var currentAge: String = ""
    @State private var scrollPosition: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var timelineContentHeight: CGFloat = 0
    @State private var isDraggingTimeline: Bool = false
    @State private var indicatorPosition: CGFloat = 0
    @State private var scrubberHeight: CGFloat = 0
    @State private var isScrolling: Bool = false
    @State private var controlsOpacity: Double = 0
    @State private var controlsTimer: Timer?
    private let pillOffsetConstant: CGFloat = 10
    private let handleHeight: CGFloat = 60
    @State private var isDraggingPill: Bool = false
    @State private var pillHeight: CGFloat = 0
    @State private var lastHapticIndex: Int = -1
    @State private var showDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var blueLinePosition: CGFloat = 0
    private let agePillOffset: CGFloat = 15
    @State private var localPhotos: [Photo] = []

    // Layout constants
    private let timelineWidth: CGFloat = 20
    private let timelinePadding: CGFloat = 0
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 14
    private let bottomPadding: CGFloat = 80
    private let agePillPadding: CGFloat = 0
    private let timelineScrubberPadding: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Main scrollable content
                CustomScrollView(
                    content: {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredPhotos()) { photo in
                                FilmReelItemView(
                                    photo: photo,
                                    person: person,
                                    selectedPhoto: $selectedPhoto,
                                    geometry: geometry,
                                    horizontalPadding: horizontalPadding,
                                    timelineWidth: timelineWidth,
                                    timelinePadding: timelinePadding,
                                    onDelete: {
                                        photoToDelete = photo
                                        showDeleteAlert = true
                                    }
                                )
                                .id(photo.id)
                            }
                        }
                        .id(photosUpdateTrigger)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, verticalPadding)
                        .padding(.bottom, bottomPadding)
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.onAppear {
                                    timelineContentHeight = contentGeometry.size.height
                                }
                            }
                        )
                        .onChange(of: person.photos) { _, _ in
                            photosUpdateTrigger = UUID()
                        }
                    }, scrollPosition: $scrollPosition, isDraggingTimeline: $isDraggingTimeline
                )
                .id(photoUpdateTrigger)
                .background(
                    GeometryReader { scrollViewGeometry in
                        Color.clear.onAppear {
                            scrollViewHeight = scrollViewGeometry.size.height
                        }
                    }
                )
                .onChange(of: scrollPosition) { oldValue, newValue in
                    updateCurrentAge()
                    isScrolling = true
                    controlsOpacity = 1  // Show controls when scrolling starts
                    startControlsTimer()
                }

                // Timeline scrubber and age pill
                if showScrubber {
                    ZStack(alignment: .topTrailing) {
                        TimelineScrubber(
                            photos: filteredPhotos(),
                            scrollPosition: $scrollPosition,
                            contentHeight: timelineContentHeight,
                            isDraggingTimeline: $isDraggingTimeline,
                            indicatorPosition: $indicatorPosition,
                            blueLinePosition: $blueLinePosition
                        )
                        .frame(width: timelineWidth)
                        .padding(.top, verticalPadding)
                        .background(
                            GeometryReader { scrubberGeometry in
                                Color.clear.onAppear {
                                    scrubberHeight = scrubberGeometry.size.height
                                }
                            })

                        if isScrolling || isDraggingPill {
                            AgePillView(age: currentAge)
                                .padding(.trailing, timelineWidth + agePillPadding)
                                .offset(y: blueLinePosition - pillHeight / 2 + agePillOffset)
                                .background(
                                    GeometryReader { pillGeometry in
                                        Color.clear.onAppear {
                                            pillHeight = pillGeometry.size.height
                                        }
                                    }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDraggingPill = true
                                            isDraggingTimeline = true
                                            let dragPosition = value.location.y - agePillOffset
                                            updateScrollPositionFromPill(dragPosition)
                                            checkForHapticFeedback(dragPosition: dragPosition)
                                        }
                                        .onEnded { _ in
                                            isDraggingPill = false
                                            isDraggingTimeline = false
                                            lastHapticIndex = -1
                                        }
                                )
                        }
                    }
                    .opacity(controlsOpacity)
                    .animation(.easeInOut(duration: 0.2), value: controlsOpacity)
                }
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .photosUpdated)) { _ in
            photoUpdateTrigger = UUID()
        }
        .onAppear {
            updateCurrentAge()
            localPhotos = person.photos
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Remove Photo"),
                message: Text("Are you sure you want to remove this photo?"),
                primaryButton: .destructive(Text("Remove")) {
                    if let photoToDelete = photoToDelete {
                        viewModel.deletePhoto(photoToDelete, from: $person)
                        self.photoToDelete = nil
                        viewModel.objectWillChange.send()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .onChange(of: viewModel.mostRecentlyAddedPhoto) { _, newPhoto in
            if let newPhoto = newPhoto {
                DispatchQueue.main.async {
                    self.selectedPhoto = newPhoto
                    self.photosUpdateTrigger = UUID()
                    viewModel.mostRecentlyAddedPhoto = nil
                }
            }
        }
        .onChange(of: viewModel.photoAddedTrigger) {
            localPhotos = person.photos
            if let newPhoto = viewModel.mostRecentlyAddedPhoto {
                selectedPhoto = newPhoto
                viewModel.mostRecentlyAddedPhoto = nil
            }
        }
    }

    // Helper methods
    private func updateCurrentAge() {
        let visiblePhotoIndex = Int(
            scrollPosition / (UIScreen.main.bounds.width - 2 * horizontalPadding - timelineWidth))
        let photos = filteredPhotos()
        if visiblePhotoIndex < photos.count {
            let visiblePhoto = photos[visiblePhotoIndex]
            currentAge = PhotoUtils.sectionForPhoto(visiblePhoto, person: person)
        }
    }

    private func filteredPhotos() -> [Photo] {
        let filteredPhotos = person.photos.filter { photo in
            // Exclude pregnancy photos if pregnancy tracking is set to none
            if person.pregnancyTracking == .none {
                let exactAge = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                if exactAge.isPregnancy {
                    return false
                }
            }
            
            if let title = sectionTitle, title != "All Photos" {
                return PhotoUtils.sectionForPhoto(photo, person: person) == title
            }
            return true
        }
        return sortPhotos(filteredPhotos)
    }

    private func sortPhotos(_ photos: [Photo]) -> [Photo] {
        photos.sorted { $0.dateTaken > $1.dateTaken }
    }

    private func startControlsTimer() {
        controlsTimer?.invalidate()

        controlsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { timer in
            withAnimation(.easeOut(duration: 0.5)) {
                controlsOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isScrolling = false
            }
        }
    }

    private func updateScrollPositionFromPill(_ dragPosition: CGFloat) {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = max(
            0, min(1, (dragPosition - verticalPadding + agePillOffset) / availableHeight))
        scrollPosition = progress * (timelineContentHeight - scrollViewHeight)
    }

    private func checkForHapticFeedback(dragPosition: CGFloat) {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = max(
            0, min(1, (dragPosition - verticalPadding + agePillOffset) / availableHeight))
        let currentIndex = Int(round(progress * CGFloat(filteredPhotos().count - 1)))

        if currentIndex != lastHapticIndex {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            lastHapticIndex = currentIndex
        }
    }
}

// Custom scroll view implementation for the timeline
struct CustomScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var scrollPosition: CGFloat
    @Binding var isDraggingTimeline: Bool

    init(
        @ViewBuilder content: () -> Content, scrollPosition: Binding<CGFloat>,
        isDraggingTimeline: Binding<Bool>
    ) {
        self.content = content()
        self._scrollPosition = scrollPosition
        self._isDraggingTimeline = isDraggingTimeline
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .normal
        let hostView = UIHostingController(rootView: content)
        hostView.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostView.view)

        NSLayoutConstraint.activate([
            hostView.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostView.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostView.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostView.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostView.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if isDraggingTimeline {
            uiView.setContentOffset(CGPoint(x: 0, y: scrollPosition), animated: false)
        }
        uiView.subviews.first?.setNeedsLayout()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: CustomScrollView

        init(_ parent: CustomScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !parent.isDraggingTimeline {
                parent.scrollPosition = scrollView.contentOffset.y
            }
        }
    }
}

// View for displaying the current age as a pill-shaped overlay
struct AgePillView: View {
    let age: String

    var body: some View {
        if !age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(age)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    ZStack {
                        VisualEffectView(effect: UIBlurEffect(style: .dark))
                        Color.black.opacity(0.1)
                    }
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}

// View representing a single photo item in the timeline
struct FilmReelItemView: View {
    let photo: Photo
    let person: Person
    @Binding var selectedPhoto: Photo?
    let geometry: GeometryProxy
    let horizontalPadding: CGFloat
    let timelineWidth: CGFloat
    let timelinePadding: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var imageLoadingState: ImageLoadingState = .initial
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch imageLoadingState {
                case .initial:
                    Color.clear.onAppear(perform: loadImage)
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(width: itemWidth, height: itemWidth)
                case .loaded(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: itemWidth, height: itemWidth)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failed:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: itemWidth, height: itemWidth)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: itemWidth, height: itemWidth)

            if case .loaded = imageLoadingState {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(exactAge)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(6)
                    .foregroundColor(.white)
                    .padding(10)
            }
        }
        .frame(width: itemWidth, height: itemWidth)
        .padding(.vertical, 2)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedPhoto = photo
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onDelete()
                }
        )
        .background(colorScheme == .dark ? Color.black : Color.white)
    }

    private var itemWidth: CGFloat {
        geometry.size.width - (2 * horizontalPadding) - timelinePadding
    }

    private var exactAge: String {
        AgeCalculator.calculate(for: person, at: photo.dateTaken).toString()
    }

    private func loadImage() {
        imageLoadingState = .loading
        if let image = photo.image {
            imageLoadingState = .loaded(Image(uiImage: image))
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = photo.image {
                    DispatchQueue.main.async {
                        self.imageLoadingState = .loaded(Image(uiImage: image))
                    }
                } else {
                    DispatchQueue.main.async {
                        self.imageLoadingState = .failed
                    }
                }
            }
        }
    }
}

// Enum to manage the loading state of images
enum ImageLoadingState {
    case initial
    case loading
    case loaded(Image)
    case failed
}