//
//  SharedViews.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import PhotosUI
import Photos

// PhotoView: Displays a single photo in the timeline or grid view
struct PhotoView: View {
    let photo: Photo
    let containerWidth: CGFloat
    let isGridView: Bool
    @Binding var selectedPhoto: Photo?
    let person: Person

    var body: some View {
        Image(uiImage: photo.image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: containerWidth)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                selectedPhoto = photo
            }
    }
}

// ShareButton: A reusable button component for sharing functionality
struct ShareButton: View {
    var body: some View {
        Button(action: {
            // Share logic
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
                .font(.system(size: 24, weight: .bold))
        }
    }
}

// PhotoUtils: Utility struct containing helper functions for photo management and organization
public struct PhotoUtils {

    static func groupAndSortPhotos(for person: Person) -> [(String, [Photo])] {
        let sortedPhotos = person.photos.sorted { $0.dateTaken < $1.dateTaken }
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let sectionTitle = sectionForPhoto(photo, person: person)
            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        return groupedPhotos.sorted { $0.key < $1.key }
    }

    static func sortedGroupedPhotosForAll(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        return groupAndSortPhotos(for: person)
    }

    static func sortedGroupedPhotosForAllIncludingEmpty(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        let allStacks = getAllExpectedStacks(for: person)
        let groupedPhotos = Dictionary(grouping: person.photos) { photo in
            PhotoUtils.sectionForPhoto(photo, person: person)
        }
        
        let completeGroupedPhotos = allStacks.map { stack in
            (stack, groupedPhotos[stack] ?? [])
        }
        
        return completeGroupedPhotos.sorted { $0.0 < $1.0 }
    }

