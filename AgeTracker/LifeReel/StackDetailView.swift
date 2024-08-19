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
    @State private var isLoading = false

    var body: some View {
        GeometryReader { geometry in
            if photosToDisplay().isEmpty {
                emptyStateView
            } else {
                ZStack(alignment: .bottom) {
                    PageViewController(pages: [
                        AnyView(SharedGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, sectionTitle: sectionTitle)),
                        AnyView(SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, forceUpdate: forceUpdate, sectionTitle: sectionTitle))
                    ], currentPage: $selectedTab, animationDirection: $animationDirection)
                    .edgesIgnoringSafeArea(.bottom)

                    VStack(spacing: 0) {
                        Spacer()
                        BottomControls(
                            shareAction: {
                                isShareSlideshowPresented = true
                            },
                            addPhotoAction: {
                                showingImagePicker = true
                            },
                            selectedTab: $selectedTab,
                            animationDirection: $animationDirection
                        )
                    }
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
                    isLoading = true
                    viewModel.objectWillChange.send()
                    isLoading = false
                }
            )
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                currentIndex: photosToDisplay().firstIndex(of: photo) ?? 0,
                photos: photosToDisplay(),
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
                photos: photosToDisplay(),
                person: person,
                sectionTitle: sectionTitle
            )
        }
    }

    private func photosToDisplay() -> [Photo] {
        return photosForCurrentSection()
    }

    private func photosForCurrentSection() -> [Photo] {
        let filteredPhotos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == sectionTitle }
        return filteredPhotos.sorted { $0.dateTaken < $1.dateTaken }
    }

    private var emptyStateView: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No photos yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Add some photos to see them here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Text("Add Photos")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .padding()
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height * 0.6)
                Spacer()
            }
        }
    }
}

extension UIImage {
    static func placeholderImage(color: UIColor = .gray, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

extension Photo {
    var placeholderImage: UIImage {
        UIImage.placeholderImage()
    }
    
    var displayImage: UIImage {
        image ?? placeholderImage
    }
}