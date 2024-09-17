//
//  GridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/4/24.
//

import Foundation
import SwiftUI

struct GridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let sectionTitle: String?
    let forceUpdate: Bool
    let showAge: Bool

    @State private var orientation = UIDeviceOrientation.unknown
    @State private var showingImagePicker = false  // Add this line

    private var filteredPhotos: [Photo] {
        guard let sectionTitle = sectionTitle else {
            return person.photos
        }

        return person.photos.filter { photo in
            switch sectionTitle {
            case "All Photos":
                return true
            case "Pregnancy":
                return AgeCalculator.calculate(for: person, at: photo.dateTaken).isPregnancy
            case "Birth Month":
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return age.months == 0 && age.years == 0 && !age.isPregnancy
            default:
                if sectionTitle.hasSuffix("Month") || sectionTitle.hasSuffix("Months") {
                    let targetMonth =
                        Int(
                            sectionTitle.components(
                                separatedBy: CharacterSet.decimalDigits.inverted
                            ).joined()) ?? 0
                    let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                    return age.months == targetMonth && age.years == 0 && !age.isPregnancy
                } else if sectionTitle.hasSuffix("Year") || sectionTitle.hasSuffix("Years") {
                    let targetYear =
                        Int(
                            sectionTitle.components(
                                separatedBy: CharacterSet.decimalDigits.inverted
                            ).joined()) ?? 0
                    let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                    return age.years == targetYear && !age.isPregnancy
                }
                return false
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if filteredPhotos.isEmpty {
                    EmptyStateView(
                        title: "No photos in \(sectionTitle ?? "this section")",
                        subtitle: "Add photos to create memories",
                        systemImageName: "photo.on.rectangle.angled",
                        action: {
                            showingImagePicker = true
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 10) {
                        ForEach(filteredPhotos.sorted(by: { $0.dateTaken > $1.dateTaken }), id: \.id) { photo in
                            let itemWidth = max(1, GridLayoutHelper.gridItemWidth(for: geometry.size))
                            Image(uiImage: photo.image ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: itemWidth, height: itemWidth)
                                .clipped()
                                .cornerRadius(10)
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                        }

                        // Add Photos tile
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                                Image(systemName: "plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: max(1, GridLayoutHelper.gridItemWidth(for: geometry.size)), 
                                   height: max(1, GridLayoutHelper.gridItemWidth(for: geometry.size)))
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .onChange(of: UIDevice.current.orientation) { oldValue, newValue in
            orientation = newValue
        }
        .id(orientation)
        .id(forceUpdate)
        .sheet(isPresented: $showingImagePicker) {
            CustomImagePicker(
                viewModel: viewModel,
                person: $person,
                sectionTitle: sectionTitle ?? "All Photos",
                isPresented: $showingImagePicker,
                onPhotosAdded: { newPhotos in
                    // Handle newly added photos if needed
                }
            )
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
        let totalSpacing = CGFloat(10 * (Int(columnCount) - 1))
        return (size.width - totalSpacing - 20) / columnCount
    }
}
