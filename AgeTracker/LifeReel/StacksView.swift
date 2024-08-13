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
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(PhotoUtils.sortedGroupedPhotosForAll(person: person, viewModel: viewModel), id: \.0) { section, photos in
                            if !photos.isEmpty {
                                StackSectionView(
                                    section: section,
                                    photos: photos,
                                    selectedPhoto: $selectedPhoto,
                                    person: person,
                                    cardHeight: 300,
                                    maxWidth: geometry.size.width - 30,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Increased bottom padding
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
    
    var body: some View {
        NavigationLink(destination: StackDetailView(
            sectionTitle: section,
            photos: photos,
            onDelete: { _ in },
            person: person,
            viewModel: viewModel
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