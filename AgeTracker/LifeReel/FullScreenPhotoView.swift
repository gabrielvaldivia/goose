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
    @State private var showingShareSheet = false
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []
    @State private var showingPolaroidSheet = false

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
                                showingPolaroidSheet = true
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
        // Polaroid Overlay
        .sheet(isPresented: $showingPolaroidSheet) {
            NavigationView {
                VStack {
                    PolaroidView(
                        image: photos[currentIndex].image ?? UIImage(),
                        name: person.name,
                        age: calculateAge(for: person, at: photos[currentIndex].dateTaken)
                    )
                    .padding()
                    
                    Button(action: sharePhoto) {
                        Text("Share")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .navigationTitle("Pick a share template")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .presentationDetents([.medium])
        // Share Sheet Presentation
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityViewController(activityItems: activityItems)
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
    
    // Share Photo Function
    @MainActor
    private func sharePhoto() {
        let polaroidView = PolaroidView(
            image: photos[currentIndex].image ?? UIImage(),
            name: person.name,
            age: calculateAge(for: person, at: photos[currentIndex].dateTaken)
        )
        
        let renderer = ImageRenderer(content: polaroidView)
        renderer.scale = 3.0 // For better quality
        
        if let uiImage = renderer.uiImage {
            let croppedImage = cropToPolaroid(uiImage)
            let imageToShare = [croppedImage]
            showingPolaroidSheet = false // Close the polaroid overlay
            isShareSheetPresented = true
            activityItems = imageToShare
        }
    }
    
    // Image Cropping Function
    private func cropToPolaroid(_ image: UIImage) -> UIImage {
        let scale = image.scale
        let size = image.size
        let rect = CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        
        let croppedImage = renderer.image { context in
            image.draw(in: rect)
        }
        
        return croppedImage
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct PolaroidView: View {
    let image: UIImage
    let name: String
    let age: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 280)
                .clipped()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                    Text(age)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                }
            .padding(.horizontal, 20)
        }
        .frame(width: 320, height: 380)
        .background(Color.white)
        .cornerRadius(10)
    }
}