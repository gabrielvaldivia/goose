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
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    let person: Person
    @State private var activeSheet: ActiveSheet?
    @State private var activityItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy = CGFloat(1.0)
    @GestureState private var dragOffset: CGSize = .zero
    @State private var showDeleteConfirmation = false
    @State private var dismissProgress: CGFloat = 0.0
    @State private var showActionSheet = false

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
                    .opacity(1 - dismissProgress)
                
                // Photo Display
                if let image = photos[currentIndex].image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(calculateImageOffset(geometry: geometry))
                        .scaleEffect(scale * magnifyBy)
                        .gesture(dragGesture(geometry: geometry))
                        .gesture(magnificationGesture())
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    showActionSheet = true
                                }
                        )
                        .onTapGesture {
                            showControls.toggle()
                        }
                } else {
                    Color.gray
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Controls Overlay
                ControlsOverlay(showControls: showControls, person: person, photo: photos[currentIndex], onClose: {
                    presentationMode.wrappedValue.dismiss()
                }, onShare: {
                    activeSheet = .shareView
                })
                .opacity(1 - dismissProgress)
            }
        }
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
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete this photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(photos[currentIndex])
                    if currentIndex > 0 {
                        currentIndex -= 1
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Photo Options"),
                buttons: [
                    .destructive(Text("Delete Photo")) {
                        showDeleteConfirmation = true
                    },
                    .cancel()
                ]
            )
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
    
    private func calculateImageOffset(geometry: GeometryProxy) -> CGSize {
        let imageSize = CGSize(
            width: geometry.size.width * scale,
            height: geometry.size.height * scale
        )
        let excessWidth = max(0, imageSize.width - geometry.size.width)
        let excessHeight = max(0, imageSize.height - geometry.size.height)

        let newOffsetX = min(max(offset.width + dragOffset.width, -excessWidth / 2), excessWidth / 2)
        let newOffsetY = min(max(offset.height + dragOffset.height, -excessHeight / 2), excessHeight / 2)
        
        return CGSize(width: newOffsetX, height: newOffsetY)
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale > 1.0 {
                    state = CGSize(
                        width: value.translation.width / scale,
                        height: value.translation.height / scale
                    )
                }
                // Update dismissProgress based on drag
                dismissProgress = min(abs(value.translation.height) / 200, 1.0)
            }
            .onEnded { value in
                if abs(value.translation.height) > 100 && scale <= 1.0 {
                    presentationMode.wrappedValue.dismiss()
                } else if scale > 1.0 {
                    let imageSize = CGSize(
                        width: geometry.size.width * scale,
                        height: geometry.size.height * scale
                    )
                    let excessWidth = max(0, imageSize.width - geometry.size.width)
                    let excessHeight = max(0, imageSize.height - geometry.size.height)

                    let scaledTranslation = CGSize(
                        width: value.translation.width / scale,
                        height: value.translation.height / scale
                    )

                    offset.width = min(max(offset.width + scaledTranslation.width, -excessWidth / 2), excessWidth / 2)
                    offset.height = min(max(offset.height + scaledTranslation.height, -excessHeight / 2), excessHeight / 2)
                }
                showControls = true
                // Reset dismissProgress if not dismissing
                withAnimation(.easeOut(duration: 0.2)) {
                    dismissProgress = 0.0
                }
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                scale = min(max(scale * value, 1), 4)
                lastScale = scale
            }
    }
}

struct ControlsOverlay: View {
    let showControls: Bool
    let person: Person
    let photo: Photo
    let onClose: () -> Void
    let onShare: () -> Void

    var body: some View {
        ZStack {
            if showControls {
                VStack(spacing: 0) {
                    // Top gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.3), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .edgesIgnoringSafeArea(.top)

                    Spacer()

                    // Bottom gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.3)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .edgesIgnoringSafeArea(.bottom)
                }

                VStack {
                    // Top Bar with Control Buttons
                    HStack {
                        CircularIconButton(icon: "xmark", action: onClose)
                        Spacer()
                        VStack(spacing: 4) {
                            Text(person.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(calculateAge(for: person, at: photo.dateTaken))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 16)
                        Spacer()
                        CircularIconButton(icon: "square.and.arrow.up", action: onShare)
                    }
                    .padding(.top, 44)
                    .padding(.horizontal, 8)
                    Spacer()
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .animation(.easeInOut, value: showControls)
    }
    
    // Helper functions
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

struct CircularIconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
        }
        .background(
            BlurEffectView()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        )
        .padding(8)
    }
    
    private struct BlurEffectView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}

struct PillButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

        }
        .background(
            BlurEffectView()
                .clipShape(Capsule())
                .padding(.horizontal, -8)
                .padding(.vertical, -4)
        )
    }
    
    private struct BlurEffectView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}