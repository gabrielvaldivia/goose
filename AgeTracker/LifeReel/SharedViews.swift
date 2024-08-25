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

// Share button component
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

// Utility functions for photo management
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

// Date of birth selection sheet
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

// Empty state view for when there are no photos
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

// Date picker sheet for editing photo dates
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

// Main timeline view for displaying photos
struct SharedTimelineView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let forceUpdate: Bool
    let sectionTitle: String?
    @State private var photoUpdateTrigger = UUID()
    @State private var currentAge: String = ""
    @State private var scrollPosition: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var timelineContentHeight: CGFloat = 0
    @State private var isDraggingTimeline: Bool = false
    @State private var indicatorPosition: CGFloat = 0
    @State private var scrubberHeight: CGFloat = 0
    private let pillOffsetConstant: CGFloat = 10 // Constant offset to move the pill higher

    // Layout constants
    private let timelineWidth: CGFloat = 20
    private let timelinePadding: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 14
    private let bottomPadding: CGFloat = 60
    private let agePillPadding: CGFloat = 8
    private let timelineScrubberPadding: CGFloat = 24

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
                                             timelinePadding: timelinePadding)
                                .id(photo.id)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, verticalPadding)
                    .padding(.bottom, bottomPadding)
                    .padding(.trailing, timelineWidth + timelinePadding)
                    .background(GeometryReader { contentGeometry in
                        Color.clear.onAppear {
                            timelineContentHeight = contentGeometry.size.height
                        }
                    })
                }, scrollPosition: $scrollPosition, isDraggingTimeline: $isDraggingTimeline)
                .id(photoUpdateTrigger)
                .background(GeometryReader { scrollViewGeometry in
                    Color.clear.onAppear {
                        scrollViewHeight = scrollViewGeometry.size.height
                    }
                })
                .onChange(of: scrollPosition) { _ in
                    updateCurrentAge()
                }

                TimelineScrubber(photos: filteredPhotos(),
                                 scrollPosition: $scrollPosition,
                                 contentHeight: timelineContentHeight,
                                 isDraggingTimeline: $isDraggingTimeline,
                                 indicatorPosition: $indicatorPosition)
                    .frame(width: timelineWidth)
                    .padding(.trailing, timelineScrubberPadding)
                    .padding(.top, verticalPadding)
                    .background(GeometryReader { scrubberGeometry in
                        Color.clear.onAppear {
                            scrubberHeight = scrubberGeometry.size.height
                        }
                    })

                AgePillView(age: currentAge)
                    .padding(.trailing, timelineWidth + timelineScrubberPadding + agePillPadding)
                    .offset(y: pillOffset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .photosUpdated)) { _ in
            photoUpdateTrigger = UUID()
        }
        .onAppear {
            updateCurrentAge()
        }
    }

    private var pillOffset: CGFloat {
        let availableHeight = scrubberHeight - verticalPadding - bottomPadding
        let progress = min(1, max(0, indicatorPosition / availableHeight))
        return verticalPadding + (availableHeight * progress) - pillOffsetConstant
    }

    private func updateCurrentAge() {
        let visiblePhotoIndex = Int(scrollPosition / (UIScreen.main.bounds.width - 2 * horizontalPadding - timelineWidth - timelinePadding))
        let photos = filteredPhotos()
        if visiblePhotoIndex < photos.count {
            let visiblePhoto = photos[visiblePhotoIndex]
            currentAge = AgeCalculator.calculate(for: person, at: visiblePhoto.dateTaken).toString()
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

// Custom scroll view for timeline
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

// Age indicator pill view
struct AgePillView: View {
    let age: String
    
    var body: some View {
        Text(age)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// Individual photo item view for film reel
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
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    
    private var itemWidth: CGFloat {
        geometry.size.width - (2 * horizontalPadding) - timelineWidth - timelinePadding
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

// Image loading state enum
enum ImageLoadingState {
    case initial
    case loading
    case loaded(Image)
    case failed
}

// Grid view for displaying photos
struct SharedGridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let sectionTitle: String?
    @State private var photoUpdateTrigger = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 20) {
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
            return true  // If sectionTitle is nil or "All Photos", include all photos
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
    
    let options = ["square.grid.2x2", "person.crop.rectangle.stack"]
    
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
    let circleSize: CGFloat

    var body: some View {
        ZStack {
            // Semi-transparent yellow background for tap area
            Rectangle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: tapAreaSize, height: tapAreaSize)
            
            Circle()
                .fill(Color.red)
                .frame(width: circleSize, height: circleSize)
            
            // Transparent overlay for larger tap area
            Color.clear
                .frame(width: tapAreaSize, height: tapAreaSize)
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
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    private let circleSize: CGFloat = 20
    private let tapAreaSize: CGFloat = 44
    private let blueDotSize: CGFloat = 6
    private let bottomPadding: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ForEach(photos.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: blueDotSize, height: blueDotSize)
                        .offset(y: photoOffset(for: index, in: geometry))
                }

                // Indicator for current scroll position
                ScrubberHandle(tapAreaSize: tapAreaSize, circleSize: circleSize)
                    .offset(y: indicatorPosition - tapAreaSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                isDraggingTimeline = true
                                let newDragOffset = value.translation.height
                                updateScrollPosition(newDragOffset - dragOffset, in: geometry)
                                dragOffset = newDragOffset
                            }
                            .onEnded { _ in
                                isDragging = false
                                isDraggingTimeline = false
                                dragOffset = 0
                            }
                    )
            }
            .padding(.bottom, bottomPadding)
            .onAppear {
                // Set initial indicator position
                indicatorPosition = currentScrollIndicatorOffset(in: geometry)
            }
            .onChange(of: scrollPosition) { _ in
                indicatorPosition = currentScrollIndicatorOffset(in: geometry)
            }
        }
    }

    private func photoOffset(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        let totalPhotos = CGFloat(photos.count)
        let availableHeight = geometry.size.height - bottomPadding - tapAreaSize
        let offset = (CGFloat(index) / (totalPhotos - 1)) * availableHeight
        return offset + tapAreaSize / 2
    }

    private func currentScrollIndicatorOffset(in geometry: GeometryProxy) -> CGFloat {
        let scrollPercentage = min(1, max(0, scrollPosition / max(1, contentHeight - geometry.size.height)))
        let availableHeight = geometry.size.height - bottomPadding - tapAreaSize
        return scrollPercentage * availableHeight + tapAreaSize / 2
    }

    private func updateScrollPosition(_ dragAmount: CGFloat, in geometry: GeometryProxy) {
        let availableHeight = geometry.size.height - bottomPadding - tapAreaSize
        let dragPercentage = dragAmount / availableHeight
        let currentScrollPercentage = scrollPosition / max(1, contentHeight - geometry.size.height)
        let newScrollPercentage = min(1, max(0, currentScrollPercentage + dragPercentage))
        scrollPosition = newScrollPercentage * max(1, contentHeight - geometry.size.height)
    }
}
