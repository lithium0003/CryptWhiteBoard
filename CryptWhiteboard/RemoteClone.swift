//
//  RemoteClone.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/06.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit
import CloudKit
import CoreData

class RemoteClone {
    static let viewContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext

    static let user = UUID()
    static let other = UUID()
    
    class func addRecord(remote: CKRecord) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let newRecord = CloneData(context: viewContext)
            newRecord.id = remote.recordID.recordName
            newRecord.active = remote["active"] as! Int64
            newRecord.board = remote["board"]
            newRecord.time = remote["time"]
            newRecord.stroke = remote["stroke"]
            newRecord.cmd = remote["cmd"]
            newRecord.editor = user
            try? viewContext.save()
        }
    }
    
    class func modifyRecord(remote: CKRecord) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", remote.recordID.recordName)
            let fetchData = try? viewContext.fetch(fetchRequest)
            if let item = fetchData?.first {
                if item.active != remote["active"] as! Int64 ||
                    item.board != remote["board"] ||
                    item.time != remote["time"] ||
                    item.stroke != remote["stroke"] ||
                    item.cmd != remote["cmd"] {
                    
                    item.active = remote["active"] as! Int64
                    item.board = remote["board"]
                    item.time = remote["time"]
                    item.stroke = remote["stroke"]
                    item.cmd = remote["cmd"]
                    print("modify \(item.id ?? "")")
                    try? viewContext.save()
                }
            }
            else {
                let newRecord = CloneData(context: viewContext)
                newRecord.id = remote.recordID.recordName
                newRecord.active = remote["active"] as! Int64
                newRecord.board = remote["board"]
                newRecord.time = remote["time"]
                newRecord.stroke = remote["stroke"]
                newRecord.cmd = remote["cmd"]
                newRecord.editor = other
                try? viewContext.save()
            }
        }
    }

    class func deleteRecord(remoteId: String) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", remoteId)
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
        }
    }

    class func lastUndoableRecord(boardId: String, finish: @escaping (String?)->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (NOT cmd IN %@) && (active > 0) && (editor == %@)", boardId, ["init"], self.user as NSUUID)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
            fetchRequest.fetchLimit = 1
            if let item = try? viewContext.fetch(fetchRequest).first {
                finish(item.id)
            }
            finish(nil)
        }
    }

    class func lastRedoableRecord(boardId: String, finish: @escaping (String?)->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (NOT cmd IN %@) && (active == 0) && (editor == %@)", boardId, ["init"], self.user as NSUUID)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
            fetchRequest.fetchLimit = 1
            if let item = try? viewContext.fetch(fetchRequest).first {
                finish(item.id)
            }
            finish(nil)
        }
    }

    class func undoRecord(remoteId: String, finish: @escaping ()->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", remoteId)
            if let item = try? viewContext.fetch(fetchRequest).first {
                item.active = 0
                try? viewContext.save()
            }
            finish()
        }
    }

    class func redoRecord(remoteId: String, finish: @escaping ()->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", remoteId)
            if let item = try? viewContext.fetch(fetchRequest).first {
                item.active = 1
                try? viewContext.save()
            }
            finish()
        }
    }
    
    class func deleteAllstroke(boardId: String, before: Date? = nil) {
        if Thread.isMainThread {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            if let before = before {
                fetchRequest.predicate = NSPredicate(format: "(board == %@) && (time < %@)", boardId, before as NSDate)
            }
            else {
                fetchRequest.predicate = NSPredicate(format: "board == %@", boardId)
            }
            if let fetchData = try? viewContext.fetch(fetchRequest) {
                for item in fetchData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
            return
        }
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            if let before = before {
                fetchRequest.predicate = NSPredicate(format: "(board == %@) && (time < %@)", boardId, before as NSDate)
            }
            else {
                fetchRequest.predicate = NSPredicate(format: "board == %@", boardId)
            }
            if let fetchData = try? viewContext.fetch(fetchRequest) {
                for item in fetchData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
        }
    }
    
    class func decodeBoard(remote: RemoteData, time: Date = Date(timeIntervalSince1970: 0), finish: @escaping ()->Void, command: @escaping (String?, String?, Data?, Date?)->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (time >= %@)", remote.boardId, time as NSDate)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            let queue = DispatchQueue(label: "command")
            if let fetchData = try? viewContext.fetch(fetchRequest) {
                for item in fetchData {
                    if let (cmd, data) = remote.decodeCommand(local: item) {
                        let id = item.id
                        let t = item.time
                        let a = item.active
                        queue.async {
                            if a > 0 {
                                command(id,cmd,data,t)
                            }
                            else {
                                command(id,nil,nil,t)
                            }
                        }
                    }
                }
            }
            queue.async {
                finish()
            }
        }
    }

    class func lasttimeBoard(remote: RemoteData, finish: @escaping (Date)->Void) {
        DispatchQueue.main.async {
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CloneData> = CloneData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "board == %@", remote.boardId)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
            finish((try? viewContext.fetch(fetchRequest))?.first?.time ?? Date(timeIntervalSince1970: 0))
        }
    }
}
