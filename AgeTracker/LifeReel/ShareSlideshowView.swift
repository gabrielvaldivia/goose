//
//  ShareSlideshowView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import AVFoundation
import Foundation
import Photos
import SwiftUI
import Vision

enum SlideshowRange: Hashable {
    case allPhotos, pregnancy, birthMonth
    case month(Int)
    case year(Int)
    case custom(String)

    var displayName: String {
        switch self {
        case .allPhotos: return "All Photos"
        case .pregnancy: return "Pregnancy"
        case .birthMonth: return "Birth Month"
        case .month(let value): return "\(value) Month\(value == 1 ? "" : "s")"
        case .year(let value): return "\(value) Year\(value == 1 ? "" : "s")"
        case .custom(let value): return value
        }
    }

    static var allCases: [SlideshowRange] {
        var cases: [SlideshowRange] = [.allPhotos, .pregnancy, .birthMonth]
        for month in 1...12 {
            cases.append(.month(month))
        }
        for year in 1...18 {
            cases.append(.year(year))
        }
        return cases
    }
}

enum SharePlatform {
    case facebook, instagram, instagramStory, other

    var label: String {
        switch self {
        case .facebook: return "Facebook"
        case .instagram: return "Instagram"
        case .instagramStory: return "IG Story"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .facebook: return "f.square"
        case .instagram: return "camera"
        case .instagramStory: return "square.and.arrow.up"
        case .other: return "square.and.arrow.up"
        }
    }
}

// ShareSlideshowView
struct ShareSlideshowView: View {
    // Properties
    let photos: [Photo]
    let person: Person
    let sectionTitle: String?
    @State private var currentPhotoIndex = 0
    @State private var isPlaying = true
    @State private var playbackSpeed: Double = 1.0
    @State private var isSharePresented = false
    @State private var showComingSoonAlert = false
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var timer: Timer?
    @State private var scrubberPosition: Double = 0
    @Environment(\.presentationMode) var presentationMode

    @State private var currentFilteredPhotoIndex = 0
    @State private var aspectRatio: AspectRatio = .portrait
    @State private var showAppIcon: Bool = true
    @State private var titleOption: TitleOption = .name
    @State private var subtitleOption: TitleOption = .age
    @State private var speedOptions = [1.0, 2.0, 3.0]

    @State private var currentImageId = UUID()
    @State private var baseImageDuration: Double = 3.0  // Base duration for each image
    @State private var imageDuration: Double = 3.0  // Actual duration, affected by speed
    @State private var effectOption: EffectOption = .kenBurns

    @State private var audioPlayer: AVAudioPlayer?
    @State private var selectedMusic: String?

    private let availableMusic = ["Serenity", "Echoes", "Sunshine", "Whispers"]

    @State private var milestoneMode: MilestoneMode
    private let forceAllPhotos: Bool

    @State private var isEditing: Bool = false

    init(photos: [Photo], person: Person, sectionTitle: String? = nil, forceAllPhotos: Bool = false)
    {
        self.photos = photos
        self.person = person
        self.sectionTitle = sectionTitle
        self.forceAllPhotos = forceAllPhotos

        // Subtitle option always defaults to age
        _subtitleOption = State(initialValue: .age)

        // Randomly select a song
        _selectedMusic = State(initialValue: availableMusic.randomElement())

        // Ensure isPlaying is true by default
        _isPlaying = State(initialValue: true)

        // Set milestone mode based on the forceAllPhotos parameter
        _milestoneMode = State(initialValue: forceAllPhotos ? .allPhotos : .milestones)
    }

    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"

