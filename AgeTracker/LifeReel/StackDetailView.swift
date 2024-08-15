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
                        SharedGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection())
                            .tag(0)
                        
                        SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: photosForCurrentSection())
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)
                }
            }
            
            bottomControls
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
    }

    private func photosForCurrentSection() -> [Photo] {
        return person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == sectionTitle }
    }

    private var bottomControls: some View {
        HStack {
            shareButton

            Spacer()

            SegmentedControlView(selectedTab: $currentPage, animationDirection: $animationDirection)
                .onChange(of: currentPage) { oldValue, newValue in
                    withAnimation {
                        selectedTab = newValue
                        viewModel.objectWillChange.send()
                    }
                }

            Spacer()

            CircularButton(systemName: "plus") {
                showingImagePicker = true
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var shareButton: some View {
        CircularButton(systemName: "square.and.arrow.up") {
            if !photosForCurrentSection().isEmpty {
                isShareSlideshowPresented = true
            } else {
                print("No photos available to share")
            }
        }
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

struct CircularButton: View {
    let systemName: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                .font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 40)
        }
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Circle())
    }
}

struct SegmentedControlView: View {
    @Binding var selectedTab: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    
    let options = ["square.grid.2x2", "list.bullet"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.15)) {
                        animationDirection = index > selectedTab ? .forward : .reverse
                        selectedTab = index
                    }
                }) {
                    Image(systemName: options[index])
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 60, height: 36)
                        .background(
                            ZStack {
                                if selectedTab == index {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.3))
                                        .matchedGeometryEffect(id: "SelectedSegment", in: animation)
                                }
                            }
                        )
                        .foregroundColor(colorScheme == .dark ? (selectedTab == index ? .white : .white.opacity(0.5)) : (selectedTab == index ? .white : .black.opacity(0.5)))
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Capsule())
    }
}