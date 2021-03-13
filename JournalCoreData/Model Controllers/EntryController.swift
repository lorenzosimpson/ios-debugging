//
//  EntryController.swift
//  JournalCoreData
//
//  Created by Spencer Curtis on 8/12/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation
import CoreData

let baseURL = URL(string: "https://journal-277a4-default-rtdb.firebaseio.com/")!

class EntryController {
    
    init() {
        fetchEntriesFromServer()
    }
    
    func createEntry(with title: String, bodyText: String, mood: String) {
        
        let entry = Entry(title: title, bodyText: bodyText, mood: mood)
        
        put(entry: entry)
        
        saveToPersistentStore()
    }
    
    func update(entry: Entry, title: String, bodyText: String, mood: String) {
        
        entry.title = title
        entry.bodyText = bodyText
        entry.timestamp = Date()
        entry.mood = mood
        
        put(entry: entry)
        
        saveToPersistentStore()
    }
    
    func delete(entry: Entry) {
        
        CoreDataStack.shared.mainContext.delete(entry)
        deleteEntryFromServer(entry: entry)
        saveToPersistentStore()
    }
    
    private func put(entry: Entry, completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        let id = entry.id ?? UUID().uuidString
        let requestURL = baseURL.appendingPathComponent(id).appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        
        do {
            request.httpBody = try JSONEncoder().encode(entry)
        } catch {
            NSLog("Error encoding Entry: \(error)")
            completion(error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                NSLog("Error PUTting Entry to server: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    func deleteEntryFromServer(entry: Entry, completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        guard let id = entry.id else {
            NSLog("Entry id is nil")
            completion(NSError())
            return
        }
        
        let requestURL = baseURL.appendingPathComponent(id).appendingPathExtension("json")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        
        URLSession.shared.dataTask(with: request) { (data, _, error) in
            if let error = error {
                NSLog("Error deleting entry from server: \(error)")
                completion(error)
                return
            }
            
            completion(nil)
        }.resume()
    }
    
    func fetchEntriesFromServer(completion: @escaping ((Error?) -> Void) = { _ in }) {
        
        let requestURL = baseURL.appendingPathExtension("json")
        
        URLSession.shared.dataTask(with: requestURL) { (data, _, error) in
            
            if let error = error {
                NSLog("Error fetching entries from server: \(error)")
                completion(error)
                return
            }
            
            guard let data = data else {
                NSLog("No data returned from data task")
                completion(NSError())
                return
            }

            let moc = CoreDataStack.shared.mainContext
            
            do {
                print(data)
                let entryReps = try JSONDecoder().decode([String: EntryRepresentation].self, from: data).map({$0.value})
                self.updateEntries(with: entryReps, in: moc)
            } catch {
                NSLog("Error decoding JSON data: \(error)")
                completion(error)
                return
            }
           
            moc.perform {
                do {
                    try moc.save()
                    completion(nil)
                } catch {
                    NSLog("Error saving context: \(error)")
                    completion(error)
                }
            }
        }.resume()
    }
    
    private func fetchSingleEntryFromPersistentStore(with id: String?, in context: NSManagedObjectContext) -> Entry? {
        
        guard let id = id else {
            return nil
        }
        
        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        var result: Entry? = nil
        do {
            result = try context.fetch(fetchRequest).first
        } catch {
            NSLog("Error fetching single entry: \(error)")
        }
        return result
    }
    
    private func updateEntries(with representations: [EntryRepresentation], in context: NSManagedObjectContext) {
        context.performAndWait {
            for entryRep in representations {
                print(entryRep)
                guard let id = entryRep.id else {
                    fatalError("Firebase entry does not have an id")
                    continue
                }
                
                let entry = self.fetchSingleEntryFromPersistentStore(with: id, in: context)
                if let entry = entry, entry != entryRep {
                    self.update(entry: entry, with: entryRep)
                } else if entry == nil {
                    _ = Entry(entryRepresentation: entryRep, context: context)
                }
            }
            saveToPersistentStore()
        }
    }
    
    private func update(entry: Entry, with entryRep: EntryRepresentation) {
        entry.title = entryRep.title
        entry.bodyText = entryRep.bodyText
        entry.mood = entryRep.mood
        entry.timestamp = entryRep.timestamp
        entry.id = entryRep.id
    }
    
    func saveToPersistentStore() {        
        do {
            try CoreDataStack.shared.mainContext.save()
        } catch {
            NSLog("Error saving managed object context: \(error)")
        }
    }
}
