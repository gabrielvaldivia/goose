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
    @State private var selectedTab = 1 // 0 for Grid, 1 for Timeline
    @State private var animationDirection: UIPageViewController.NavigationDirection = .forward
    @State private var isShareSlideshowPresented = false
    @State private var currentPage = 1 // 0 for Grid, 1 for Timeline
    @State private var sortOrder: SortOrder = .latestToOldest
    @State private var forceUpdate: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
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
                    TabView(selection: $currentPage) {
                        SharedGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection(), forceUpdate: forceUpdate)
                            .tag(0)
                        
                        SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection(), forceUpdate: forceUpdate)
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)
                }
            }
            
            BottomControls(
                shareAction: {
                    if !photosForCurrentSection().isEmpty {
                        isShareSlideshowPresented = true
                    } else {
                        print("No photos available to share")
                    }
                },
                addPhotoAction: {
                    showingImagePicker = true
                },
                selectedTab: $currentPage,
                animationDirection: $animationDirection
            )
        }
        .navigationTitle(sectionTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleSortOrder) {
                    Image(systemName: "arrow.up.arrow.down")
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
                    viewModel.objectWillChange.send()
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
                    selectedPhoto = nil
                    viewModel.objectWillChange.send()
                },
                person: person
            )
        }
        .sheet(isPresented: $isShareSlideshowPresented) {
            ShareSlideshowView(
                photos: photosForCurrentSection(),
                person: person,
                sectionTitle: sectionTitle
            )
        }
        .background(Color.clear.opacity(forceUpdate ? 0 : 0.00001))
    }

    private func toggleSortOrder() {
        sortOrder = sortOrder == .latestToOldest ? .oldestToLatest : .latestToOldest
        forceUpdate.toggle()
        viewModel.objectWillChange.send()
    }

    private func photosForCurrentSection() -> [Photo] {
        let filteredPhotos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == sectionTitle }
        return filteredPhotos.sorted { (photo1, photo2) -> Bool in
            sortOrder == .latestToOldest ? photo1.dateTaken > photo2.dateTaken : photo1.dateTaken < photo2.dateTaken
        }
    }
}

enum SortOrder {
    case latestToOldest
    case oldestToLatest
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