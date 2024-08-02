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
    @State private var selectedAlbum: PHAssetCollection?
    @State private var selectedPhotos: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    @State private var syncWithAlbum = false
    @State private var importAll = false
    var onImportComplete: ((String?) -> Void)?
    @State private var importProgress: Float = 0
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    VStack {
                        ProgressView("Importing photos...", value: importProgress, total: 1.0)
                        Text("\(Int(importProgress * 100))%")
                    }
                    .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    Picker("Select Album", selection: $selectedAlbum) {
                        Text("Choose an album").tag(nil as PHAssetCollection?)
                        ForEach(albums, id: \.localIdentifier) { album in
                            Text(album.localizedTitle ?? "Untitled Album").tag(album as PHAssetCollection?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    
                    if let selectedAlbum = selectedAlbum {
                        Toggle("Sync with Album", isOn: $syncWithAlbum)
                            .padding()
                        
                        Toggle("Import All Photos", isOn: $importAll)
                            .padding()
                            .onChange(of: importAll) { newValue in
                                selectedAssets = newValue ? Set(selectedPhotos.map { $0.localIdentifier }) : []
                            }
                        
                        List {
                            ForEach(selectedPhotos, id: \.localIdentifier) { asset in
                                AssetThumbnailView(asset: asset, isSelected: binding(for: asset))
                            }
                        }
                    } else {
                        Text("Please select an album")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Import") {
                    importSelectedPhotos()
                }
                .disabled(selectedAssets.isEmpty)
            )
        }
        .onAppear(perform: fetchAlbums)
        .onChange(of: selectedAlbum) { newAlbum in
            fetchPhotosFromSelectedAlbum()
        }
    }
    
    private func binding(for asset: PHAsset) -> Binding<Bool> {
        Binding(
            get: { self.selectedAssets.contains(asset.localIdentifier) },
            set: { isSelected in
                if isSelected {
                    self.selectedAssets.insert(asset.localIdentifier)
                } else {
                    self.selectedAssets.remove(asset.localIdentifier)
                }
            }
        )
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
    
    private func fetchPhotosFromSelectedAlbum() {
        guard let album = selectedAlbum else { return }
        isLoading = true
        errorMessage = nil
        viewModel.fetchPhotosFromAlbum(album) { result in
            isLoading = false
            switch result {
            case .success(let assets):
                selectedPhotos = assets
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func importSelectedPhotos() {
        isLoading = true
        let assetsToImport = selectedPhotos.filter { selectedAssets.contains($0.localIdentifier) }
        print("Importing \(assetsToImport.count) photos")
        
        let batchSize = 10 // Reduced batch size
        let totalBatches = (assetsToImport.count + batchSize - 1) / batchSize
        
        func importBatch(batchIndex: Int) {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, assetsToImport.count)
            let batch = Array(assetsToImport[start..<end])
            
            for (index, asset) in batch.enumerated() {
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                    if let image = image {
                        print("Successfully retrieved image for asset: \(asset.localIdentifier)")
                        self.viewModel.addPhoto(to: &self.person, image: image, dateTaken: asset.creationDate ?? Date())
                    } else {
                        print("Failed to import photo for asset: \(asset.localIdentifier)")
                    }
                    
                    let progress = Float(batchIndex * batchSize + index + 1) / Float(assetsToImport.count)
                    DispatchQueue.main.async {
                        self.importProgress = progress
                        print("Progress: \(Int(progress * 100))%")
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
            if syncWithAlbum, let selectedAlbum = selectedAlbum {
                person.syncedAlbumIdentifier = selectedAlbum.localIdentifier
                onImportComplete?(selectedAlbum.localIdentifier)
            } else {
                person.syncedAlbumIdentifier = nil
                onImportComplete?(nil)
            }
            
            viewModel.updatePerson(person)
            
            if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                person = updatedPerson
            }
            
            print("Import completed")
            isLoading = false
            presentationMode.wrappedValue.dismiss()
        }
        
        importBatch(batchIndex: 0)
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Color.gray
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
            Toggle("", isOn: $isSelected)
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: options) { result, _ in
            image = result
        }
    }
}