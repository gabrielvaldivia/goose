//
//  PersonViewModel.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import Photos
import SwiftUI
import UIKit

extension Notification.Name {
    static let photosUpdated = Notification.Name("photosUpdated")
    static let personDeleted = Notification.Name("personDeleted")
}

class PersonViewModel: ObservableObject {
    @Published var people: [Person] = []
    @Published var lastOpenedPersonId: UUID?
    @Published var loadingStacks: Set<String> = []
    @Published var selectedPerson: Person?
    @Published var navigationPath = NavigationPath()
    @Published var newlyAddedPerson: Person?
    @Published var mostRecentlyAddedPhoto: Photo?
    @Published var photoAddedTrigger: Bool = false

    init() {
        loadPeople()
        loadLastOpenedPersonId()

        // Check if photo migration is needed
        // if !UserDefaults.standard.bool(forKey: "photoMigrationCompleted") {
        //     migratePhotos()
        //     migratePhotoStructure()
        //     UserDefaults.standard.set(true, forKey: "photoMigrationCompleted")
        // }
    }

    func addPerson(name: String, dateOfBirth: Date, asset: PHAsset) {
        var newPerson = Person(name: name, dateOfBirth: dateOfBirth)
        addPhoto(to: &newPerson, asset: asset)
        people.append(newPerson)
        savePeople()

        // Use setSelectedPerson to handle navigation
        setSelectedPerson(newPerson)
    }

