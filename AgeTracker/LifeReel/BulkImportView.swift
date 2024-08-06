//
//  BulkImportView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import Photos

struct BulkImportView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @State private var albums: [PHAssetCollection] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    var onImportComplete: (() -> Void)?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading albums...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    List(albums, id: \.localIdentifier) { album in
                        NavigationLink(destination: AlbumPhotosView(viewModel: viewModel, person: $person, album: album, onImportComplete: onImportComplete, dismissParent: { presentationMode.wrappedValue.dismiss() })) {
                            Text(album.localizedTitle ?? "Untitled Album")
                        }
                    }
                }
            }
            .navigationBarTitle("Select Album")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear(perform: fetchAlbums)
    }

    private func fetchAlbums() {
        isLoading = true
        errorMessage = nil
        viewModel.fetchAlbums { result in
            isLoading = false
            switch result {
            case .success(let fetchedAlbums):
                self.albums = fetchedAlbums
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AlbumPhotosView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let album: PHAssetCollection
    @State private var photos: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var importAll = false
    @Environment(\.presentationMode) var presentationMode
    var onImportComplete: (() -> Void)?
    @State private var importProgress: Float = 0
    @State private var importStartTime: Date?
    @State private var estimatedTimeRemaining: TimeInterval?
    @State private var averageTimePerPhoto: TimeInterval = 0
    var dismissParent: (() -> Void)?

    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 4)

    var body: some View {
        VStack {
            if isLoading {
                VStack {
                    ProgressView("Importing photos...", value: importProgress, total: 1.0)
                    Text("\(Int(importProgress * 100))%")
                    if let estimatedTimeRemaining = estimatedTimeRemaining {
                        Text("Estimated time remaining: \(formatTimeInterval(estimatedTimeRemaining))")
                    }
                }
                .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                Toggle("Import All Photos", isOn: $importAll)
                    .padding()
                    .onChange(of: importAll) { _, newValue in
                        selectedAssets = newValue ? Set(photos.map { $0.localIdentifier }) : []
                    }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos, id: \.localIdentifier) { asset in
                            AssetThumbnailView(asset: asset, isSelected: selectedAssets.contains(asset.localIdentifier))
                                .onTapGesture {
                                    toggleSelection(for: asset)
                                }
                        }
                    }
                }
            }
        }
        .navigationBarTitle(album.localizedTitle ?? "Untitled Album")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Import") {
            importSelectedPhotos()
        }
        .disabled(selectedAssets.isEmpty))
        .onAppear(perform: fetchPhotosFromAlbum)
    }

    private func toggleSelection(for asset: PHAsset) {
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
        importAll = selectedAssets.count == photos.count
    }

    private func fetchPhotosFromAlbum() {
        isLoading = true
        errorMessage = nil
        viewModel.fetchPhotosFromAlbum(album) { result in
            isLoading = false
            switch result {
            case .success(let fetchedPhotos):
                self.photos = fetchedPhotos
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importSelectedPhotos() {
        isLoading = true
        importStartTime = Date()
        let assetsToImport = selectedAssets.map { assetIdentifier in
            photos.first(where: { $0.localIdentifier == assetIdentifier })!
        }
        
        let batchSize = 10
        let totalBatches = (assetsToImport.count + batchSize - 1) / batchSize
        
        func importBatch(batchIndex: Int) {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, assetsToImport.count)
            let batch = Array(assetsToImport[start..<end])
            
            for (index, asset) in batch.enumerated() {
                let photoStartTime = Date()
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                    if image != nil {
                        print("Successfully retrieved image for asset: \(asset.localIdentifier)")
                        self.viewModel.addPhoto(to: &self.person, asset: asset)
                    } else {
                        print("Failed to import photo for asset: \(asset.localIdentifier)")
                    }
                    
                    let photoEndTime = Date()
                    let photoImportTime = photoEndTime.timeIntervalSince(photoStartTime)
                    
                    let totalPhotosProcessed = batchIndex * batchSize + index + 1
                    averageTimePerPhoto = ((averageTimePerPhoto * Double(totalPhotosProcessed - 1)) + photoImportTime) / Double(totalPhotosProcessed)
                    
                    let progress = Float(totalPhotosProcessed) / Float(assetsToImport.count)
                    let remainingPhotos = assetsToImport.count - totalPhotosProcessed
                    estimatedTimeRemaining = averageTimePerPhoto * Double(remainingPhotos)
                    
                    DispatchQueue.main.async {
                        self.importProgress = progress
                        print("Progress: \(Int(progress * 100))%, Estimated time remaining: \(formatTimeInterval(self.estimatedTimeRemaining ?? 0))")
                    }
                    
                    if index == batch.count - 1 {
                        if batchIndex + 1 < totalBatches {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                importBatch(batchIndex: batchIndex + 1)
                            }
                        } else {
                            finishImport()
                        }
                    }
                }
            }
        }
        
        func finishImport() {
            viewModel.updatePerson(person)
            
            if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                person = updatedPerson
            }
            
            print("Import completed")
            isLoading = false
            onImportComplete?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismissParent?()
            }
        }
        
        importBatch(batchIndex: 0)
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .short
        return formatter.string(from: timeInterval) ?? ""
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 97, height: 97)
                    .clipped()
            } else {
                Color.gray
                    .frame(width: 97, height: 97)
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .background(Color.white.clipShape(Circle()))
                    .padding(2)
            }
        }
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 160, height: 160), contentMode: .aspectFill, options: option) { result, info in
            if let result = result {
                image = result
            }
        }
    }
}