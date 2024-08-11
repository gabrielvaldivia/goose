//
//  ShareSlideshowView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import AVKit
import Photos

// ShareSlideshowView
struct ShareSlideshowView: View {
    // Properties
    let photos: [Photo]
    let person: Person
    let sectionTitle: String
    @State private var currentPhotoIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var isSharePresented = false
    @State private var showComingSoonAlert = false
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var timer: Timer?
    @State private var scrubberPosition: Double = 0
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedRange: SlideshowRange
    @State private var currentFilteredPhotoIndex = 0
    @State private var aspectRatio: AspectRatio = .square
    @State private var isMusicSelectionPresented = false
    @State private var showAppIcon: Bool = true
    @State private var titleOption: TitleOption = .name
    @State private var subtitleOption: TitleOption = .age
    @State private var speedOptions = [1.0, 2.0, 3.0]
    
    init(photos: [Photo], person: Person, sectionTitle: String) {
        self.photos = photos
        self.person = person
        self.sectionTitle = sectionTitle
        let initialRange = SlideshowRange.allCases.first { $0.displayName == sectionTitle } ?? .allPhotos
        _selectedRange = State(initialValue: initialRange)
    }
    
    enum SlideshowRange: Hashable, CaseIterable {
        case allPhotos
        case pregnancy
        case birthMonth
        case month(Int)
        case year(Int)

