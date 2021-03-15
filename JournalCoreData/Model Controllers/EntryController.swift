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
        
        let id = entry.identifier ?? UUID().uuidString
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
        
        guard let id = entry.identifier else {
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
                var entryReps: [EntryRepresentation] = []
                do {
                    entryReps = Array(try JSONDecoder().decode([String: EntryRepresentation].self, from: data).values)
                } catch {
                    entryReps = []
                }
             
                if entryReps.count == 0 {
                    self.updateEntries(with: entryReps, with: [], in: moc)
                } else {
                let firebaseIDs = entryReps.compactMap({ $0.identifier })
                print("FIREBASE IDS: \(firebaseIDs)")
                    self.updateEntries(with: entryReps, with: firebaseIDs, in: moc)
                }
                
               
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
    
    private func updateEntries(with representations: [EntryRepresentation], with firebaseIDs: [String], in context: NSManagedObjectContext) {
        
        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "NOT id IN %@", firebaseIDs)
        let outdatedEntries = try! context.fetch(fetchRequest)
        
        let localFetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        let localEntries = try! context.fetch(fetchRequest)
        
        context.performAndWait {
                for entryRep in representations {
                    guard let identifier = entryRep.identifier else {
                        continue
                    }
                    
                    let entry = self.fetchSingleEntryFromPersistentStore(with: identifier, in: context)
                    
                    if let entry = entry, entry != entryRep {
                        self.update(entry: entry, with: entryRep)
                    } else if entry == nil {
                        _ = Entry(entryRepresentation: entryRep, context: context)
                    }
                }
            for localEntry in outdatedEntries {
                    self.delete(entry: localEntry)
                }
            saveToPersistentStore()
        }
    }
    
    private func update(entry: Entry, with entryRep: EntryRepresentation) {
        entry.title = entryRep.title
        entry.bodyText = entryRep.bodyText
        entry.mood = entryRep.mood
        entry.timestamp = entryRep.timestamp
        entry.identifier = entryRep.identifier
    }
    
    func saveToPersistentStore() {        
        do {
            try CoreDataStack.shared.mainContext.save()
        } catch {
            NSLog("Error saving managed object context: \(error)")
        }
    }
}