    static func getAllExpectedStacks(for person: Person) -> [String] {
        var stacks: [String] = []
        let calendar = Calendar.current
        let currentDate = Date()
        
        let endDate = min(person.dateOfBirth, currentDate)
        let pregnancyStartDate = calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth
        
        // Include pregnancy stacks only if tracking is set to trimesters or weeks
        switch person.pregnancyTracking {
        case .trimesters:
            let trimesterDuration = TimeInterval(91 * 24 * 60 * 60) // 91 days in seconds
            for i in 0..<3 {
                let trimesterStart = pregnancyStartDate.addingTimeInterval(Double(i) * trimesterDuration)
                if trimesterStart < endDate {
                    stacks.append(["First Trimester", "Second Trimester", "Third Trimester"][i])
                }
            }
        case .weeks:
            for week in 1...40 {
                let weekStart = pregnancyStartDate.addingTimeInterval(Double(week - 1) * 7 * 24 * 60 * 60)
                if weekStart < endDate {
                    stacks.append("Week \(week)")
                }
            }
        case .none:
            // Don't add any pregnancy stacks
            break
        }
        
        // Handle past or current birth dates
        if person.dateOfBirth <= currentDate {
            let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
            let currentAgeInMonths = max(0, (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0))
            let currentAgeInYears = ageComponents.year ?? 0

            switch person.birthMonthsDisplay {
            case .none:
                stacks.append("Birth Year")
                stacks.append(contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
            case .twelveMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(11, currentAgeInMonths)
                stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                stacks.append(contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
            case .twentyFourMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(23, currentAgeInMonths)
                stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                if currentAgeInYears >= 2 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
        }
        
        return stacks
    }
    
    static func getDateRangeForSection(_ section: String, person: Person) throws -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let birthDate = person.dateOfBirth

        switch section {
        case "Pregnancy":
            let start = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            return (start: start, end: birthDate)
        case "First Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            return (start: pregnancyStart, end: end)
        case "Second Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
            return (start: start, end: end)
        case "Third Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
            return (start: start, end: birthDate)
        case "Birth Month":
            let start = person.dateOfBirth
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start)!
            let end = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
            return (start: start, end: end)
        case "Birth Year":
            let start = calendar.startOfDay(for: birthDate)
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            let adjustedEnd = calendar.date(byAdding: .day, value: -1, to: end)!
            return (start: start, end: adjustedEnd)
        default:
            if section.contains("Month") {
                if let months = Int(section.components(separatedBy: " ").first ?? "") {
                    let start = calendar.date(byAdding: .month, value: months - 1, to: birthDate) ?? birthDate
                    let end = calendar.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
                    return (start: start, end: end)
                }
            } else if section.contains("Year") {
                if let years = Int(section.components(separatedBy: " ").first ?? "") {
                    let start = calendar.date(byAdding: .year, value: years - 1, to: birthDate) ?? birthDate
                    let end = calendar.date(byAdding: .year, value: years, to: birthDate) ?? birthDate
                    let adjustedEnd = calendar.date(byAdding: .day, value: -1, to: end) ?? end
                    return (start: start, end: adjustedEnd)
                }
            } else if section.starts(with: "Week") {
                if let week = Int(section.components(separatedBy: " ").last ?? "") {
                    let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
                    let start = calendar.date(byAdding: .day, value: (week - 1) * 7, to: pregnancyStart) ?? pregnancyStart
                    let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                    return (start: start, end: end)
                }
            }
            throw NSError(domain: "Invalid section", code: 0, userInfo: nil)
        }
    }

    static func sectionForPhoto(_ photo: Photo, person: Person) -> String {
        let exactAge = AgeCalculator.calculate(for: person, at: photo.dateTaken)
        let calendar = Calendar.current
        
        if exactAge.isPregnancy {
            switch person.pregnancyTracking {
            case .none:
                return "" // Return an empty string for photos before birth when tracking is off
            case .trimesters:
                let trimester = (exactAge.pregnancyWeeks - 1) / 13 + 1
                return "\(["First", "Second", "Third"][trimester - 1]) Trimester"
            case .weeks:
                return "Week \(exactAge.pregnancyWeeks)"
            }
        }
        
        // Check if the photo is within the birth month
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: person.dateOfBirth)!
        let endOfBirthMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        if photo.dateTaken >= person.dateOfBirth && photo.dateTaken <= endOfBirthMonth {
            return "Birth Month"
        }
        
        switch person.birthMonthsDisplay {
        case .none:
            return exactAge.years == 0 ? "Birth Year" : "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
        case .twelveMonths:
            if exactAge.years == 0 {
                return "\(exactAge.months) Month\(exactAge.months == 1 ? "" : "s")"
            } else if exactAge.years == 1 && exactAge.months == 0 {
                return "1 Year"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        case .twentyFourMonths:
            if exactAge.months < 24 {
                return "\(exactAge.months) Month\(exactAge.months == 1 ? "" : "s")"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        }
    }

    static func getGeneralAgeStacks(for person: Person) -> [String] {
        var stacks: [String] = ["Pregnancy"]
        let calendar = Calendar.current
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
        let currentAgeInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)
        let currentAgeInYears = ageComponents.year ?? 0

        switch person.birthMonthsDisplay {
        case .none:
            stacks.append("Birth Year")
            stacks.append(contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
        case .twelveMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(11, currentAgeInMonths)
            stacks.append(contentsOf: (0...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
            if currentAgeInMonths >= 12 {
                stacks.append("1 Year")
                if currentAgeInYears > 1 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
        case .twentyFourMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(23, currentAgeInMonths)
            stacks.append(contentsOf: (0...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
            if currentAgeInYears >= 2 {
                stacks.append(contentsOf: (2...max(2, currentAgeInYears)).map { "\($0) Years" })
            }
        }
        
        return stacks
    }

    enum DateRangeError: Error {
        case invalidDate(String)
        case invalidSection(String)
    }
}


// EmptyStateView: Displays a message when there are no photos
struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImageName: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImageName)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .onTapGesture(perform: action)
    }
}

// BirthDaySheet: View for selecting the date of birth
struct BirthDaySheet: View {
    @Binding var dateOfBirth: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .padding()
                .navigationTitle("Select Date of Birth")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    isPresented = false
                })
        }
    }
}

// PhotoDatePickerSheet: View for editing the date of a photo
struct PhotoDatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool
    var onSave: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Text("Edit Date")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    onSave()
                    isPresented = false
                }
            }
            .padding()

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// SharedTimelineView: Main view for displaying photos in a timeline format
struct SharedTimelineView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let forceUpdate: Bool
    let sectionTitle: String?
    let showScrubber: Bool  // Add this line
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
                CustomScrollView(content: {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPhotos()) { photo in
                            FilmReelItemView(photo: photo,
                                             person: person,
                                             selectedPhoto: $selectedPhoto,
                                             geometry: geometry,
                                             horizontalPadding: horizontalPadding,
                                             timelineWidth: timelineWidth,
                                             timelinePadding: timelinePadding,
                                             onDelete: {
                                                 photoToDelete = photo
                                                 showDeleteAlert = true
                                             })
                                .id(photo.id)
                        }
                    }
                    .id(photosUpdateTrigger)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, verticalPadding)
                    .padding(.bottom, bottomPadding)
                    .background(GeometryReader { contentGeometry in
                        Color.clear.onAppear {
                            timelineContentHeight = contentGeometry.size.height
                        }
                    })
                    .onChange(of: person.photos) { _, _ in
                        photosUpdateTrigger = UUID()
                    }
                }, scrollPosition: $scrollPosition, isDraggingTimeline: $isDraggingTimeline)
                .id(photoUpdateTrigger)
                .background(GeometryReader { scrollViewGeometry in
                    Color.clear.onAppear {
                        scrollViewHeight = scrollViewGeometry.size.height
                    }
                })
                .onChange(of: scrollPosition) { oldValue, newValue in
                    updateCurrentAge()
                    isScrolling = true
                    controlsOpacity = 1 // Show controls when scrolling starts
                    startControlsTimer()
                }

                if showScrubber {  // Add this condition
                    ZStack(alignment: .topTrailing) {
                        TimelineScrubber(photos: filteredPhotos(),
                                         scrollPosition: $scrollPosition,
                                         contentHeight: timelineContentHeight,
                                         isDraggingTimeline: $isDraggingTimeline,
                                         indicatorPosition: $indicatorPosition)
                            .frame(width: timelineWidth)
                            .padding(.top, verticalPadding)
                            .background(GeometryReader { scrubberGeometry in
                                Color.clear.onAppear {
                                    scrubberHeight = scrubberGeometry.size.height
                                }
                            })

                        if isScrolling || isDraggingPill {
                            AgePillView(age: currentAge)
                                .padding(.trailing, timelineWidth + agePillPadding)
                                .offset(y: pillOffset)
                                .background(GeometryReader { pillGeometry in
                                    Color.clear.onAppear {
                                        pillHeight = pillGeometry.size.height
                                    }
                                })
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDraggingPill = true
                                            isDraggingTimeline = true
                                            let dragPosition = value.location.y
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
    }

    private var pillOffset: CGFloat {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding - pillHeight
        let progress = min(1, max(0, scrollPosition / (timelineContentHeight - scrollViewHeight)))
        return verticalPadding + (availableHeight * progress) - pillOffsetConstant
    }

    private func updateCurrentAge() {
        let visiblePhotoIndex = Int(scrollPosition / (UIScreen.main.bounds.width - 2 * horizontalPadding - timelineWidth))
        let photos = filteredPhotos()
        if visiblePhotoIndex < photos.count {
            let visiblePhoto = photos[visiblePhotoIndex]
            currentAge = PhotoUtils.sectionForPhoto(visiblePhoto, person: person)
        }
    }

    private func filteredPhotos() -> [Photo] {
        let filteredPhotos = person.photos.filter { photo in
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
        let progress = max(0, min(1, (dragPosition - verticalPadding + pillOffsetConstant) / availableHeight))
        scrollPosition = progress * (timelineContentHeight - scrollViewHeight)
    }

    private func checkForHapticFeedback(dragPosition: CGFloat) {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = max(0, min(1, (dragPosition - verticalPadding + pillOffsetConstant) / availableHeight))
        let currentIndex = Int(round(progress * CGFloat(filteredPhotos().count - 1)))
        
        if currentIndex != lastHapticIndex {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            lastHapticIndex = currentIndex
        }
    }
}

// CustomScrollView: A custom scroll view implementation for the timeline
struct CustomScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    @Binding var scrollPosition: CGFloat
    @Binding var isDraggingTimeline: Bool

    init(@ViewBuilder content: () -> Content, scrollPosition: Binding<CGFloat>, isDraggingTimeline: Binding<Bool>) {
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
            hostView.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
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

// AgePillView: Displays the current age as a pill-shaped overlay
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

// FilmReelItemView: Represents a single photo item in the timeline view
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

// ImageLoadingState: Enum to manage the loading state of images
enum ImageLoadingState {
    case initial
    case loading
    case loaded(Image)
    case failed
}

// SharedGridView: Displays photos in a grid layout
struct SharedGridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let sectionTitle: String?
    @State private var photoUpdateTrigger = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 10) {
                    ForEach(filteredPhotos()) { photo in
                        Image(uiImage: photo.displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: GridLayoutHelper.gridItemWidth(for: geometry.size), 
                                   height: GridLayoutHelper.gridItemWidth(for: geometry.size))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedPhoto = photo
                            }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
        }
        .id(photoUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .photosUpdated)) { _ in
            photoUpdateTrigger = UUID()
        }
    }
    
    private func filteredPhotos() -> [Photo] {
        let filteredPhotos = person.photos.filter { photo in
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
}

// Circular button component
struct CircularButton: View {
    let systemName: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    var size: CGFloat = 40
    var backgroundColor: Color?

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .foregroundColor(.white)
                .font(.system(size: size * 0.35, weight: .bold))
                .frame(width: size, height: size)
        }
        .background(
            ZStack {
                if let backgroundColor = backgroundColor {
                    backgroundColor
                } else {
                    VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                    if colorScheme == .light {
                        Color.black.opacity(0.4)
                    }
                    if colorScheme == .dark {
                        Color.white.opacity(0.2)
                    }
                }
            }
        )
        .clipShape(Circle())
    }
}

