//
//  Person.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit
import AVFoundation

struct Person: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var dateOfBirth: Date
    var photos: [Photo]
    var syncedAlbumIdentifier: String?
    
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
               lhs.syncedAlbumIdentifier == rhs.syncedAlbumIdentifier
    }
}

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let dateTaken: Date
    let isVideo: Bool
    
    var image: UIImage? {
        guard !isVideo else { return nil }
        let path = Photo.getDocumentsDirectory().appendingPathComponent(fileName).path
        return UIImage(contentsOfFile: path)
    }
    
    var videoURL: URL? {
        guard isVideo else { return nil }
        return Photo.getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    init(id: UUID = UUID(), image: UIImage, dateTaken: Date) {
        self.id = id
        self.fileName = "\(id).jpg"
        self.dateTaken = dateTaken
        self.isVideo = false
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = Photo.getDocumentsDirectory().appendingPathComponent(fileName)
            try? data.write(to: url)
        }
    }
    
    init(id: UUID = UUID(), videoURL: URL, dateTaken: Date) {
        self.id = id
        self.fileName = "\(id).mov"
        self.dateTaken = dateTaken
        self.isVideo = true
        
        let destinationURL = Photo.getDocumentsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.copyItem(at: videoURL, to: destinationURL)
    }
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}