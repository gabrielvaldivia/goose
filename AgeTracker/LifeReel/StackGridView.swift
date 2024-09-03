//
//  StackGridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/15/24.
//

import Foundation
import SwiftUI

struct StackGridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    var openImagePickerForMoment: (String, (Date, Date)) -> Void
    let forceUpdate: Bool

    @State private var orientation = UIDeviceOrientation.unknown

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
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
                    LazyVGrid(columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 10) {
                        ForEach(sortedStacks(), id: \.self) { section in
                            let photos = person.photos.filter { PhotoUtils.sectionForPhoto($0, person: person) == section }
                            let itemWidth = GridLayoutHelper.gridItemWidth(for: geometry.size)
                            
                            if !photos.isEmpty || person.showEmptyStacks {
                                NavigationLink(destination: StackDetailView(viewModel: viewModel, person: $person, sectionTitle: section)) {
                                    StackTileView(section: section, photos: photos, width: itemWidth, isLoading: viewModel.loadingStacks.contains(section))
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    if photos.isEmpty {
                                        openImagePickerForSection(section)
                                    }
                                })
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(person.name)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(
                photo: photo,
                currentIndex: person.photos.firstIndex(of: photo) ?? 0,
                photos: Binding(
                    get: { self.person.photos },
                    set: { newValue in
                        self.person.photos = newValue
                        self.viewModel.updatePerson(self.person)
                    }
                ),
                onDelete: { deletedPhoto in
                    viewModel.deletePhoto(deletedPhoto, from: $person)
                    selectedPhoto = nil
                    viewModel.objectWillChange.send()
                },
                person: $person,
                viewModel: viewModel
            )
            .background(Color.clear)
        }
        .onChange(of: UIDevice.current.orientation) { oldValue, newValue in
            orientation = newValue
        }
        .id(orientation)
        .id(forceUpdate)
    }

    private func sortedStacks() -> [String] {
        let stacks = PhotoUtils.getAllExpectedStacks(for: person)
        let filteredStacks = person.pregnancyTracking == .none ? stacks.filter { !$0.contains("Pregnancy") && !$0.contains("Trimester") && !$0.contains("Week") } : stacks
        
        return filteredStacks.sorted { (stack1, stack2) -> Bool in
            let order: [String] = [
                "First Trimester", "Second Trimester", "Third Trimester",
                "Week", "Birth Month", "Month", "Year"
            ]
            
            func priority(for stack: String) -> Int {
                if stack.contains("Week") {
                    return 0
                }
                return order.firstIndex(where: { stack.contains($0) }) ?? order.count
            }
            
            let priority1 = priority(for: stack1)
            let priority2 = priority(for: stack2)
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // For weeks, sort numerically
            if stack1.contains("Week") && stack2.contains("Week") {
                let week1 = Int(stack1.components(separatedBy: " ")[1]) ?? 0
                let week2 = Int(stack2.components(separatedBy: " ")[1]) ?? 0
                return week1 < week2
            }
            
            // For months, sort numerically
            if stack1.contains("Month") && stack2.contains("Month") {
                let month1 = Int(stack1.components(separatedBy: " ")[0]) ?? 0
                let month2 = Int(stack2.components(separatedBy: " ")[0]) ?? 0
                return month1 < month2
            }
            
            // For years, sort numerically
            if stack1.contains("Year") && stack2.contains("Year") {
                let year1 = Int(stack1.components(separatedBy: " ")[0]) ?? 0
                let year2 = Int(stack2.components(separatedBy: " ")[0]) ?? 0
                return year1 < year2
            }
            
            return stack1 < stack2
        }
    }

    private func openImagePickerForEmptyState() {
        do {
            let dateRange = try PhotoUtils.getDateRangeForSection("Birth Month", person: person)
            openImagePickerForMoment("Birth Month", dateRange)
        } catch {
            print("Error getting date range for Birth Month: \(error)")
        }
    }

    private func openImagePickerForSection(_ section: String) {
        do {
            let dateRange = try PhotoUtils.getDateRangeForSection(section, person: person)
            openImagePickerForMoment(section, dateRange)
        } catch {
            print("Error getting date range for \(section): \(error)")
        }
    }
    
    private func captureScreenshot() -> UIImage {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene?.windows.first { $0.isKeyWindow }
        let renderer = UIGraphicsImageRenderer(bounds: window?.bounds ?? .zero)
        return renderer.image { ctx in
            window?.drawHierarchy(in: window?.bounds ?? .zero, afterScreenUpdates: true)
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

struct StackTileView: View {
    let section: String
    let photos: [Photo]
    let width: CGFloat
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            if let latestPhoto = photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first {
                Image(uiImage: latestPhoto.image ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: width)
                    .clipped()
                    .cornerRadius(10)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(section)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(10)
                        Spacer()
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                }
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
                                VStack {
                                    Spacer()
                                    Image(systemName: "plus")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 30))
                                    Spacer()
                                    Text(section)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.top, 4)
                                }
                                .padding(10)
                            }
                        }
                    )
            }
        }
        .frame(width: width, height: width)
        .cornerRadius(10)
    }
}

// Add this extension to enable corner radius for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}