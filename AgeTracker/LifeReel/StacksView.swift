//
//  StacksView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation
import SwiftUI

struct StacksView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    var openImagePickerForMoment: (String, (Date, Date)) -> Void
    @State var showingImagePicker = false
    
    private var stacks: [String] {
        return PhotoUtils.getAllExpectedStacks(for: person)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if stacks.isEmpty || person.photos.isEmpty {
                EmptyStateView(
                    title: "No photos in stacks",
                    subtitle: "Add photos to create stacks",
                    systemImageName: "photo.on.rectangle.angled",
                    action: {
                        showingImagePicker = true
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(stacks, id: \.self) { stack in
                            let photos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == stack }
                            if !photos.isEmpty {
                                StackSectionView(
                                    section: stack,
                                    photos: photos,
                                    selectedPhoto: $selectedPhoto,
                                    person: person,
                                    cardHeight: 300,
                                    maxWidth: geometry.size.width - 30,
                                    viewModel: viewModel,
                                    openImagePickerForMoment: openImagePickerForMoment
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
    }
}

struct StackSectionView: View {
    let section: String
    let photos: [Photo]
    @Binding var selectedPhoto: Photo?
    let person: Person
    let cardHeight: CGFloat
    let maxWidth: CGFloat
    @ObservedObject var viewModel: PersonViewModel
    var openImagePickerForMoment: (String, (Date, Date)) -> Void
    
    var body: some View {
        NavigationLink(destination: StackDetailView(
            sectionTitle: section,
            photos: photos,
            onDelete: { _ in },
            person: person,
            viewModel: viewModel,
            openImagePickerForMoment: openImagePickerForMoment
        )) {
            if let randomPhoto = photos.randomElement() {
                ZStack(alignment: .bottom) {
                    if let image = randomPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .clipped()
                            .cornerRadius(20)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .cornerRadius(20)
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight / 3)
                    .frame(maxWidth: maxWidth)
                    .cornerRadius(20)
                    
                    HStack {
                        HStack(spacing: 8) {
                            Text(section)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            } else {
                Text("No photos available")
                    .italic()
                    .foregroundColor(.gray)
                    .frame(height: cardHeight)
                    .frame(maxWidth: maxWidth)
            }
        }
    }
}