        var description: String { self.rawValue }
    }

    enum EffectOption: String, CaseIterable, CustomStringConvertible {
        case kenBurns = "Ken Burns"
        case none = "None"

        var description: String { self.rawValue }
    }

    enum MilestoneMode: String, CaseIterable, CustomStringConvertible {
        case allPhotos = "All Photos"
        case milestones = "Milestones"

        var description: String { self.rawValue }
    }

    // Body
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            navigationBar

            contentView
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear(perform: onAppear)
        .onChange(of: isPlaying) { oldValue, newValue in
            handlePlayingChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: playbackSpeed) { oldValue, newValue in
            handleSpeedChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: currentFilteredPhotoIndex) { oldValue, newValue in
            handleIndexChange(oldValue: oldValue, newValue: newValue)
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert, actions: comingSoonAlert)
        .onDisappear {
            stopAudio()
        }
        .onChange(of: milestoneMode) { oldValue, newValue in
            if forceAllPhotos && newValue != .allPhotos {
                milestoneMode = .allPhotos
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if filteredPhotos.isEmpty {
            emptyStateView
        } else {
            VStack {
                photoView
                if isEditing {
                    bottomControls
                } else {
                    shareOptions
                }
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            if isEditing {
                Button("Cancel") {
                    withAnimation {
                        isEditing = false
                        // Revert any unsaved changes here
                    }
                }
            } else {
                cancelButton
            }
            Spacer()
            Text("Slideshow")
                .font(.headline)
            Spacer()
            if isEditing {
                Button("Save") {
                    withAnimation {
                        isEditing = false
                        // Save changes here
                    }
                }
            } else {
                editButton
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var emptyStateView: some View {
        Text("No photos available for this range")
            .foregroundColor(.secondary)
            .padding()
    }

    private var photoView: some View {
        VStack {
            Spacer()
            if !filteredPhotos.isEmpty {
                let safeIndex = min(currentFilteredPhotoIndex, filteredPhotos.count - 1)
                if safeIndex >= 0 && safeIndex < filteredPhotos.count {
                    ZStack {
                        LazyImage(
                            photo: filteredPhotos[safeIndex],
                            loadedImage: loadedImages[filteredPhotos[safeIndex].id.uuidString]
                                ?? UIImage(),
                            aspectRatio: aspectRatio.value,
                            showAppIcon: showAppIcon,
                            titleText: getTitleText(for: filteredPhotos[safeIndex]),
                            subtitleText: getSubtitleText(for: filteredPhotos[safeIndex]),
                            duration: imageDuration,
                            isPlaying: isPlaying,
                            effectOption: effectOption,
                            isActive: isPlaying
                        )
                        .id(currentImageId)
                        .transition(effectOption == .none ? .identity : .opacity)

                        // Play button overlay (only shown when paused)
                        if !isPlaying {
                            PlayButton(isPlaying: $isPlaying)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .contentShape(Rectangle())  // Ensures the entire area is tappable
                    .onTapGesture {
                        isPlaying.toggle()
                    }
                } else {
                    Text("No photos available")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No photos available")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var shareOptions: some View {
        HStack(spacing: 20) {
            shareButton(for: .facebook)
            shareButton(for: .instagram)
            shareButton(for: .instagramStory)
            shareButton(for: .other)
        }
        .padding()
    }

    private func shareButton(for platform: SharePlatform) -> some View {
        Button(action: {
            shareToPlaftorm(platform)
        }) {
            VStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: platform.iconName)
                            .foregroundColor(.primary)
                    )
                Text(platform.label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }

    private var editButton: some View {
        Button("Edit") {
            withAnimation {
                isEditing = true
            }
        }
    }

    private func shareToPlaftorm(_ platform: SharePlatform) {
        switch platform {
        case .facebook, .instagram, .instagramStory:
            // Implement specific sharing logic for each platform
            print("Sharing to \(platform.label)")
        case .other:
            // Implement native share sheet
            print("Opening native share sheet")
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {

                    // Title
                    SimplifiedCustomizationButton(
                        icon: "textformat",
                        title: "Title",
                        options: TitleOption.allCases,
                        selection: $titleOption
                    )
                    .frame(width: 80)

                    // Subtitle
                    SimplifiedCustomizationButton(
                        icon: "text.alignleft",
                        title: "Subtitle",
                        options: TitleOption.allCases,
                        selection: $subtitleOption
                    )
                    .frame(width: 80)

                    // Effect
                    SimplifiedCustomizationButton(
                        icon: "wand.and.stars",
                        title: "Effect",
                        options: EffectOption.allCases,
                        selection: $effectOption
                    )
                    .frame(width: 80)

                    // Music Control
                    SimplifiedCustomizationButton(
                        icon: "music.note",
                        title: "Music",
                        options: ["None"] + availableMusic,
                        selection: musicBinding
                    )
                    .frame(width: 80)

                    // Speed
                    SimplifiedCustomizationButton(
                        icon: "speedometer",
                        title: "Speed",
                        options: speedOptions.map { "\(Int($0))x" },
                        selection: Binding(
                            get: { "\(Int(self.playbackSpeed))x" },
                            set: { newValue in
                                if let speed = Double(newValue.dropLast()) {
                                    self.playbackSpeed = speed
                                    self.handleSpeedChange(
                                        oldValue: self.playbackSpeed, newValue: speed)
                                }
                            }
                        )
                    )
                    .frame(width: 80)

                    // Aspect Ratio
                    SimplifiedCustomizationButton(
                        icon: "aspectratio",
                        title: "Aspect Ratio",
                        options: [AspectRatio.square, AspectRatio.portrait],
                        selection: $aspectRatio
                    )
                    .frame(width: 80)

                    // Milestone Mode
                    if !forceAllPhotos {
                        SimplifiedCustomizationButton(
                            icon: "photo.on.rectangle.angled",
                            title: "Photos",
                            options: MilestoneMode.allCases,
                            selection: $milestoneMode
                        )
                        .frame(width: 80)
                    }

                    // Watermark
                    Button(action: { showAppIcon.toggle() }) {
                        VStack(spacing: 6) {
                            Image(
                                systemName: showAppIcon ? "checkmark.seal.fill" : "checkmark.seal"
                            )
                            .font(.system(size: 24))
                            .frame(height: 28)
                            Text("Watermark")
                                .font(.caption)
                        }
                        .frame(width: 80)
                    }
                    .foregroundColor(.primary)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
            }
        }
        .frame(height: 80)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var musicBinding: Binding<String> {
        Binding(
            get: { self.selectedMusic ?? "None" },
            set: { newValue in
                self.stopAudio()
                self.selectedMusic = newValue == "None" ? nil : newValue
                if self.selectedMusic != nil {
                    self.setupAudioPlayer()
                    if self.isPlaying {
                        self.audioPlayer?.play()
                    }
                }
            }
        )
    }

    private func onAppear() {
        print("View appeared, isPlaying: \(isPlaying)")
        loadImagesAround(index: currentFilteredPhotoIndex)
        setupAudioPlayer()
        startTimer()
        if isPlaying {
            audioPlayer?.play()
        }
    }

    private func handlePlayingChange(oldValue: Bool, newValue: Bool) {
        if newValue {
            startTimer()
            audioPlayer?.play()
        } else {
            stopTimer()
            audioPlayer?.pause()
        }
    }

    private func handleSpeedChange(oldValue: Double, newValue: Double) {
        imageDuration = baseImageDuration / newValue
        if isPlaying {
            stopTimer()
            startTimer()
        }
    }

    private func handleIndexChange(oldValue: Int, newValue: Int) {
        if !isPlaying {
            scrubberPosition = Double(newValue)
        }
        currentImageId = UUID()
    }

    private func comingSoonAlert() -> some View {
        Button("OK", role: .cancel) {}
    }

    // Helper Methods
    private func loadImagesAround(index: Int) {
        let photos = filteredPhotos
        guard !photos.isEmpty else { return }

        let count = photos.count
        let safeIndex = (index + count) % count

        // Determine the range of indices to load
        let rangeToLoad: [Int]
        if count <= 11 {
            // If we have 11 or fewer photos, load all of them
            rangeToLoad = Array(0..<count)
        } else {
            // Otherwise, load 5 before and 5 after the current index
            rangeToLoad = (-5...5).map { (safeIndex + $0 + count) % count }
        }

        for i in rangeToLoad {
            let photo = photos[i]
            if loadedImages[photo.id.uuidString] == nil {
                loadedImages[photo.id.uuidString] = photo.image
            }
        }
    }

    private func calculateGeneralAge(for person: Person, at date: Date) -> String {
        let exactAge = AgeCalculator.calculate(for: person, at: date)

        if exactAge.isPregnancy {
            switch person.pregnancyTracking {
            case .none:
                return ""
            case .trimesters:
                let trimester = (exactAge.pregnancyWeeks - 1) / 13 + 1
                return "\(["First", "Second", "Third"][trimester - 1]) Trimester"
            case .weeks:
                return "Week \(exactAge.pregnancyWeeks)"
            }
        }

        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: person.dateOfBirth)!
        let endOfBirthMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        if date >= person.dateOfBirth && date <= endOfBirthMonth {
            return "Birth Month"
        }

        switch person.birthMonthsDisplay {
        case .none:
            return exactAge.years == 0
                ? "Birth Year" : "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
        case .twelveMonths:
            if exactAge.years == 0 {
                return "\(exactAge.months) Month\(exactAge.months == 1 ? "" : "s")"
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func getTitleText(for photo: Photo) -> String {
        switch titleOption {
        case .none: return ""
        case .name: return person.name
        case .age: return calculateGeneralAge(for: person, at: photo.dateTaken)
        case .date: return formatDate(photo.dateTaken)
        }
    }

    private func getSubtitleText(for photo: Photo) -> String {
        switch subtitleOption {
        case .none: return ""
        case .name: return person.name
        case .age: return calculateGeneralAge(for: person, at: photo.dateTaken)
        case .date: return formatDate(photo.dateTaken)
        }
    }

    // Timer Methods
    private func startTimer() {
        guard filteredPhotos.count > 1 else { return }
        let interval = 0.016  // Approximately 60 FPS
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            self.scrubberPosition += interval / self.imageDuration
            if self.scrubberPosition >= Double(self.filteredPhotos.count) {
                self.scrubberPosition = 0
            }
            let newPhotoIndex = Int(self.scrubberPosition) % self.filteredPhotos.count
            if newPhotoIndex != self.currentFilteredPhotoIndex {
                withAnimation(
                    self.effectOption == .none
                        ? .none : .easeInOut(duration: self.imageDuration * 0.5)
                ) {
                    self.currentFilteredPhotoIndex = newPhotoIndex
                    self.currentImageId = UUID()
                }
                self.loadImagesAround(index: self.currentFilteredPhotoIndex)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        scrubberPosition = Double(currentFilteredPhotoIndex)
    }

    private func groupAndSortPhotos() -> [(String, [Photo])] {
        return PhotoUtils.groupAndSortPhotos(for: person)
    }

    private var cancelButton: some View {
        Button("Close") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var filteredPhotos: [Photo] {
        switch milestoneMode {
        case .allPhotos:
            return photos.filter { photo in
                if person.pregnancyTracking == .none {
                    let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                    return !age.isPregnancy
                }
                return true
            }
        case .milestones:
            return filterMilestoneStack(
                photos: photos.filter { photo in
                    if person.pregnancyTracking == .none {
                        let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                        return !age.isPregnancy
                    }
                    return true
                })
        }
    }

    private func filterMilestoneStack(photos: [Photo]) -> [Photo] {
        var milestoneStack: [Photo] = []
        var lastMilestone: String?

        for photo in photos {
            let currentMilestone = calculateGeneralAge(for: person, at: photo.dateTaken)
            if currentMilestone != lastMilestone {
                milestoneStack.append(photo)
                lastMilestone = currentMilestone
            }
        }

        return milestoneStack
    }

    private func setupAudioPlayer() {
        guard let musicFileName = selectedMusic else { return }

        print("Attempting to set up audio player for: \(musicFileName)")

        // List all resources in the bundle
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("Bundle contents:")
                for item in items {
                    print(item)
                }
            } catch {
                print("Error listing bundle contents: \(error)")
            }
        }

        // Try to find the file directly in the bundle
        if let path = Bundle.main.path(forResource: musicFileName, ofType: "mp3") {
            createAudioPlayer(with: path)
        } else {
            print("Unable to find \(musicFileName).mp3 in bundle")
            if let resourcePath = Bundle.main.resourcePath {
                let fullPath = (resourcePath as NSString).appendingPathComponent(
                    "\(musicFileName).mp3")
                print("Searched path: \(fullPath)")
            }
        }
    }

    private func createAudioPlayer(with path: String) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.numberOfLoops = -1  // Loop indefinitely
            audioPlayer?.prepareToPlay()
            print("Successfully set up audio player for: \(path)")
        } catch {
            print("Error setting up audio player: \(error.localizedDescription)")
        }
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// LazyImage
struct LazyImage: View {
    let photo: Photo
    let loadedImage: UIImage?
    let aspectRatio: CGFloat
    let showAppIcon: Bool
    let titleText: String
    let subtitleText: String
    let duration: Double
    let isPlaying: Bool
    let effectOption: ShareSlideshowView.EffectOption
    let isActive: Bool

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geometry.size.width, height: geometry.size.width / aspectRatio
                        )
                        .modifier(
                            KenBurnsEffect(
                                isActive: effectOption == .kenBurns && isPlaying, duration: duration
                            )
                        )
                        .clipped()
                } else {
                    ProgressView()
                }

                // Gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.5), Color.black.opacity(0),
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: geometry.size.width / aspectRatio / 3)
                }

                // Title, subtitle, and watermark
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !titleText.isEmpty {
                                Text(titleText)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            if !subtitleText.isEmpty {
                                Text(subtitleText)
                                    .font(.subheadline)
                                    .opacity(0.7)
                            }
                        }

                        Spacer()

                        if showAppIcon {
                            VStack(alignment: .trailing) {
                                Text("Made with")
                                    .font(.system(size: geometry.size.width * 0.04))
                                    .foregroundColor(.white.opacity(0.7))

                                Text("Life Reel")
                                    .font(.system(size: geometry.size.width * 0.05, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .opacity(0.8)
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(effectOption == .none ? 1 : opacity)
            .onAppear {
                if effectOption == .kenBurns {
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.opacity = 1
                    }
                } else {
                    self.opacity = 1
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}

struct KenBurnsEffect: ViewModifier {
    let isActive: Bool
    let duration: Double
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .onAppear(perform: startEffectIfNeeded)
            .onChange(of: isActive) { oldValue, newValue in
                if newValue {
                    startEffect()
                } else {
                    stopEffect()
                }
            }
    }

    private func startEffectIfNeeded() {
        if isActive {
            startEffect()
        }
    }

    private func startEffect() {
        let scales = [1.02, 1.03, 1.04]
        let offsets: [CGSize] = [
            CGSize(width: 5, height: 5),
            CGSize(width: -5, height: -5),
            CGSize(width: 0, height: 5),
            CGSize(width: 5, height: 0),
            CGSize(width: -5, height: 0),
            CGSize(width: 0, height: -5),
        ]

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            self.scale = scales.randomElement() ?? 1.02
            self.offset = offsets.randomElement() ?? .zero
        }
    }

    private func stopEffect() {
        withAnimation(.easeInOut(duration: 0.5)) {
            scale = 1.0
            offset = .zero
        }
    }
}

struct PlayButton: View {
    @Binding var isPlaying: Bool

    var body: some View {
        Button(action: {
            isPlaying.toggle()
        }) {
            Image(systemName: "play.fill")
                .foregroundColor(.white)
                .font(.system(size: 24, weight: .bold))
        }
        .frame(width: 60, height: 60)
        .background(Color.black.opacity(0.5))
        .clipShape(Circle())
    }
}

// Add these new structs outside the main view
struct AspectRatio: Hashable, CustomStringConvertible {
    let value: CGFloat
    let description: String

    static let square = AspectRatio(value: 1.0, description: "Square")
    static let portrait = AspectRatio(value: 9.0 / 16.0, description: "IG Story")
}

struct CustomScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)

                Rectangle()
                    .fill(Color.blue)
                    .frame(width: self.progressWidth(in: geometry), height: 8)
                    .cornerRadius(4)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = self.gestureLocation(value: gesture.location.x, in: geometry)
                        self.value = min(
                            max(newValue, self.range.lowerBound), self.range.upperBound)
                        self.onEditingChanged(true)
                    }
                    .onEnded { _ in
                        isDragging = false
                        self.onEditingChanged(false)
                    }
            )
        }
    }

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(0, geometry.size.width * CGFloat(percent)), geometry.size.width)
    }

    private func gestureLocation(value: CGFloat, in geometry: GeometryProxy) -> Double {
        let percent = Double(max(0, min(value, geometry.size.width)) / geometry.size.width)
        let result = percent * (range.upperBound - range.lowerBound) + range.lowerBound
        return min(max(range.lowerBound, (result / step).rounded() * step), range.upperBound)
    }
}
