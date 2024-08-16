//
//  StackGridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/15/24.
//

import Foundation
import SwiftUI

struct StacksGridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    var openImagePickerForMoment: (String, (Date, Date)) -> Void
    let forceUpdate: Bool

    var body: some View {
        GeometryReader { geometry in
            if person.photos.isEmpty {
                EmptyStateView(
                    title: "No photos in grid",
                    subtitle: "Add photos to create stacks",
                    systemImageName: "photo.on.rectangle.angled",
                    action: {
                        openImagePickerForEmptyState()
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ScrollView {
                    LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 20) {
                        ForEach(sortedStacks(), id: \.self) { section in
                            let photos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == section }
                            let itemWidth = GridLayoutHelper.gridItemWidth(for: geometry.size)
                            
                            if !photos.isEmpty || person.showEmptyStacks {
                                NavigationLink(destination: StackDetailView(viewModel: viewModel, person: $person, sectionTitle: section)) {
                                    StackTileView(section: section, photos: photos, width: itemWidth, isLoading: viewModel.loadingStacks.contains(section))
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                currentIndex: person.photos.firstIndex(of: photo) ?? 0,
                photos: person.photos,
                onDelete: { deletedPhoto in
                    viewModel.deletePhoto(deletedPhoto, from: &person)
                    selectedPhoto = nil
                    viewModel.objectWillChange.send()
                },
                person: person
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Force view update on orientation change
            viewModel.objectWillChange.send()
        }
        .id(forceUpdate)
    }

    private func sortedStacks() -> [String] {
        let stacks = PhotoUtils.getAllExpectedStacks(for: person)
        let filteredStacks = person.pregnancyTracking == .none ? stacks.filter { !$0.contains("Pregnancy") && !$0.contains("Trimester") && !$0.contains("Week") } : stacks
        
        return filteredStacks.sorted()
    }

    private func openImagePickerForEmptyState() {
        do {
            let dateRange = try PhotoUtils.getDateRangeForSection("Birth Month", person: person)
            openImagePickerForMoment("Birth Month", dateRange)
        } catch {
            print("Error getting date range for Birth Month: \(error)")
        }
    }
}

struct GridLayoutHelper {
    static func gridItems(for size: CGSize) -> [GridItem] {
        let isLandscape = size.width > size.height
        let columnCount = isLandscape ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount)
    }

    static func gridItemWidth(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let columnCount = CGFloat(isLandscape ? 6 : 3)
        let totalSpacing = CGFloat(20 * (Int(columnCount) - 1))
        return (size.width - totalSpacing - 40) / columnCount
    }
}

struct StackTileView: View {
    let section: String
    let photos: [Photo]
    let width: CGFloat
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let latestPhoto = photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first {
                    Image(uiImage: latestPhoto.image ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: width)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: width, height: width)
                        .cornerRadius(10)
                        .overlay(
                            Group {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 30))
                                }
                            }
                        )
                }
                
                if photos.count >= 2 {
                    Text("\(photos.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                        .padding(4)
                }
            }
            
            Text(section)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: width)
        }
    }
}