// Segmented control for switching between grid and timeline views
struct SegmentedControlView: View {
    @Binding var selectedTab: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    
    let options = ["person.crop.rectangle.stack", "square.grid.2x2"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.15)) {
                        animationDirection = index > selectedTab ? .forward : .reverse
                        selectedTab = index
                    }
                }) {
                    Image(systemName: options[index])
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 60, height: 36)
                        .background(
                            ZStack {
                                if selectedTab == index {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.3))
                                        .matchedGeometryEffect(id: "SelectedSegment", in: animation)
                                }
                            }
                        )
                        .foregroundColor(colorScheme == .dark ? (selectedTab == index ? .white : .white.opacity(0.5)) : (selectedTab == index ? .white : .black.opacity(0.5)))
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Capsule())
    }
}

// Bottom control bar with share, view toggle, and add photo buttons
struct BottomControls: View {
    let shareAction: () -> Void
    let addPhotoAction: () -> Void
    @Binding var selectedTab: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection
    let options: [String]

    var body: some View {
        HStack {
            CircularButton(systemName: "square.and.arrow.up", action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                shareAction()
            })
            Spacer()

            SegmentedControlView(selectedTab: $selectedTab, animationDirection: $animationDirection)

            Spacer()

            CircularButton(systemName: "plus", action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                addPhotoAction()
            }, size: 50, backgroundColor: .blue)
        }
        .padding(.horizontal)
    }
}

