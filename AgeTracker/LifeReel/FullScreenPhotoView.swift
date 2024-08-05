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
    // View Properties
    let photo: Photo
    @State var currentIndex: Int
    let photos: [Photo]
    var onDelete: (Photo) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGSize = .zero
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    let person: Person
    @State private var activeSheet: ActiveSheet?
    @State private var activityItems: [Any] = []
    @State private var isShareSheetPresented = false
    
    enum ActiveSheet: Identifiable {
        case shareView
        case activityView
        
        var id: Int {
            hashValue
        }
    }
    
    var body: some View {
        // Main View Layout
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                // Photo Display
                if let image = photos[currentIndex].image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(offset)
                        .scaleEffect(scale)
                        .gesture(
                            // Drag Gesture
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
                } else {
                    Color.gray
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Controls Overlay
                if showControls {
                    VStack {
                        // Top Bar
                        Text(person.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Spacer()
                        
                        // Bottom Bar
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
                    
                    // Control Buttons
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
                                activeSheet = .shareView
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .padding()
                            }
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
        // Gesture to Toggle Controls
        .gesture(
            DragGesture()
                .onChanged { _ in
                    showControls.toggle()
                }
        )
        // Animation on Appear
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
            }
        }
        // Share Sheet Presentation
        .sheet(item: $activeSheet) { item in
            switch item {
            case .shareView:
                NavigationView {
                    SharePhotoView(
                        image: photos[currentIndex].image ?? UIImage(),
                        name: person.name,
                        age: calculateAge(for: person, at: photos[currentIndex].dateTaken),
                        isShareSheetPresented: $isShareSheetPresented,
                        activityItems: $activityItems
                    )
                }
            case .activityView:
                ActivityViewController(activityItems: activityItems)
                    .onDisappear {
                        self.activeSheet = nil
                    }
            }
        }
    }
    
    // Helper Functions
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