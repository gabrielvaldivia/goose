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
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var timer: Timer?
    @State private var scrubberPosition: Double = 0
    @Environment(\.presentationMode) var presentationMode

    // Body
    var body: some View {   
        VStack(alignment: .center, spacing: 10) {
            // Navigation bar
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Text("Share Slideshow")
                    .font(.headline)
                Spacer()
                Button("Share") {
                    isSharePresented = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            // Photo TabView
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZStack(alignment: .bottomLeading) {
                        LazyImage(photo: photo, loadedImage: loadedImages[index])
                        
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(calculateGeneralAge(for: person, at: photos[index].dateTaken))
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(formatDate(photos[index].dateTaken))
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
            Slider(value: $scrubberPosition, in: 0...Double(photos.count - 1), step: 0.01)
                .padding(.horizontal)
                .onChange(of: scrubberPosition) { newValue in
                    if !isPlaying {
                        currentPhotoIndex = Int(newValue.rounded())
                        loadImagesAround(index: currentPhotoIndex)
                    }
                }

            // Playback Controls
            PlaybackControls(isPlaying: $isPlaying, playbackSpeed: $playbackSpeed)

            Spacer()
        }
        // View Modifiers
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            loadImagesAround(index: currentPhotoIndex)
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
        .onChange(of: currentPhotoIndex) { newValue in
            if !isPlaying {
                scrubberPosition = Double(newValue)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let image = photos[currentPhotoIndex].image {
                ActivityViewController(activityItems: [image])
            }
        }
    }
    
    // Helper Methods
    private func loadImagesAround(index: Int) {
        let range = max(0, index - 5)...min(photos.count - 1, index + 5)
        for i in range {
            if loadedImages[i] == nil {
                loadedImages[i] = photos[i].image
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
        let interval = 0.016 // Update at 60fps for smoother animation
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: interval)) {
                scrubberPosition += interval * playbackSpeed
                if scrubberPosition >= Double(photos.count) {
                    scrubberPosition = 0
                }
                let newPhotoIndex = Int(scrubberPosition.rounded())
                if newPhotoIndex != currentPhotoIndex {
                    currentPhotoIndex = newPhotoIndex
                    loadImagesAround(index: currentPhotoIndex)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        scrubberPosition = Double(currentPhotoIndex)
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