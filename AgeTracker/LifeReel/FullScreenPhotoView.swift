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
    @State var currentIndex: Int
    let photos: [Photo]
    var onDelete: (Photo) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGSize = .zero
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    let person: Person

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                AsyncImage(url: URL(fileURLWithPath: Photo.getDocumentsDirectory().appendingPathComponent(photos[currentIndex].fileName).path)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(offset)
                            .scaleEffect(scale)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation
                                        showControls = false
                                    }
                                    .onEnded { value in
                                        if abs(value.translation.height) > 100 {
                                            presentationMode.wrappedValue.dismiss()
                                        } else {
                                            withAnimation { offset = .zero }
                                        }
                                        showControls = true
                                    }
                            )
                    case .failure(_):
                        Color.gray
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                
                if showControls {
                    VStack {
                        // Name at the top
                        Text(person.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Spacer()
                        
                        // Age and date at the bottom
                        VStack {
                            Text(calculateAge(for: person, at: photos[currentIndex].dateTaken))
                                .font(.body)
                                .foregroundColor(.white)
                            Text(formatDate(photos[currentIndex].dateTaken))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    
                    // Controls overlay
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
                                onDelete(photos[currentIndex])
                                if currentIndex > 0 {
                                    currentIndex -= 1
                                } else {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { _ in
                    showControls.toggle()
                }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
            }
        }
    }
    
    private func calculateAge(for person: Person, at date: Date) -> String {
        return AgeCalculator.calculateAgeString(for: person, at: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}