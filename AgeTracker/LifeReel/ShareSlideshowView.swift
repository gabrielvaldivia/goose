//
//  ShareSlideshowView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import Photos
import Vision
import AVFoundation

enum SlideshowRange: Hashable, CaseIterable {
    case allPhotos
    case pregnancy
    case birthMonth
    case month(Int)
    case year(Int)
    case custom(String)

    var displayName: String {
        switch self {
        case .allPhotos:
            return "All Photos"
        case .pregnancy:
            return "Pregnancy"
        case .birthMonth:
            return "Birth Month"
        case .month(let value):
            return "\(value) Month\(value == 1 ? "" : "s")"
        case .year(let value):
            return "\(value) Year\(value == 1 ? "" : "s")"
        case .custom(let value):
            return value
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

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPhotos:
            hasher.combine(0)
        case .pregnancy:
            hasher.combine(1)
        case .birthMonth:
            hasher.combine(2)
        case .month(let value):
            hasher.combine(3)
            hasher.combine(value)
        case .year(let value):
            hasher.combine(4)
            hasher.combine(value)
        case .custom(let value):
            hasher.combine(5)
            hasher.combine(value)
        }
    }

    static func == (lhs: SlideshowRange, rhs: SlideshowRange) -> Bool {
        switch (lhs, rhs) {
        case (.allPhotos, .allPhotos),
             (.pregnancy, .pregnancy),
             (.birthMonth, .birthMonth):
            return true
        case let (.month(lhsValue), .month(rhsValue)):
            return lhsValue == rhsValue
        case let (.year(lhsValue), .year(rhsValue)):
            return lhsValue == rhsValue
        case let (.custom(lhsValue), .custom(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
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
    @State private var baseImageDuration: Double = 3.0 // Base duration for each image
    @State private var imageDuration: Double = 3.0 // Actual duration, affected by speed
    @State private var effectOption: EffectOption = .kenBurns
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var selectedMusic: String?
    
    private let availableMusic = ["Serenity", "Echoes", "Sunshine", "Whispers"]
    
    init(photos: [Photo], person: Person, sectionTitle: String? = nil) {
        self.photos = photos
        self.person = person
        self.sectionTitle = sectionTitle
        
        // Subtitle option always defaults to age
        _subtitleOption = State(initialValue: .age)
        
        // Randomly select a song
        _selectedMusic = State(initialValue: availableMusic.randomElement())
        
        // Ensure isPlaying is true by default
        _isPlaying = State(initialValue: true)
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
    
    // Body
    var body: some View {   
        VStack(alignment: .center, spacing: 10) {
            navigationBar
            
            if filteredPhotos.isEmpty {
                emptyStateView
            } else {
                photoView
                bottomControls
            }
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
    }
    
    private var navigationBar: some View {
        HStack {
            cancelButton
            Spacer()
            Text("Slideshow")
                .font(.headline)
            Spacer()
            shareButton
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
                            loadedImage: loadedImages[filteredPhotos[safeIndex].id.uuidString] ?? UIImage(),
                            aspectRatio: aspectRatio.value,
                            showAppIcon: showAppIcon,
                            titleText: getTitleText(for: filteredPhotos[safeIndex]),
                            subtitleText: getSubtitleText(for: filteredPhotos[safeIndex]),
                            duration: imageDuration,
                            isPlaying: isPlaying,
                            effectOption: effectOption
                        )
                        .id(currentImageId)
                        .transition(effectOption == .none ? .identity : .opacity)
                        
                        if !isPlaying {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
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
                        selection: Binding(
                            get: { self.selectedMusic ?? "None" },
                            set: { newValue in
                                self.stopAudio() // Stop current audio
                                if newValue == "None" {
                                    self.selectedMusic = nil
                                } else {
                                    self.selectedMusic = newValue
                                    self.setupAudioPlayer()
                                    if self.isPlaying {
                                        self.audioPlayer?.play()
                                    }
                                }
                            }
                        )
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
                                    self.handleSpeedChange(oldValue: self.playbackSpeed, newValue: speed)
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
                    
                    // Watermark
                    Button(action: { showAppIcon.toggle() }) {
                        VStack(spacing: 6) {
                            Image(systemName: showAppIcon ? "checkmark.seal.fill" : "checkmark.seal")
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
        .frame(height: 100)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func onAppear() {
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
        Button("OK", role: .cancel) { }
    }

    // Helper Methods
    private func loadImagesAround(index: Int) {
        let photos = filteredPhotos
        guard !photos.isEmpty else { return }
        let count = photos.count
        let safeIndex = (index + count) % count
        let range = (-5...5).map { (safeIndex + $0 + count) % count }
        for i in range {
            let photo = photos[i]
            if loadedImages[photo.id.uuidString] == nil {
                loadedImages[photo.id.uuidString] = photo.image
            }
        }
    }
    
    private func calculateGeneralAge(for person: Person, at date: Date) -> String {
        let exactAge = AgeCalculator.calculate(for: person, at: date)
        
        if exactAge.isNewborn || (exactAge.years == 0 && exactAge.months == 0) {
            return "Birth Month"
        } else if exactAge.isPregnancy {
            return "Pregnancy"
        } else if exactAge.years == 0 {
            return "\(exactAge.months) month\(exactAge.months == 1 ? "" : "s")"
        } else {
            return "\(exactAge.years) year\(exactAge.years == 1 ? "" : "s")"
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
        let interval = 0.016 // Approximately 60 FPS
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            self.scrubberPosition += interval / self.imageDuration
            if self.scrubberPosition >= Double(self.filteredPhotos.count) {
                self.scrubberPosition = 0
            }
            let newPhotoIndex = Int(self.scrubberPosition) % max(1, self.filteredPhotos.count)
            if newPhotoIndex != self.currentFilteredPhotoIndex {
                withAnimation(self.effectOption == .none ? .none : .easeInOut(duration: self.imageDuration * 0.5)) {
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

    private var shareButton: some View {
        Button("Share") {
            showComingSoonAlert = true
        }
    }

    private var filteredPhotos: [Photo] {
        if person.pregnancyTracking == .none {
            return photos.filter { photo in
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return !age.isPregnancy
            }
        }
        return photos
    }

    private func setupAudioPlayer() {
        guard let musicFileName = selectedMusic else { return }
        
        guard let path = Bundle.main.path(forResource: musicFileName, ofType: "mp3") else {
            print("Unable to find \(musicFileName).mp3 in bundle")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.prepareToPlay()
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
                        .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
                        .scaleEffect(effectOption == .kenBurns ? scale : 1.0)
                        .offset(effectOption == .kenBurns ? offset : .zero)
                        .clipped()
                } else {
                    ProgressView()
                }
                
                // Gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
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
                                
                                Text("LifeReel.app")
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
                    self.startKenBurnsEffect()
                } else {
                    self.opacity = 1
                }
            }
            .onChange(of: isPlaying) { oldValue, newValue in
                if newValue && effectOption == .kenBurns {
                    self.startKenBurnsEffect()
                } else {
                    self.stopKenBurnsEffect()
                }
            }
            .onChange(of: effectOption) { oldValue, newValue in
                if newValue == .kenBurns && isPlaying {
                    self.startKenBurnsEffect()
                } else {
                    self.stopKenBurnsEffect()
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func startKenBurnsEffect() {
        let scales = [1.02, 1.03, 1.04]
        let offsets: [CGSize] = [
            CGSize(width: 5, height: 5),
            CGSize(width: -5, height: -5),
            CGSize(width: 0, height: 5),
            CGSize(width: 5, height: 0),
            CGSize(width: -5, height: 0),
            CGSize(width: 0, height: -5)
        ]
        
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            self.scale = scales.randomElement() ?? 1.02
            self.offset = offsets.randomElement() ?? .zero
        }
    }

    private func stopKenBurnsEffect() {
        withAnimation(.easeInOut(duration: 0.5)) {
            self.scale = 1.0
            self.offset = .zero
        }
    }
}

struct PlayButton: View {
    @Binding var isPlaying: Bool
    
    var body: some View {
        Button(action: {
            isPlaying.toggle()
        }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .foregroundColor(.blue)
                .font(.system(size: 18, weight: .bold))
        }
        .frame(width: 40, height: 40)
        .background(Color.clear)
        .clipShape(Circle())
    }
}

// Add these new structs outside the main view
struct AspectRatio: Hashable, CustomStringConvertible {
    let value: CGFloat
    let description: String
    
    static let square = AspectRatio(value: 1.0, description: "Square")
    static let portrait = AspectRatio(value: 9.0/16.0, description: "IG Story")
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
                        self.value = min(max(newValue, self.range.lowerBound), self.range.upperBound)
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

