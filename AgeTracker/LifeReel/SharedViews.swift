//
//  SharedViews.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import PhotosUI

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
                selectedPhoto = photo
            }
    }
}

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
            Image(systemName: "speedometer")
                .foregroundColor(.blue)
                .font(.system(size: 24, weight: .bold))
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