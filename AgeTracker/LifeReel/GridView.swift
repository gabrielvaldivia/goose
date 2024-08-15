//
//  GridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import SwiftUI
import Photos

struct GridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    var openImagePickerForMoment: (String, (Date, Date)) -> Void
    var deletePhoto: (Photo) -> Void
    @State private var orientation = UIDeviceOrientation.unknown
    @State private var isImagePickerPresented = false
    @State private var currentSection: String?
    @State private var currentDateRange: (Date, Date)?

    var body: some View {
        GeometryReader { geometry in
            if person.photos.isEmpty && !person.showEmptyStacks {
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
                    LazyVGrid(columns: gridItems(for: geometry.size), spacing: 20) {
                        ForEach(sortedStacks(), id: \.self) { section in
                            let photos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == section }
                            let itemWidth = gridItemWidth(for: geometry.size)
                            
                            if !photos.isEmpty || person.showEmptyStacks {
                                if photos.isEmpty {
                                    StackTileView(section: section, photos: photos, width: itemWidth, isLoading: viewModel.loadingStacks.contains(section))
                                        .onTapGesture {
                                            do {
                                                let dateRange = try PhotoUtils.getDateRangeForSection(section, person: person)
                                                openImagePickerForMoment(section, dateRange)
                                            } catch {
                                                print("Error getting date range for section \(section): \(error)")
                                            }
                                        }
                                } else {
                                    NavigationLink(destination: StackDetailView(viewModel: viewModel, person: $person, sectionTitle: section)) {
                                        StackTileView(section: section, photos: photos, width: itemWidth, isLoading: false)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 60) 
                }
                .onChange(of: person.photos) { _ in
                    viewModel.loadingStacks.removeAll()
                }
                .onChange(of: viewModel.sortOrder) { _ in
                    viewModel.objectWillChange.send()
                }
            }
        }
        .onChange(of: viewModel.sortOrder) { _ in
            viewModel.objectWillChange.send()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
        .sheet(isPresented: $isImagePickerPresented) {
            if let section = currentSection {
                CustomImagePicker(
                    viewModel: viewModel,
                    person: $person,
                    sectionTitle: section,
                    isPresented: $isImagePickerPresented,
                    onPhotosAdded: { newPhotos in
                        // Handle newly added photos
                        viewModel.updatePerson(person)
                    }
                )
            }
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

    private func gridItems(for size: CGSize) -> [GridItem] {
        let isLandscape = size.width > size.height
        let columnCount = isLandscape ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount)
    }

    private func gridItemWidth(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let columnCount = CGFloat(isLandscape ? 6 : 3)
        let totalSpacing = CGFloat(20 * (Int(columnCount) - 1))
        return (size.width - totalSpacing - 40) / columnCount
    }

    private func deletePhoto(_ photo: Photo) {
        viewModel.deletePhoto(photo, from: &person)
    }

    private func openImagePickerForEmptyState() {
        do {
            let dateRange = try PhotoUtils.getDateRangeForSection("Birth Month", person: person)
            openImagePickerForMoment("Birth Month", dateRange)
        } catch {
            print("Error getting date range for Birth Month: \(error)")
        }
    }
    
    func openImagePickerForMoment(_ section: String, _ dateRange: (Date, Date)) {
        currentSection = section
        currentDateRange = dateRange
        isImagePickerPresented = true
    }
    
    private func photosForCurrentSection() -> [Photo] {
        return person.photos
    }
    
    private func sortedStacks() -> [String] {
        let stacks = PhotoUtils.getAllExpectedStacks(for: person)
        let filteredStacks = person.pregnancyTracking == .none ? stacks.filter { !$0.contains("Pregnancy") && !$0.contains("Trimester") && !$0.contains("Week") } : stacks
        
        return filteredStacks.sorted { stack1, stack2 in
            let order1 = PhotoUtils.orderFromSectionTitle(stack1, sortOrder: viewModel.sortOrder)
            let order2 = PhotoUtils.orderFromSectionTitle(stack2, sortOrder: viewModel.sortOrder)
            return viewModel.sortOrder == .oldestToLatest ? order1 < order2 : order1 > order2
        }
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
                
                if !photos.isEmpty {
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