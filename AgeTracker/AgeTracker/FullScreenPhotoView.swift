//
//  FullScreenPhotoView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import AVKit

struct FullScreenPhotoView: View {
    let photo: Photo
    var onDelete: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if photo.isVideo, let videoURL = photo.videoURL {
                VideoPlayerView(player: player ?? AVPlayer(url: videoURL))
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player = AVPlayer(url: videoURL)
                        player?.play()
                        setupPlayerLoop()
                    }
            } else if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            }
            
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete this photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func setupPlayerLoop() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { _ in
            player?.seek(to: CMTime.zero)
            player?.play()
        }
    }
}