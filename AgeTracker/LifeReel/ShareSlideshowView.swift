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

struct ShareSlideshowView: View {
    let photos: [Photo]
    let person: Person
    @State private var currentPhotoIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0
    @State private var isSharePresented = false
    @State private var loadedImages: [Int: UIImage] = [:]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    LazyImage(photo: photo, loadedImage: loadedImages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.none)

            Text(calculateGeneralAge(for: person, at: photos[currentPhotoIndex].dateTaken))
                .font(.headline)

            Slider(value: Binding(
                get: { Double(currentPhotoIndex) },
                set: { newValue in
                    currentPhotoIndex = Int(newValue)
                    loadImagesAround(index: currentPhotoIndex)
                }
            ), in: 0...Double(photos.count - 1), step: 1)
            .padding(.horizontal)

            PlaybackControls(isPlaying: $isPlaying, playbackSpeed: $playbackSpeed)

            Button("Share") {
                isSharePresented = true
            }
        }
        .onAppear {
            loadImagesAround(index: currentPhotoIndex)
        }
        .sheet(isPresented: $isSharePresented) {
            if let image = photos[currentPhotoIndex].image {
                ActivityViewController(activityItems: [image])
            }
        }
    }
    
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
}

struct LazyImage: View {
    let photo: Photo
    let loadedImage: UIImage?

    var body: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
        }
    }
}