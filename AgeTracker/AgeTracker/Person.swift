//
//  Person.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit

struct Person: Identifiable, Codable {
    let id: UUID
    let name: String
    let dateOfBirth: Date
    var photos: [Photo]
    
    init(name: String, dateOfBirth: Date) {
        self.id = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.photos = []
    }
}

struct Photo: Identifiable, Codable {
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
}