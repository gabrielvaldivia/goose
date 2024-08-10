//
//  Person.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit
import AVFoundation
import Photos

struct Person: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var dateOfBirth: Date
    var photos: [Photo]
    var syncedAlbumIdentifier: String?
    var ageFormat: AgeFormat = .full
    
    init(name: String, dateOfBirth: Date) {
        self.id = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.photos = []
    }
    
    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.dateOfBirth == rhs.dateOfBirth &&
               lhs.photos == rhs.photos &&
               lhs.syncedAlbumIdentifier == rhs.syncedAlbumIdentifier &&
               lhs.ageFormat == rhs.ageFormat
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum AgeFormat: String, Codable, CaseIterable {
    case full = "YY, MM, DD"
    case yearMonth = "YY, MM"
    case yearOnly = "YY"
}

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    let assetIdentifier: String
    var dateTaken: Date
    let isVideo: Bool

    var image: UIImage? {
        guard !isVideo else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        
        let manager = PHImageManager.default()
        var image: UIImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { result, _ in
            image = result
        }
        
        return image
    }

    var videoURL: URL? {
        guard isVideo else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        
        var videoURL: URL?
        let options = PHVideoRequestOptions()
        options.version = .original
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                videoURL = urlAsset.url
            }
        }
        
        return videoURL
    }

    init(asset: PHAsset) {
        self.id = UUID()
        self.assetIdentifier = asset.localIdentifier
        self.dateTaken = asset.creationDate ?? Date()
        self.isVideo = asset.mediaType == .video
    }
}