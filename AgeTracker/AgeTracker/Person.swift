//
//  Person.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit

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
    let imageName: String
    let dateTaken: Date
    
    var image: UIImage? {
        let path = Photo.getDocumentsDirectory().appendingPathComponent(imageName).path
        print("Loading image from path: \(path)")
        return UIImage(contentsOfFile: path)
    }
    
    init(id: UUID = UUID(), image: UIImage, dateTaken: Date) {
        self.id = id
        self.imageName = "\(id).jpg"
        self.dateTaken = dateTaken
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = Photo.getDocumentsDirectory().appendingPathComponent(imageName)
            print("Saving image to path: \(url.path)")
            try? data.write(to: url)
        }
    }
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id &&
               lhs.imageName == rhs.imageName &&
               lhs.dateTaken == rhs.dateTaken
    }
}