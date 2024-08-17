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
    @State private var isMusicSelectionPresented = false
    @State private var showAppIcon: Bool = true
    @State private var titleOption: TitleOption = .name
    @State private var subtitleOption: TitleOption = .age
    @State private var speedOptions = [1.0, 2.0, 3.0]
    
    init(photos: [Photo], person: Person, sectionTitle: String? = nil) {
        self.photos = photos
        self.person = person
        self.sectionTitle = sectionTitle
        
        // Subtitle option always defaults to age
        _subtitleOption = State(initialValue: .age)
    }
    
    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        
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
                playbackControls
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
        .sheet(isPresented: $isMusicSelectionPresented) {
            MusicSelectionView()
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
            if !photos.isEmpty {
                let safeIndex = min(currentFilteredPhotoIndex, filteredPhotos.count - 1)
                if safeIndex >= 0 && safeIndex < filteredPhotos.count {
                    LazyImage(
                        photo: filteredPhotos[safeIndex],
                        loadedImage: loadedImages[filteredPhotos[safeIndex].id.uuidString] ?? UIImage(),
                        aspectRatio: aspectRatio.value,
                        showAppIcon: showAppIcon,
                        titleText: getTitleText(for: filteredPhotos[safeIndex]),
                        subtitleText: getSubtitleText(for: filteredPhotos[safeIndex])
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
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

    private var playbackControls: some View {
        Group {
            if filteredPhotos.count > 1 {
                HStack(spacing: 20) {
                    PlayButton(isPlaying: $isPlaying)
                        .frame(width: 40, height: 40)
                    
                    CustomScrubber(
                        value: $scrubberPosition,
                        range: 0...Double(filteredPhotos.count - 1),
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing {
                                currentFilteredPhotoIndex = Int(scrubberPosition.rounded())
                                loadImagesAround(index: currentFilteredPhotoIndex)
                            }
                        }
                    )
                    .frame(height: 40)
                    
                    Spacer(minLength: 20) // Add extra space to the right
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            Divider()
            
            HStack(spacing: 20) {
                SimplifiedCustomizationButton(
                    icon: "textformat",
                    title: "Title",
                    options: TitleOption.allCases,
                    selection: $titleOption
                )
                
                SimplifiedCustomizationButton(
                    icon: "text.alignleft",
                    title: "Subtitle",
                    options: TitleOption.allCases,
                    selection: $subtitleOption
                )
                
                SimplifiedCustomizationButton(
                    icon: "aspectratio",
                    title: "Aspect Ratio",
                    options: [AspectRatio.square, AspectRatio.portrait],
                    selection: $aspectRatio
                )
                
                SimplifiedCustomizationButton(
                    icon: "speedometer",
                    title: "Speed",
                    options: speedOptions.map { "\(Int($0))x" },
                    selection: Binding(
                        get: { "\(Int(self.playbackSpeed))x" },
                        set: { newValue in
                            if let speed = Double(newValue.dropLast()) {
                                self.playbackSpeed = speed
                            }
                        }
                    )
                )
                
                Button(action: { showAppIcon.toggle() }) {
                    VStack(spacing: 8) {
                        Image(systemName: showAppIcon ? "checkmark.seal.fill" : "checkmark.seal")
                            .font(.system(size: 24))
                            .frame(height: 24)
                        Text("Watermark")
                            .font(.caption)
                    }
                    .frame(width: 70)
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 10)
        .frame(height: 80)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func onAppear() {
        loadImagesAround(index: currentFilteredPhotoIndex)
        startTimer()
    }

    private func handlePlayingChange(oldValue: Bool, newValue: Bool) {
        if newValue {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func handleSpeedChange(oldValue: Double, newValue: Double) {
        if isPlaying {
            stopTimer()
            startTimer()
        }
    }

    private func handleIndexChange(oldValue: Int, newValue: Int) {
        if !isPlaying {
            scrubberPosition = Double(newValue)
        }
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
        let interval = 0.016
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            withAnimation(.linear(duration: interval)) {
                self.scrubberPosition += interval * self.playbackSpeed
                if self.scrubberPosition >= Double(self.filteredPhotos.count) {
                    self.scrubberPosition = 0
                }
                let newPhotoIndex = Int(self.scrubberPosition) % max(1, self.filteredPhotos.count)
                if newPhotoIndex != self.currentFilteredPhotoIndex {
                    self.currentFilteredPhotoIndex = newPhotoIndex
                    self.loadImagesAround(index: self.currentFilteredPhotoIndex)
                }
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
        Button("Cancel") {
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
}

// LazyImage
struct LazyImage: View {
    let photo: Photo
    let loadedImage: UIImage?
    let aspectRatio: CGFloat
    let showAppIcon: Bool
    let titleText: String
    let subtitleText: String

    @State private var faceRect: CGRect?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
                        .clipShape(Rectangle())
                        .overlay(
                            GeometryReader { imageGeometry in
                                Color.clear.onAppear {
                                    self.detectFace(in: image, size: imageGeometry.size)
                                }
                            }
                        )
                        .position(faceAwarePosition(in: geometry))
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
                                    .font(.system(size: geometry.size.width * 0.03))
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
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func detectFace(in image: UIImage, size: CGSize) {
        guard let ciImage = CIImage(image: image) else { return }

        let context = CIContext()
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)

        let faces = faceDetector?.features(in: ciImage, options: [CIDetectorSmile: true, CIDetectorEyeBlink: true])

        if let face = faces?.first as? CIFaceFeature {
            let faceRect = face.bounds
            let scaledRect = CGRect(
                x: faceRect.origin.x / ciImage.extent.width * size.width,
                y: (1 - (faceRect.origin.y + faceRect.height) / ciImage.extent.height) * size.height,
                width: faceRect.width / ciImage.extent.width * size.width,
                height: faceRect.height / ciImage.extent.height * size.height
            )
            self.faceRect = scaledRect
        }
    }

    private func faceAwarePosition(in geometry: GeometryProxy) -> CGPoint {
        guard let faceRect = faceRect else {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }

        let faceCenter = CGPoint(x: faceRect.midX, y: faceRect.midY)
        let imageCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

        let xOffset = min(max(faceCenter.x - imageCenter.x, -geometry.size.width / 4), geometry.size.width / 4)
        let yOffset = min(max(faceCenter.y - imageCenter.y, -geometry.size.height / 4), geometry.size.height / 4)

        return CGPoint(x: imageCenter.x - xOffset, y: imageCenter.y - yOffset)
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

struct MusicSelectionView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Text("Music Selection Coming Soon")
                .navigationTitle("Select Music")
                .navigationBarItems(trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                })
        }
    }
}

// Add these new structs outside the main view
struct AspectRatio: Hashable, CustomStringConvertible {
    let value: CGFloat
    let description: String
    
    static let square = AspectRatio(value: 1.0, description: "Square")
    static let portrait = AspectRatio(value: 9.0/16.0, description: "9:16")
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
        return geometry.size.width * CGFloat(percent)
    }

    private func gestureLocation(value: CGFloat, in geometry: GeometryProxy) -> Double {
        let percent = Double(value / geometry.size.width)
        let result = percent * (range.upperBound - range.lowerBound) + range.lowerBound
        return (result / step).rounded() * step
    }
}