        var displayName: String {
            switch self {
            case .allPhotos: return "All Photos"
            case .pregnancy: return "Pregnancy"
            case .birthMonth: return "Birth Month"
            case .month(let value): return "\(value) Month\(value == 1 ? "" : "s")"
            case .year(let value): return "\(value) Year\(value == 1 ? "" : "s")"
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
            default:
                return false
            }
        }
    }
    
    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        
        var description: String { self.rawValue }
    }
    
    private var availableRanges: [SlideshowRange] {
        let groupedPhotos = groupAndSortPhotos()
        return SlideshowRange.allCases.filter { range in
            switch range {
            case .allPhotos:
                return !photos.isEmpty
            case .pregnancy:
                return groupedPhotos.contains { $0.0 == "Pregnancy" }
            case .birthMonth:
                return groupedPhotos.contains { $0.0 == "Birth Month" }
            case .month(let value):
                return groupedPhotos.contains { $0.0 == "\(value) Month\(value == 1 ? "" : "s")" }
            case .year(let value):
                return groupedPhotos.contains { $0.0 == "\(value) Year\(value == 1 ? "" : "s")" }
            }
        }
    }
    
    private var filteredPhotos: [Photo] {
        switch selectedRange {
        case .allPhotos:
            return photos
        case .pregnancy:
            return photos.filter { $0.dateTaken < person.dateOfBirth }
        case .birthMonth:
            return photos.filter { photo in
                let age = AgeCalculator.calculateAge(for: person, at: photo.dateTaken)
                return age.years == 0 && age.months == 0
            }
        case .month(let month):
            return photos.filter { photo in
                let age = AgeCalculator.calculateAge(for: person, at: photo.dateTaken)
                return age.years == 0 && age.months == month
            }
        case .year(let year):
            return photos.filter { photo in
                let age = AgeCalculator.calculateAge(for: person, at: photo.dateTaken)
                return age.years == year - 1
            }
        }
    }
    
    // Body
    var body: some View {   
        VStack(alignment: .center, spacing: 10) {
            // Navigation bar
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                if !availableRanges.isEmpty {
                    VStack {
                        Picker("Range", selection: $selectedRange) {
                            ForEach(availableRanges, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedRange) { oldValue, newValue in
                            currentFilteredPhotoIndex = 0
                            scrubberPosition = 0
                            loadImagesAround(index: currentFilteredPhotoIndex)
                        }
                    }
                }
                Spacer()
                Button("Share") {
                    showComingSoonAlert = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // Single Photo View (replacing TabView)
            if filteredPhotos.isEmpty {
                Text("No photos available for this range")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Spacer()
                LazyImage(
                    photo: filteredPhotos[currentFilteredPhotoIndex],
                    loadedImage: loadedImages[filteredPhotos[currentFilteredPhotoIndex].id.uuidString],
                    aspectRatio: aspectRatio.value,
                    showAppIcon: showAppIcon,
                    titleText: getTitleText(for: filteredPhotos[currentFilteredPhotoIndex]),
                    subtitleText: getSubtitleText(for: filteredPhotos[currentFilteredPhotoIndex])
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
                
                // Playback Controls
                if filteredPhotos.count > 1 {
                    HStack(spacing: 20) {
                        PlayButton(isPlaying: $isPlaying)
                            .frame(width: 40, height: 40)
                        
                        Slider(value: $scrubberPosition, in: 0...Double(filteredPhotos.count - 1), step: 1)
                            .onChange(of: scrubberPosition) { oldValue, newValue in
                                if !isPlaying {
                                    currentFilteredPhotoIndex = Int(newValue.rounded())
                                    loadImagesAround(index: currentFilteredPhotoIndex)
                                }
                            }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 40)
                }

                Spacer()

                // Bottom controls section
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
                            options: TitleOption.allCases.filter { $0 != titleOption || $0 == .none },
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
                        
                        // App Icon toggle
                        VStack(spacing: 8) {
                            Button(action: { showAppIcon.toggle() }) {
                                VStack(spacing: 8) {
                                    Image(systemName: showAppIcon ? "app.badge.checkmark" : "app")
                                        .font(.system(size: 24))
                                        .frame(height: 24)
                                    Text("App Icon")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(width: 70) // Match the width of other buttons
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            loadImagesAround(index: currentFilteredPhotoIndex)
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onChange(of: playbackSpeed) { oldValue, newValue in
            if isPlaying {
                stopTimer()
                startTimer()
            }
        }
        .onChange(of: currentFilteredPhotoIndex) { oldValue, newValue in
            if !isPlaying {
                scrubberPosition = Double(newValue)
            }
        }
        .onChange(of: selectedRange) { oldValue, newValue in
            currentFilteredPhotoIndex = 0
            scrubberPosition = 0
            loadImagesAround(index: currentFilteredPhotoIndex)
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sharing functionality will be available in a future update.")
        }
        .sheet(isPresented: $isMusicSelectionPresented) {
            MusicSelectionView()
        }
    }
    
    // Helper Methods
    private func loadImagesAround(index: Int) {
        let range = max(0, index - 5)...min(filteredPhotos.count - 1, index + 5)
        for i in range {
            let photo = filteredPhotos[i]
            if loadedImages[photo.id.uuidString] == nil {
                loadedImages[photo.id.uuidString] = photo.image
            }
        }
    }
    
    private func calculateGeneralAge(for person: Person, at date: Date) -> String {
        if date < person.dateOfBirth {
            return "Pregnancy"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: date)
        
        if let year = components.year, let month = components.month {
            if year == 0 {
                if month == 0 {
                    return "Birth Month"
                } else {
                    return "\(month) month\(month == 1 ? "" : "s")"
                }
            } else {
                return "\(year) year\(year == 1 ? "" : "s")"
            }
        }
        
        return "Unknown"
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
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: interval)) {
                scrubberPosition += interval * playbackSpeed
                if scrubberPosition >= Double(filteredPhotos.count) {
                    scrubberPosition = 0
                }
                let newPhotoIndex = Int(scrubberPosition.rounded())
                if newPhotoIndex != currentFilteredPhotoIndex {
                    currentFilteredPhotoIndex = newPhotoIndex
                    loadImagesAround(index: currentFilteredPhotoIndex)
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
        let calendar = Calendar.current
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in photos {
            let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if photo.dateTaken >= person.dateOfBirth {
                if years == 0 && months == 0 {
                    sectionTitle = "Birth Month"
                } else if years == 0 {
                    sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                } else {
                    sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                }
            } else {
                sectionTitle = "Pregnancy"
            }

            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        return groupedPhotos.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
                        .clipped()
                } else {
                    ProgressView()
                }
                
                VStack {
                    Spacer()
                    HStack {
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
                        .padding()
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        if showAppIcon {
                            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.vertical, 8)
                                .padding(.trailing, 16)
                        }
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width / aspectRatio)
            .background(Color.black.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
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

