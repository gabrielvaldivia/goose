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
    @State private var scrollViewHeight: CGFloat = 0
    @State private var timelineContentHeight: CGFloat = 0
    @State private var isDraggingTimeline: Bool = false
    @State private var indicatorPosition: CGFloat = 0
    @State private var scrubberHeight: CGFloat = 0
    @State private var isDraggingPill: Bool = false
    @State private var pillHeight: CGFloat = 0
    @State private var lastHapticIndex: Int = -1
    @State private var showDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var blueLinePosition: CGFloat = 0
    private let agePillOffset: CGFloat = 15
    @State private var localPhotos: [Photo] = []
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var scrollOffset: CGPoint = .zero
    @State private var scrollPosition: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var scrollTarget: Int?
    @State private var isScrollingProgrammatically = false
    @State private var isScrolling: Bool = false
    @State private var showScrubberAndPill: Bool = true
    @State private var hideTimer: Timer?

    // Layout constants
    private let timelineWidth: CGFloat = 20
    private let timelinePadding: CGFloat = 0
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 14
    private let bottomPadding: CGFloat = 80
    private let agePillPadding: CGFloat = 0
    private let timelineScrubberPadding: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            offsetReader
                            LazyVStack(spacing: 10) {
                                ForEach(Array(filteredPhotos().enumerated()), id: \.element.id) { index, photo in
                                    PhotoItemView(
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
                                    .id(index)
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
                        }
                        .scrollIndicators(.hidden)
                        .coordinateSpace(name: "scroll")
                        .onChange(of: scrollTarget) { _, newValue in
                            if let target = newValue {
                                isScrollingProgrammatically = true
                                withAnimation(.linear(duration: 0.05)) {
                                    proxy.scrollTo(target, anchor: .top)
                                }
                                // Reset the flag after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isScrollingProgrammatically = false
                                }
                            }
                        }
                        .onAppear {
                            scrollViewProxy = proxy
                        }
                    }
                    .id(photoUpdateTrigger)
                    .background(
                        GeometryReader { scrollViewGeometry in
                            Color.clear.onAppear {
                                scrollViewHeight = scrollViewGeometry.size.height
                            }
                        }
                    )
                    .onChange(of: scrollOffset) { _, _ in
                        handleScrollChange()
                    }

                    // Timeline scrubber and age pill
                    if showScrubber && showScrubberAndPill {
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
                                            handleDragChange()
                                            isDraggingPill = true
                                            isDraggingTimeline = true
                                            let dragPosition = value.location.y - agePillOffset
                                            updateScrollPositionFromPill(dragPosition)
                                            checkForHapticFeedback(dragPosition: dragPosition)
                                        }
                                        .onEnded { _ in
                                            handleDragEnd()
                                            isDraggingPill = false
                                            isDraggingTimeline = false
                                            lastHapticIndex = -1
                                        }
                                )
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: showScrubberAndPill)
                    }
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(sectionTitle ?? person.name)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
        }
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

    private var offsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named("scroll")).origin
                )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            if !isDragging && !isScrollingProgrammatically {
                scrollOffset = value
                scrollPosition = -value.y
                updateCurrentAge()
            }
        }
    }

    // Helper methods
    private func updateCurrentAge() {
        let photos = filteredPhotos()
        let visiblePhotoIndex = min(max(0, Int(scrollPosition / (UIScreen.main.bounds.width - 2 * horizontalPadding - timelineWidth))), photos.count - 1)
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

    private func updateScrollPositionFromPill(_ dragPosition: CGFloat) {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = max(0, min(1, (dragPosition - verticalPadding) / availableHeight))
        let photos = filteredPhotos()
        let targetIndex = Int(progress * CGFloat(photos.count - 1))
        scrollTarget = targetIndex
        scrollPosition = CGFloat(targetIndex) * (UIScreen.main.bounds.width - 2 * horizontalPadding - timelineWidth)
        updateCurrentAge()
    }

    private func checkForHapticFeedback(dragPosition: CGFloat) {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = max(0, min(1, (dragPosition - verticalPadding) / availableHeight))
        let currentIndex = Int(round(progress * CGFloat(filteredPhotos().count - 1)))

        if currentIndex != lastHapticIndex {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            lastHapticIndex = currentIndex
        }
    }

    private func handleScrollChange() {
        isScrolling = true
        showScrubberAndPill = true
        resetHideTimer()
    }

    private func handleDragChange() {
        isDragging = true
        showScrubberAndPill = true
        resetHideTimer()
    }

    private func handleDragEnd() {
        isDragging = false
        resetHideTimer()
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation {
                showScrubberAndPill = false
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
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
struct PhotoItemView: View {
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

// Timeline scrubber
struct TimelineScrubber: View {
    let photos: [Photo]
    @Binding var scrollPosition: CGFloat
    let contentHeight: CGFloat
    @Binding var isDraggingTimeline: Bool
    @Binding var indicatorPosition: CGFloat
    @Binding var blueLinePosition: CGFloat
    @State private var lastHapticIndex: Int = -1

    private let tapAreaSize: CGFloat = 20
    private let lineWidth: CGFloat = 8
    private let lineHeight: CGFloat = 1
    private let bottomPadding: CGFloat = 100
    private let topPadding: CGFloat = 0
    private let handleHeight: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: tapAreaSize)

                ForEach(photos.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: lineWidth, height: lineHeight)
                        .offset(y: photoOffset(for: index, in: geometry))
                }

                ScrubberHandle(tapAreaSize: tapAreaSize)
                    .offset(y: indicatorPosition - handleHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleDrag(value, in: geometry)
                                blueLinePosition = indicatorPosition
                            }
                            .onEnded { _ in
                                endDrag()
                            }
                    )
            }
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .onAppear {
                updateIndicatorPosition(in: geometry)
            }
            .onChange(of: scrollPosition) { oldValue, newValue in
                updateIndicatorPosition(in: geometry)
                blueLinePosition = indicatorPosition
            }
        }
    }

    private func photoOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let availableHeight = geometry.size.height - bottomPadding - topPadding
        return (CGFloat(index) / CGFloat(photos.count - 1)) * availableHeight + topPadding
    }

    private func updateIndicatorPosition(in geometry: GeometryProxy) {
        let scrollPercentage = min(
            1, max(0, scrollPosition / max(1, contentHeight - geometry.size.height)))
        let availableHeight = geometry.size.height - bottomPadding - topPadding
        indicatorPosition = scrollPercentage * availableHeight + topPadding
    }

    private func handleDrag(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        isDraggingTimeline = true
        let availableHeight = geometry.size.height - bottomPadding - topPadding
        let dragPercentage = value.translation.height / availableHeight
        let currentScrollPercentage = scrollPosition / max(1, contentHeight - geometry.size.height)
        let newScrollPercentage = min(1, max(0, currentScrollPercentage + dragPercentage))
        scrollPosition = newScrollPercentage * max(1, contentHeight - geometry.size.height)

        checkForHapticFeedback(in: geometry)
    }

    private func endDrag() {
        isDraggingTimeline = false
        lastHapticIndex = -1
    }

    private func checkForHapticFeedback(in geometry: GeometryProxy) {
        let currentIndex = getCurrentPhotoIndex(in: geometry)
        if currentIndex != lastHapticIndex {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            lastHapticIndex = currentIndex
        }
    }

    private func getCurrentPhotoIndex(in geometry: GeometryProxy) -> Int {
        let availableHeight = geometry.size.height - bottomPadding - topPadding
        let currentPosition = indicatorPosition - topPadding
        let percentage = currentPosition / availableHeight
        return Int(round(percentage * CGFloat(photos.count - 1)))
    }
}

// Enum to manage the loading state of images
enum ImageLoadingState {
    case initial
    case loading
    case loaded(Image)
    case failed
}
