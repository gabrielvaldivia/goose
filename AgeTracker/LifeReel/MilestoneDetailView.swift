//
//  MilestoneDetailView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import PhotosUI
import SwiftUI

struct MilestoneDetailView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let sectionTitle: String
    @State private var showingImagePicker = false
    @State private var selectedPhoto: Photo? = nil
    @State private var isShareSlideshowPresented = false
    @State private var forceUpdate: Bool = false
    @State private var isLoading = false
    @State private var showingSlideshowSheet = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            if photosToDisplay().isEmpty {
                emptyStateView
            } else {
                GridView(
                    viewModel: viewModel,
                    person: $person,
                    selectedPhoto: $selectedPhoto,
                    sectionTitle: sectionTitle,
                    forceUpdate: forceUpdate,
                    showAge: false
                )
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                CircularButton(
                    systemName: "chevron.left",
                    action: {
                        presentationMode.wrappedValue.dismiss()
                    },
                    size: 32,
                    backgroundColor: Color.gray.opacity(0.2),
                    iconColor: .primary,
                    blurEffect: false,
                    iconSize: nil  // Add this line
                )
            }
            ToolbarItem(placement: .principal) {
                Text(sectionTitle)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if photosToDisplay().count >= 2 {
                        CircularButton(
                            systemName: "square.and.arrow.up",
                            action: {
                                showingSlideshowSheet = true
                            },
                            size: 32,
                            backgroundColor: Color.gray.opacity(0.2),
                            iconColor: .primary,
                            blurEffect: false,
                            iconSize: 11
                        )
                    }
                    CircularButton(
                        systemName: "plus",
                        action: {
                            showingImagePicker = true
                        },
                        size: 32,
                        backgroundColor: Color.gray.opacity(0.2),
                        iconColor: .primary,
                        blurEffect: false,
                        iconSize: nil  // Add this line
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .gesture(
            DragGesture().updating($dragOffset) { value, state, _ in
                if value.startLocation.x < 20 && value.translation.width > 100 {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        )
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
                viewModel: viewModel,
                photo: photo,
                currentIndex: photosToDisplay().firstIndex(of: photo) ?? 0,
                photos: Binding(
                    get: { self.photosToDisplay() },
                    set: { _ in }
                ),
                onDelete: { deletedPhoto in
                    viewModel.deletePhoto(deletedPhoto, from: $person)
                    selectedPhoto = nil
                    viewModel.objectWillChange.send()
                },
                person: $person
            )
        }
        .sheet(isPresented: $isShareSlideshowPresented) {
            ShareSlideshowView(
                photos: photosToDisplay(),
                person: person,
                sectionTitle: sectionTitle
            )
        }
        .sheet(isPresented: $showingSlideshowSheet) {
            ShareSlideshowView(
                photos: photosToDisplay(),
                person: person,
                sectionTitle: sectionTitle,
                forceAllPhotos: true
            )
        }
        .overlay(
            Group {
                if photosToDisplay().count >= 2 {
                    VStack {
                        Spacer()
                        Button(action: {
                            showingSlideshowSheet = true
                        }) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 20))
                                Text("Slideshow")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        }
                    }
                }
            }
        )
    }

    @GestureState private var dragOffset = CGSize.zero

    private func photosToDisplay() -> [Photo] {
        return photosForCurrentSection()
    }

    private func photosForCurrentSection() -> [Photo] {
        let filteredPhotos = person.photos.filter { photo in
            let shouldInclude = PhotoUtils.sectionForPhoto(photo, person: person) == sectionTitle
            if person.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return shouldInclude && !age.isPregnancy
            }
            return shouldInclude
        }
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
    static func placeholderImage(
        color: UIColor = .gray, size: CGSize = CGSize(width: 100, height: 100)
    ) -> UIImage {
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
