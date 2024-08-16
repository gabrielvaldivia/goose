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
    @State private var isShareSlideshowPresented = false
    @State private var selectedTab = 1 // 0 for Grid, 1 for Timeline
    @State private var forceUpdate: Bool = false
    @State private var animationDirection: UIPageViewController.NavigationDirection = .forward

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                PageViewController(pages: [
                    AnyView(SharedGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection(), forceUpdate: forceUpdate)),
                    AnyView(SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection(), forceUpdate: forceUpdate))
                ], currentPage: $selectedTab, animationDirection: $animationDirection)
                .edgesIgnoringSafeArea(.bottom)

                VStack(spacing: 0) {
                    Spacer()
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
                        selectedTab: $selectedTab,
                        animationDirection: $animationDirection
                    )
                    // .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.bottom))
                }
            }
        }
        .navigationTitle(sectionTitle)
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

    private func photosForCurrentSection() -> [Photo] {
        let filteredPhotos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == sectionTitle }
        return filteredPhotos.sorted { $0.dateTaken < $1.dateTaken }
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