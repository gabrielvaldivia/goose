//
//  StackDetailView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct StackDetailView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let sectionTitle: String
    @State private var showingImagePicker = false
    @State private var selectedPhoto: Photo? = nil

    var body: some View {
        GeometryReader { geometry in
            if photosForCurrentSection().isEmpty {
                EmptyStateView(
                    title: "This stack is empty",
                    subtitle: "Add photos and they'll show up here",
                    systemImageName: "photo.on.rectangle.angled",
                    action: {
                        showingImagePicker = true
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ScrollView {
                    LazyVGrid(columns: gridItems(for: geometry.size), spacing: 10) {
                        ForEach(photosForCurrentSection()) { photo in
                            PhotoTile(photo: photo, size: tileSize(for: geometry.size))
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(sectionTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            CustomImagePicker(
                viewModel: viewModel,
                person: $person,
                sectionTitle: sectionTitle,
                isPresented: $showingImagePicker,
                onPhotosAdded: { newPhotos in
                    // Handle the newly added photos here
                    // For example, you might want to refresh the view
                    // or update some state
                }
            )
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                currentIndex: photosForCurrentSection().firstIndex(of: photo) ?? 0,
                photos: photosForCurrentSection(),
                onDelete: { deletedPhoto in
                    viewModel.deletePhoto(deletedPhoto, from: &person)
                    selectedPhoto = nil  // Close the full screen view
                    // Force view update
                    viewModel.objectWillChange.send()
                },
                person: person
            )
        }
    }

    private func photosForCurrentSection() -> [Photo] {
        return person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == sectionTitle }
    }

    private func gridItems(for size: CGSize) -> [GridItem] {
        let isLandscape = size.width > size.height
        let columnCount = isLandscape ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
    }

    private func tileSize(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let columnCount = CGFloat(isLandscape ? 6 : 3)
        let totalSpacing = CGFloat(10 * (Int(columnCount) - 1))
        return (size.width - totalSpacing - 32) / columnCount // 32 is for the padding (16 on each side)
    }
}

struct PhotoTile: View {
    let photo: Photo
    let size: CGFloat

    var body: some View {
        Image(uiImage: photo.image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