    private func updatePersonWithNewPhoto(_ person: inout Person, photo: Photo) {
        print("Adding photo to \(person.name) with date: \(photo.dateTaken)")
        if !person.photos.contains(where: { $0.assetIdentifier == photo.assetIdentifier }) {
            person.photos.append(photo)
            person.photos.sort { $0.dateTaken < $1.dateTaken }
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = person
                savePeople()
                objectWillChange.send()
                NotificationCenter.default.post(name: .photosUpdated, object: nil)
                print(
                    "Photo added successfully. Total photos for \(person.name): \(person.photos.count)"
                )
            } else {
                print("Failed to find person \(person.name) in people array")
            }
        } else {
            print(
                "Photo with asset identifier \(photo.assetIdentifier) already exists for \(person.name)"
            )
        }
    }

    func addPhoto(to person: inout Person, asset: PHAsset) {
        if let newPhoto = Photo(asset: asset) {
            updatePersonWithNewPhoto(&person, photo: newPhoto)
        } else {
            print("Failed to create Photo object from asset")
        }
    }

    func addPhoto(to person: inout Person, photo: Photo) {
        updatePersonWithNewPhoto(&person, photo: photo)
    }

    func deletePerson(at offsets: IndexSet) {
        people.remove(atOffsets: offsets)
        savePeople()
    }

    func deletePerson(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            // Remove the person
            people.remove(at: index)
            savePeople()

            // Select the next person, or the previous one if this was the last person
            let nextIndex = min(index, people.count - 1)
            if nextIndex >= 0 {
                setSelectedPerson(people[nextIndex])
            } else {
                selectedPerson = nil
                navigationPath = NavigationPath()
            }

            // Notify observers of the change
            objectWillChange.send()
        }
    }

    func calculateAge(for person: Person, at date: Date) -> String {
        return AgeCalculator.calculate(for: person, at: date).toString()
    }

    func updatePerson(_ updatedPerson: Person) {
        if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
            people[index] = updatedPerson
            selectedPerson = updatedPerson
            savePeople()
            objectWillChange.send()
            NotificationCenter.default.post(name: .photosUpdated, object: nil)
        }
    }

    func updatePersonProperties(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people[index] = person
            savePeople()
        }
    }

    public func savePeople() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(people)
            UserDefaults.standard.set(data, forKey: "SavedPeople")
        } catch {
            print("Failed to save people: \(error.localizedDescription)")
        }
    }

    private func loadPeople() {
        if let savedPeople = UserDefaults.standard.data(forKey: "SavedPeople") {
            do {
                let decoder = JSONDecoder()
                people = try decoder.decode([Person].self, from: savedPeople)
            } catch {
                print("Failed to load people: \(error.localizedDescription)")
            }
        }
    }

    // New function to fetch photos for a person
    func fetchPhotosForPerson(
        _ person: Person, completion: @escaping (Result<[PHAsset], Error>) -> Void
    ) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized {
                    self.performFetch(for: person, completion: completion)
                } else {
                    completion(.failure(PhotoAccessError.denied))
                }
            }
        case .restricted, .denied:
            completion(.failure(PhotoAccessError.denied))
        case .authorized, .limited:
            performFetch(for: person, completion: completion)
        @unknown default:
            completion(.failure(PhotoAccessError.unknown))
        }
    }

    private func performFetch(
        for person: Person, completion: @escaping (Result<[PHAsset], Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var personPhotos: [PHAsset] = []

            allPhotos.enumerateObjects { (asset, _, stop) in
                let personNamePredicate = NSPredicate(format: "localizedTitle = %@", person.name)
                let personFetchResult = PHAssetCollection.fetchAssetCollections(
                    with: .album, subtype: .albumRegular, options: nil)
                let personAlbums = personFetchResult.objects(
                    at: IndexSet(integersIn: 0..<personFetchResult.count)
                ).filter { personNamePredicate.evaluate(with: $0) }

                if !personAlbums.isEmpty {
                    personPhotos.append(asset)
                }

                if personPhotos.count >= 100 {  // Limit to 100 photos for performance
                    stop.pointee = true
                }
            }

            DispatchQueue.main.async {
                completion(.success(personPhotos))
            }
        }
    }

    // Add to PersonViewModel
    func loadPhotos(
        for person: Person, page: Int, perPage: Int, completion: @escaping (Bool) -> Void
    ) {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else {
            completion(false)
            return
        }

        let start = page * perPage
        let end = min(start + perPage, person.photos.count)
        guard start < person.photos.count else {
            completion(false)
            return
        }

        // Simulate async loading to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            let photosToLoad = Array(person.photos[start..<end])

            // Pre-load images in background
            for photo in photosToLoad {
                _ = photo.image  // This will trigger the image loading
            }

            DispatchQueue.main.async {
                // Update the UI
                self.objectWillChange.send()
                completion(true)
            }
        }
    }

    // Optional: Add a method to clear cached images when memory warning is received
    func clearImageCache() {
        // Implement cache clearing logic here
    }

    // func fetchAlbums(completion: @escaping (Result<[PHAssetCollection], Error>) -> Void) {
    //     let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    //     switch status {
    //     case .notDetermined:
    //         PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
    //             if newStatus == .authorized {
    //                 self.performAlbumsFetch(completion: completion)
    //             } else {
    //                 completion(.failure(PhotoAccessError.denied))
    //             }
    //         }
    //     case .restricted, .denied:
    //         completion(.failure(PhotoAccessError.denied))
    //     case .authorized, .limited:
    //         performAlbumsFetch(completion: completion)
    //     @unknown default:
    //         completion(.failure(PhotoAccessError.unknown))
    //     }
    // }

    // private func performAlbumsFetch(
    //     completion: @escaping (Result<[PHAssetCollection], Error>) -> Void
    // ) {
    //     DispatchQueue.global(qos: .userInitiated).async {
    //         let userAlbums = PHAssetCollection.fetchAssetCollections(
    //             with: .album, subtype: .any, options: nil)
    //         let smartAlbums = PHAssetCollection.fetchAssetCollections(
    //             with: .smartAlbum, subtype: .any, options: nil)

    //         var albums: [PHAssetCollection] = []
    //         userAlbums.enumerateObjects { (collection, _, _) in
    //             albums.append(collection)
    //         }
    //         smartAlbums.enumerateObjects { (collection, _, _) in
    //             albums.append(collection)
    //         }

    //         DispatchQueue.main.async {
    //             completion(.success(albums))
    //         }
    //     }
    // }

    // func fetchPhotosFromAlbum(
    //     _ album: PHAssetCollection, completion: @escaping (Result<[PHAsset], Error>) -> Void
    // ) {
    //     DispatchQueue.global(qos: .userInitiated).async {
    //         let fetchOptions = PHFetchOptions()
    //         fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    //         let assetsFetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)

    //         var assets: [PHAsset] = []
    //         assetsFetchResult.enumerateObjects { (asset, _, _) in
    //             assets.append(asset)
    //         }

    //         DispatchQueue.main.async {
    //             completion(.success(assets))
    //         }
    //     }
    // }

    func movePerson(from source: IndexSet, to destination: Int) {
        people.move(fromOffsets: source, toOffset: destination)
    }

    func deleteAllPhotos(for person: Person, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Find the person in the people array
            guard var updatedPerson = self.people.first(where: { $0.id == person.id }) else {
                DispatchQueue.main.async {
                    completion(
                        .failure(NSError(domain: "PersonNotFound", code: 404, userInfo: nil)))
                }
                return
            }

            // Remove all photos
            updatedPerson.photos.removeAll()

            // Update the person in the people array
            if let index = self.people.firstIndex(where: { $0.id == person.id }) {
                self.people[index] = updatedPerson
            }

            // Save the updated people array
            self.savePeople()

            DispatchQueue.main.async {
                self.objectWillChange.send()
                completion(.success(()))
            }
        }
    }

    func deletePhoto(_ photo: Photo, from personBinding: Binding<Person>) {
        if let index = personBinding.wrappedValue.photos.firstIndex(where: { $0.id == photo.id }) {
            personBinding.photos.wrappedValue.remove(at: index)
            if let personIndex = people.firstIndex(where: { $0.id == personBinding.wrappedValue.id }
            ) {
                people[personIndex] = personBinding.wrappedValue
                savePeople()

                // Force view updates
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                    NotificationCenter.default.post(name: .photosUpdated, object: nil)

                    // Post an additional notification specifically for photo deletion
                    NotificationCenter.default.post(
                        name: NSNotification.Name("photoDeleted"),
                        object: nil,
                        userInfo: ["photoID": photo.id]
                    )
                }
            }
        }
    }

    func setLastOpenedPerson(_ person: Person) {
        lastOpenedPersonId = person.id
        UserDefaults.standard.set(lastOpenedPersonId?.uuidString, forKey: "lastOpenedPersonId")
    }

    private func loadLastOpenedPersonId() {
        if let savedId = UserDefaults.standard.string(forKey: "lastOpenedPersonId"),
            let uuid = UUID(uuidString: savedId)
        {
            lastOpenedPersonId = uuid
        }
    }

    func deleteAllData() {
        people.removeAll()
        UserDefaults.standard.removeObject(forKey: "SavedPeople")
        UserDefaults.standard.removeObject(forKey: "lastOpenedPersonId")
        UserDefaults.standard.synchronize()
        objectWillChange.send()
    }

    func resetLoadingState(for section: String) {
        DispatchQueue.main.async {
            self.loadingStacks.remove(section)
        }
    }

    func bindingForPerson(_ person: Person) -> Binding<Person> {
        Binding<Person>(
            get: { self.people.first(where: { $0.id == person.id }) ?? person },
            set: { newValue in
                if let index = self.people.firstIndex(where: { $0.id == person.id }) {
                    self.people[index] = newValue
                }
            }
        )
    }

    func addPhoto(to person: Person, asset: PHAsset, completion: @escaping (Photo?) -> Void) {
        print("Adding photo to \(person.name) with date: \(asset.creationDate ?? Date())")
        if let newPhoto = Photo(asset: asset) {
            if !person.photos.contains(where: { $0.assetIdentifier == newPhoto.assetIdentifier }) {
                if let index = people.firstIndex(where: { $0.id == person.id }) {
                    people[index].photos.append(newPhoto)
                    people[index].photos.sort { $0.dateTaken < $1.dateTaken }
                    selectedPerson = people[index]  // Update selectedPerson
                    savePeople()
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                        NotificationCenter.default.post(name: .photosUpdated, object: nil)
                        print(
                            "Photo added successfully. Total photos for \(person.name): \(self.people[index].photos.count)"
                        )
                        completion(newPhoto)
                    }
                } else {
                    print("Failed to find person \(person.name) in people array")
                    completion(nil)
                }
            } else {
                print(
                    "Photo with asset identifier \(newPhoto.assetIdentifier) already exists for \(person.name)"
                )
                completion(nil)
            }
        } else {
            print("Failed to create Photo object from asset")
            completion(nil)
        }
    }

    func updatePhotoDate(person: Person, photo: Photo, newDate: Date) -> Person {
        var updatedPerson = person
        if let index = updatedPerson.photos.firstIndex(where: { $0.id == photo.id }) {
            updatedPerson.photos[index].dateTaken = newDate
            updatedPerson.photos.sort { $0.dateTaken < $1.dateTaken }
        }

        if let personIndex = people.firstIndex(where: { $0.id == person.id }) {
            people[personIndex] = updatedPerson
            savePeople()
            objectWillChange.send()
            NotificationCenter.default.post(name: .photosUpdated, object: nil)
        }

        return updatedPerson
    }

    func navigateToPersonDetail(_ person: Person) {
        navigationPath.append(person)
    }

    func setSelectedPerson(_ person: Person?) {
        if let person = person {
            setLastOpenedPerson(person)
            selectedPerson = person

            // If we're in settings, preserve that state
            let wasInSettings = navigationPath.count == 1
            navigationPath = NavigationPath()
            if wasInSettings {
                navigationPath.append("settings")
            }
        }
        objectWillChange.send()
    }

    func bindingForSelectedPerson() -> Binding<Person>? {
        guard let selectedPerson = selectedPerson else { return nil }
        return Binding<Person>(
            get: { self.selectedPerson ?? selectedPerson },
            set: { newValue in
                self.selectedPerson = newValue
                if let index = self.people.firstIndex(where: { $0.id == newValue.id }) {
                    self.people[index] = newValue
                }
                self.savePeople()
            }
        )
    }

    func addPhotoToSelectedPerson(asset: PHAsset) {
        guard let selectedPerson = selectedPerson else {
            print("No person selected to add photo to")
            return
        }

        print("Attempting to add photo with asset identifier: \(asset.localIdentifier)")

        // Check if the photo already exists
        if selectedPerson.photos.contains(where: { $0.assetIdentifier == asset.localIdentifier }) {
            print("Photo already exists for \(selectedPerson.name)")
            return
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit,
            options: options
        ) { image, info in
            if let error = info?[PHImageErrorKey] as? Error {
                print("Error fetching image: \(error.localizedDescription)")
                return
            }

            guard image != nil else {
                print("Failed to create image from asset. Info: \(String(describing: info))")
                return
            }

            if let newPhoto = Photo(asset: asset) {
                DispatchQueue.main.async {
                    if let index = self.people.firstIndex(where: { $0.id == selectedPerson.id }) {
                        self.people[index].photos.append(newPhoto)
                        self.people[index].photos.sort { $0.dateTaken < $1.dateTaken }
                        self.selectedPerson = self.people[index]
                        self.savePeople()
                        self.objectWillChange.send()
                        NotificationCenter.default.post(name: .photosUpdated, object: nil)
                        print(
                            "Photo added successfully to \(selectedPerson.name). Total photos: \(self.people[index].photos.count)"
                        )
                    } else {
                        print("Failed to find selected person in people array")
                    }
                }
            } else {
                print("Failed to create Photo object from asset")
            }
        }
    }

    func updatePersonPhotos(_ person: Person, newPhotos: [Photo]) {
        if var updatedPerson = people.first(where: { $0.id == person.id }) {
            updatedPerson.photos = newPhotos
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = updatedPerson
                savePeople()
                objectWillChange.send()
            }
        }
    }

    func deletePhoto(_ photo: Photo, from person: Person) {
        if var updatedPerson = people.first(where: { $0.id == person.id }) {
            updatedPerson.photos.removeAll { $0.id == photo.id }
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = updatedPerson
                savePeople()
                objectWillChange.send()
            }
        }
    }

    func forceUpdate() {
        self.objectWillChange.send()
    }

    func requestNotificationPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print(
                        "Error requesting notification permissions: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
}

enum PhotoAccessError: Error {
    case denied
    case unknown
    case albumNotFound
}
