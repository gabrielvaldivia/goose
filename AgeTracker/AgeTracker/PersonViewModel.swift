//
//  PersonViewModel.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit
import Photos

class PersonViewModel: ObservableObject {
    @Published var people: [Person] = []
    
    init() {
        loadPeople()
    }
    
    func addPerson(name: String, dateOfBirth: Date) {
        let newPerson = Person(name: name, dateOfBirth: dateOfBirth)
        people.append(newPerson)
        savePeople()
    }
    
    func addPhoto(to person: Person, image: UIImage, dateTaken: Date) {
        print("Adding photo to \(person.name) with date: \(dateTaken)") // Add this line
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            let newPhoto = Photo(image: image, dateTaken: dateTaken)
            people[index].photos.append(newPhoto)
            savePeople()
            objectWillChange.send()  // Notify observers of the change
        }
    }
    
    func deletePerson(at offsets: IndexSet) {
        people.remove(atOffsets: offsets)
        savePeople()
    }
    
    func calculateAge(for person: Person, at date: Date) -> (years: Int, months: Int, days: Int) {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        return (ageComponents.year ?? 0, ageComponents.month ?? 0, ageComponents.day ?? 0)
    }
    
    func updatePerson(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people[index] = person
            savePeople()
            objectWillChange.send()  // Notify observers of the change
        }
    }
    
    private func savePeople() {
        if let encoded = try? JSONEncoder().encode(people) {
            UserDefaults.standard.set(encoded, forKey: "SavedPeople")
        }
    }
    
    private func loadPeople() {
        if let savedPeople = UserDefaults.standard.data(forKey: "SavedPeople") {
            if let decodedPeople = try? JSONDecoder().decode([Person].self, from: savedPeople) {
                people = decodedPeople
            }
        }
    }
}