// Scrubber handle
struct ScrubberHandle: View {
    let tapAreaSize: CGFloat
    let lineHeight: CGFloat = 2
    let leftPadding: CGFloat = 4
    let tapAreaHeight: CGFloat = 60
    let blueLineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            // Clear background rectangle
            Rectangle()
                .fill(Color.clear)
                .frame(width: tapAreaSize, height: tapAreaHeight)
            
            HStack(spacing: 0) {
                Spacer() // This pushes the blue line to the right
                
                // Blue line
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: blueLineWidth, height: lineHeight)
            }
            .frame(width: tapAreaSize)
            
            // Transparent overlay for larger tap area
            Color.clear
                .frame(width: tapAreaSize, height: tapAreaHeight)
                .contentShape(Rectangle())
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
            .onChange(of: scrollPosition) { _ in
                updateIndicatorPosition(in: geometry)
            }
        }
    }

    private func photoOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let availableHeight = geometry.size.height - bottomPadding - topPadding
        return (CGFloat(index) / CGFloat(photos.count - 1)) * availableHeight + topPadding
    }

    private func updateIndicatorPosition(in geometry: GeometryProxy) {
        let scrollPercentage = min(1, max(0, scrollPosition / max(1, contentHeight - geometry.size.height)))
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

// UIViewRepresentable for visual effects
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

