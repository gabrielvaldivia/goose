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

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let filteredPhotos = person.photos.filter { photo in
                    PhotoUtils.sectionForPhoto(photo, person: person) == sectionTitle
                }

                if filteredPhotos.isEmpty {
                    EmptyStateView(
                        title: "No photos in grid",
                        subtitle: "Add photos to create memories",
                        systemImageName: "photo.on.rectangle.angled",
                        action: {
                            // Implement photo picker action here
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 10)
                    {
                        ForEach(
                            filteredPhotos.sorted(by: { $0.dateTaken > $1.dateTaken }), id: \.id
                        ) { photo in
                            let itemWidth = GridLayoutHelper.gridItemWidth(for: geometry.size)
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
