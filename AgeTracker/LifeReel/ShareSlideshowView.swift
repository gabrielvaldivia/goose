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
    @State private var currentPhotoIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var isSharePresented = false
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var timer: Timer?
    @State private var scrubberPosition: Double = 0
    @Environment(\.presentationMode) var presentationMode
    
    enum SlideshowRange: String, Identifiable {
        case allPhotos = "All Photos"
        case pregnancy = "Pregnancy"
        case newborn = "Newborn"
        case month1 = "1 Month"
        case month2 = "2 Months"
        case month3 = "3 Months"
        case month4 = "4 Months"
        case month5 = "5 Months"
        case month6 = "6 Months"
        case month7 = "7 Months"
        case month8 = "8 Months"
        case month9 = "9 Months"
        case month10 = "10 Months"
        case month11 = "11 Months"
        case year1 = "1 Year"
        case year2 = "2 Years"
        case year3 = "3 Years"
        case year4 = "4 Years"
        case year5 = "5 Years"
        
        var id: String { self.rawValue }
    }
    
    @State private var selectedRange: SlideshowRange = .allPhotos
    @State private var currentFilteredPhotoIndex = 0
    
    private var availableRanges: [SlideshowRange] {
        let groupedPhotos = groupAndSortPhotos()
        var ranges: [SlideshowRange] = []
        
        if photos.count >= 2 { ranges.append(.allPhotos) }
        
        if let pregnancyPhotos = groupedPhotos.first(where: { $0.0 == "Pregnancy" })?.1, pregnancyPhotos.count >= 2 {
            ranges.append(.pregnancy)
        }
        
        if let newbornPhotos = groupedPhotos.first(where: { $0.0 == "Newborn" })?.1, newbornPhotos.count >= 2 {
            ranges.append(.newborn)
        }
        
        for i in 1...11 {
            if let monthPhotos = groupedPhotos.first(where: { $0.0 == "\(i) Month\(i == 1 ? "" : "s")" })?.1, monthPhotos.count >= 2 {
                ranges.append(SlideshowRange(rawValue: "\(i) Month\(i == 1 ? "" : "s")")!)
            }
        }
        
        for i in 1...5 {
            if let yearPhotos = groupedPhotos.first(where: { $0.0 == "\(i) Year\(i == 1 ? "" : "s")" })?.1, yearPhotos.count >= 2 {
                ranges.append(SlideshowRange(rawValue: "\(i) Year\(i == 1 ? "" : "s")")!)
            }
        }
        
        return ranges
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
                            ForEach(availableRanges) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedRange) { _ in
                            currentFilteredPhotoIndex = 0
                            scrubberPosition = 0
                            loadImagesAround(index: currentFilteredPhotoIndex)
                        }
                    }
                }
                Spacer()
                Button("Share") {
                    isSharePresented = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // Photo TabView
            if filteredPhotos.isEmpty {
                Text("No photos available for this range")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                TabView(selection: $currentFilteredPhotoIndex) {
                    ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                        ZStack(alignment: .bottomLeading) {
                            LazyImage(photo: photo, loadedImage: loadedImages[photo.id.uuidString])
                            
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(calculateGeneralAge(for: person, at: photo.dateTaken))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(formatDate(photo.dateTaken))
                                    .font(.subheadline)
                                    .opacity(0.7) 
                            }
                            .padding()
                            .foregroundColor(.white)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.none)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Scrubber
                if filteredPhotos.count > 1 {
                    Slider(value: $scrubberPosition, in: 0...Double(filteredPhotos.count - 1), step: 1)
                        .padding(.horizontal)
                        .onChange(of: scrubberPosition) { newValue in
                            if !isPlaying {
                                currentFilteredPhotoIndex = Int(newValue.rounded())
                                loadImagesAround(index: currentFilteredPhotoIndex)
                            }
                        }
                }

                // Playback Controls
                if filteredPhotos.count > 1 {
                    PlaybackControls(isPlaying: $isPlaying, playbackSpeed: $playbackSpeed)
                }
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            loadImagesAround(index: currentFilteredPhotoIndex)
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onChange(of: playbackSpeed) { _ in
            if isPlaying {
                stopTimer()
                startTimer()
            }
        }
        .onChange(of: currentFilteredPhotoIndex) { newValue in
            if !isPlaying {
                scrubberPosition = Double(newValue)
            }
        }
        .onChange(of: selectedRange) { _ in
            currentFilteredPhotoIndex = 0
            scrubberPosition = 0
            loadImagesAround(index: currentFilteredPhotoIndex)
        }
        .sheet(isPresented: $isSharePresented) {
            if let image = filteredPhotos[currentFilteredPhotoIndex].image {
                ActivityViewController(activityItems: [image])
            }
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
                    return "Newborn"
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
    
    // Timer Methods
    private func startTimer() {
        guard filteredPhotos.count > 1 else { return }
        let interval = 0.016 // Update at 60fps for smoother animation
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
    
    private var filteredPhotos: [Photo] {
        let groupedPhotos = groupAndSortPhotos()
        switch selectedRange {
        case .allPhotos:
            return photos
        case .pregnancy:
            return groupedPhotos.first { $0.0 == "Pregnancy" }?.1 ?? []
        case .newborn:
            return groupedPhotos.first { $0.0 == "Newborn" }?.1 ?? []
        case .month1, .month2, .month3, .month4, .month5, .month6, .month7, .month8, .month9, .month10, .month11:
            let monthNumber = Int(selectedRange.rawValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            return groupedPhotos.first { $0.0 == "\(monthNumber) Month\(monthNumber == 1 ? "" : "s")" }?.1 ?? []
        case .year1, .year2, .year3, .year4, .year5:
            let yearNumber = Int(selectedRange.rawValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
            return groupedPhotos.first { $0.0 == "\(yearNumber) Year\(yearNumber == 1 ? "" : "s")" }?.1 ?? []
        }
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
                    sectionTitle = "Newborn"
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

    var body: some View {
        GeometryReader { geometry in
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ProgressView()
                    .frame(width: geometry.size.width, height: geometry.size.width)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// PlaybackControls
struct PlaybackControls: View {
    @Binding var isPlaying: Bool
    @Binding var playbackSpeed: Double
    
    var body: some View {
        HStack(spacing: 40) {
            SpeedControlButton(playbackSpeed: $playbackSpeed)
            
            PlayButton(isPlaying: $isPlaying)
            
            VolumeButton()
        }
        .frame(height: 40)
    }
}

struct SpeedControlButton: View {
    @Binding var playbackSpeed: Double
    
    var body: some View {
        Button(action: {
            playbackSpeed = playbackSpeed == 1.0 ? 2.0 : playbackSpeed == 2.0 ? 3.0 : 1.0
        }) {
            Text("\(Int(playbackSpeed))x")
                .foregroundColor(.blue)
                .font(.system(size: 18, weight: .bold))
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
                .font(.system(size: 24, weight: .bold))
        }
    }
}

struct VolumeButton: View {
    var body: some View {
        Button(action: {
            // Volume control logic
        }) {
            Image(systemName: "speaker.wave.2")
                .foregroundColor(.blue)
                .font(.system(size: 24, weight: .bold))
        }
    }
}