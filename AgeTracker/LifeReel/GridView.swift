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
    @State private var loadingStacks: Set<String> = []

    private var stacks: [String] {
        return PhotoUtils.getGeneralAgeStacks(for: person)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                    ForEach(stacks, id: \.self) { section in
                        let photos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == section }
                        let itemWidth = (geometry.size.width - 40) / 2
                        
                        if photos.isEmpty {
                            StackTileView(section: section, photos: photos, width: itemWidth, isLoading: loadingStacks.contains(section))
                                .onTapGesture {
                                    do {
                                        let dateRange = try PhotoUtils.getDateRangeForSection(section, person: person)
                                        loadingStacks.insert(section)
                                        openImagePickerForMoment(section, dateRange)
                                    } catch {
                                        print("Error getting date range for section \(section): \(error)")
                                    }
                                }
                        } else {
                            NavigationLink(destination: StackDetailView(sectionTitle: section, photos: photos, onDelete: deletePhoto, person: person, viewModel: viewModel, openImagePickerForMoment: openImagePickerForMoment)) {
                                StackTileView(section: section, photos: photos, width: itemWidth, isLoading: false)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func deletePhoto(_ photo: Photo) {
        viewModel.deletePhoto(photo, from: &person)
    }
}

struct StackTileView: View {
    let section: String
    let photos: [Photo]
    let width: CGFloat
    let isLoading: Bool
    
    var body: some View {
        VStack {
            if let photo = photos.randomElement() {
                Image(uiImage: photo.image ?? UIImage())
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
            
            Text(section)
                .font(.caption)
                .lineLimit(1)
            
            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}