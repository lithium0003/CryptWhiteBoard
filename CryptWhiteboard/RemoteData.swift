//
//  RemoteData.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/24.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import CloudKit
import Compression
import UIKit
import CommonCrypto

class RemoteData {
    static let boardDatabase = CKContainer(identifier: "iCloud.info.lithium03.whiteboard").publicCloudDatabase
    let boardId: String
    let keyBytes: Data
    
    init(board: String, key: String) {
        boardId = board
        keyBytes = RemoteData.pbkdf2(password: key, salt: board.data(using: .utf8)!)
    }
    
    func isValid(finish: @escaping (Bool?)->Void) {
        RemoteData.isValidBoard(boardId: boardId, keyBytes: keyBytes) { exist, valid in
            guard let exist = exist else {
                finish(nil)
                return
            }
            guard exist, valid else {
                finish(false)
                return
            }
            finish(true)
        }
    }
    
    class func isValidBoard(boardId: String, key: String, finish: @escaping (Bool?, Bool)->Void) {
        let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "(board == %@) && (cmd == %@)", boardId, "init"))
        query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        RemoteData.boardDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { (records, error) in

            guard error == nil else{
                print(error?.localizedDescription as Any)
                print(error as Any)
                finish(nil, false)
                return
            }
            
            let kData = pbkdf2(password: key, salt: boardId.data(using: .utf8)!)
            
            var isExists = false
            var pass = false
            records?.forEach({ (record) in
                isExists = true
                guard let s = record["stroke"] as? String else {
                    return
                }
                guard let d = DecompressData(src: s, key: kData) else {
                    return
                }
                if String(bytes: d, encoding: .utf8) == boardId {
                    pass = true
                }
            })
            
            finish(isExists, pass)
        }
    }

    class func isValidBoard(boardId: String, keyBytes: Data, finish: @escaping (Bool?, Bool)->Void) {
        let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "(board == %@) && (cmd == %@)", boardId, "init"))
        query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        RemoteData.boardDatabase.perform(query, inZoneWith: CKRecordZone.default().zoneID) { (records, error) in

            guard error == nil else{
                print(error?.localizedDescription as Any)
                print(error as Any)
                finish(nil, false)
                return
            }
            
            var isExists = false
            var pass = false
            records?.forEach({ (record) in
                isExists = true
                guard let s = record["stroke"] as? String else {
                    return
                }
                guard let d = DecompressData(src: s, key: keyBytes) else {
                    return
                }
                if String(bytes: d, encoding: .utf8) == boardId {
                    pass = true
                }
            })
            
            finish(isExists, pass)
        }
    }

    class func makeBoard(boardId: String, key: String, finish: @escaping (Bool?)->Void) {
        let kData = pbkdf2(password: key, salt: boardId.data(using: .utf8)!)
        guard let str = ComressData(src: boardId.data(using: .utf8)!, key: kData) else {
            finish(nil)
            return
        }

        let newRecord = CKRecord(recordType: "Board")
        newRecord["board"] = boardId
        newRecord["time"] = Date()
        newRecord["stroke"] = str
        newRecord["cmd"] = "init"
        newRecord["active"] = 1

        let operation = CKModifyRecordsOperation(recordsToSave: [newRecord], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInteractive
        operation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print(error.localizedDescription)
                print(error as Any)
                return
            }
            RemoteClone.addRecord(remote: record)
        }
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            guard operationError == nil else {
                print(operationError?.localizedDescription as Any)
                print(operationError as Any)
                finish(nil)
                return
            }
            finish(savedRecords?.count ?? 0 > 0)
        }
        RemoteData.boardDatabase.add(operation)
    }
    
    class func ComressData(src: Data, key: Data) -> String? {
        if src.count == 0 {
            return ""
        }
        var sourceBuffer = [UInt8](src)
        let destinationBufferSize = max(sourceBuffer.count * 2, 512)
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        let compressedSize = compression_encode_buffer(&destinationBuffer, destinationBufferSize, &sourceBuffer, sourceBuffer.count, nil, COMPRESSION_LZFSE)
        guard compressedSize > 0 else {
            print("compression error")
            return nil
        }
        let encodedData = Data(bytes: destinationBuffer, count: compressedSize)
        guard let encryptedData = EncryptData(plain: encodedData as Data, key: key) else {
            return nil
        }
        let str = encryptedData.base64EncodedString()
        return str
    }
    
    static let decodedCapacity = 8_000_000
    static var decodedDestinationBuffer = [UInt8](repeating: 0, count: decodedCapacity)

    class func DecompressData(src: String, key: Data) -> Data? {
        if src.isEmpty {
            return Data()
        }
        guard let encodedSourceData = Data(base64Encoded: src) else {
            return nil
        }
        guard let decryptedData = DecryptData(chipter: encodedSourceData, key: key) else {
            return nil
        }
        
        let decodedData = decryptedData.withUnsafeBytes { pointer -> Data? in
            let decodedCount = compression_decode_buffer(&decodedDestinationBuffer, decodedCapacity, pointer.bindMemory(to: UInt8.self).baseAddress!, decryptedData.count, nil, COMPRESSION_LZFSE)
            guard decodedCount > 0 else {
                return nil
            }
            let result = Data(bytes: decodedDestinationBuffer, count: decodedCount)
            return result
        }
        guard let d = decodedData else {
            return nil
        }
        return d
    }
 
    class func EncryptData(plain: Data, key: Data) -> Data? {
        let keyLength = key.count
        guard keyLength == kCCKeySizeAES256 else {
            return nil
        }
        let ivSize = kCCBlockSizeAES128
        let cryptLength = size_t(ivSize + plain.count + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        let status = cryptData.withUnsafeMutableBytes { ivBytes in
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, ivBytes.baseAddress!)
        }
        guard status == 0 else {
            return nil
        }
        var numBytesEncrypted: size_t = 0
        let options = CCOptions(kCCOptionPKCS7Padding)
        let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
            plain.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        options,
                        keyBytes.baseAddress!,
                        keyLength,
                        cryptBytes.baseAddress!,
                        dataBytes.baseAddress!,
                        plain.count,
                        cryptBytes.baseAddress! + ivSize,
                        cryptLength - ivSize,
                        &numBytesEncrypted
                    )
                }
            }
        }
        guard cryptStatus == kCCSuccess else {
            return nil
        }
        cryptData.count = numBytesEncrypted + ivSize
        return cryptData
    }
    
    class func DecryptData(chipter: Data, key: Data) -> Data? {
        let keyLength = key.count
        guard keyLength == kCCKeySizeAES256 else {
            return nil
        }
        let ivSize = kCCBlockSizeAES128
        let clearLength = size_t(chipter.count - ivSize)
        guard clearLength > 0 else {
            return nil
        }
        var clearData = Data(count: clearLength)
        var numBytesDecrypted: size_t = 0
        let options = CCOptions(kCCOptionPKCS7Padding)
        let cryptStatus = clearData.withUnsafeMutableBytes { clearBytes in
            chipter.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        options,
                        keyBytes.baseAddress!,
                        keyLength,
                        dataBytes.baseAddress!,
                        dataBytes.baseAddress! + ivSize,
                        clearLength,
                        clearBytes.baseAddress!,
                        clearLength,
                        &numBytesDecrypted
                    )
                }
            }
        }
        guard cryptStatus == kCCSuccess else {
            return nil
        }
        clearData.count = numBytesDecrypted
        return clearData
    }
    
    class func pbkdf2(password: String, salt: Data) -> Data {
        let iterations = UInt32(100000)
        let hashedLength = kCCKeySizeAES256
        var hashed = Data(count: hashedLength)
        let saltBuffer = [UInt8](salt)

        let result = hashed.withUnsafeMutableBytes { data in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                 password, password.count,
                                 saltBuffer, saltBuffer.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                 iterations,
                                 data.bindMemory(to: UInt8.self).baseAddress!, hashedLength)
        }

        guard result == kCCSuccess else { fatalError("pbkdf2 error") }
        return hashed
    }
    
    func decodeCommand(local: CloneData) -> (String, Data)? {
        guard local.active == 1 else {
            return nil
        }
        guard local.board == boardId else {
            return nil
        }
        guard let cmd = local.cmd, let stroke = local.stroke else {
            return nil
        }
        guard let cmdData = RemoteData.DecompressData(src: cmd, key: keyBytes) else {
            return nil
        }
        guard let cmdstr = String(bytes: cmdData, encoding: .utf8) else {
            return nil
        }
        guard let strokeData = RemoteData.DecompressData(src: stroke, key: keyBytes) else {
            return nil
        }
        return (cmdstr, strokeData)
    }
    
    func writeCommand(cmd: String, data: Data, finish: @escaping (Bool?)->Void) -> String? {
        guard let str = RemoteData.ComressData(src: data, key: keyBytes) else {
            return nil
        }
        guard let cmdstr = RemoteData.ComressData(src: cmd.data(using: .utf8)!, key: keyBytes) else {
            return nil
        }

        let newRecord = CKRecord(recordType: "Board")
        newRecord["board"] = boardId
        newRecord["time"] = Date()
        newRecord["stroke"] = str
        newRecord["cmd"] = cmdstr
        newRecord["active"] = 1

        RemoteData.isValidBoard(boardId: boardId, keyBytes: keyBytes) { exist, valid in
            guard let exist = exist else {
                finish(nil)
                return
            }
            guard exist, valid else {
                finish(false)
                return
            }

            let operation = CKModifyRecordsOperation(recordsToSave: [newRecord], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInteractive
            operation.perRecordCompletionBlock = { record, error in
                if let error = error {
                    print(error.localizedDescription)
                    print(error as Any)
                    return
                }
                RemoteClone.addRecord(remote: record)
            }
            operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                
                guard operationError == nil else {
                    print(operationError?.localizedDescription as Any)
                    print(operationError as Any)
                    return
                }
            }
            RemoteData.boardDatabase.add(operation)
        }
        
        return newRecord.recordID.recordName
    }

    func deleteCommand(record: CKRecord) {
        record["active"] = 0
        record["time"] = Date()
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInteractive
        operation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print(error.localizedDescription)
                print(error as Any)
                return
            }
            RemoteClone.modifyRecord(remote: record)
        }
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            guard operationError == nil else {
                print(operationError?.localizedDescription as Any)
                print(operationError as Any)
                return
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func undeleteCommand(record: CKRecord) {
        record["active"] = 1
        record["time"] = Date()
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInteractive
        operation.perRecordCompletionBlock = { record, error in
            if let error = error {
                print(error.localizedDescription)
                print(error as Any)
                return
            }
            RemoteClone.modifyRecord(remote: record)
        }
        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            
            guard operationError == nil else {
                print(operationError?.localizedDescription as Any)
                print(operationError as Any)
                return
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func deleteCommand(recordId: String) {
        let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "recordID == %@", CKRecord.ID(recordName: recordId)))
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .userInteractive
        operation.recordFetchedBlock = { record in
            self.deleteCommand(record: record)
        }
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
                print(error as Any)
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func undeleteCommand(recordId: String) {
        let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "recordID == %@", CKRecord.ID(recordName: recordId)))
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .userInteractive
        operation.recordFetchedBlock = { record in
            self.undeleteCommand(record: record)
        }
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
                print(error as Any)
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func readStroke(from: Date, finish: @escaping ()->Void, cursor: CKQueryOperation.Cursor? = nil) {
        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        }
        else {
            let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "(board == %@) && (time >= %@)", boardId, from as NSDate))
            query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            operation = CKQueryOperation(query: query)
        }
        operation.qualityOfService = .userInteractive
        operation.recordFetchedBlock = { record in
            RemoteClone.modifyRecord(remote: record)
        }
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
                print(error as Any)
            }
            if let cursor = cursor {
                self.readStroke(from: from, finish: finish, cursor: cursor)
            }
            else {
                finish()
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func readAllStroke(keepInit: Bool, finish: @escaping ([CKRecord.ID])->Void, cursor: CKQueryOperation.Cursor? = nil) {
        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        }
        else {
            if keepInit {
                let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "board == %@ && cmd != %@", boardId, "init"))
                query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                operation = CKQueryOperation(query: query)
            }
            else {
                let query = CKQuery(recordType: "Board", predicate: NSPredicate(format: "board == %@", boardId))
                query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                operation = CKQueryOperation(query: query)
            }
        }
        var ret: [CKRecord.ID] = []
        operation.recordFetchedBlock = { record in
            ret += [record.recordID]
        }
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
                print(error as Any)
            }
            if let cursor = cursor {
                self.readAllStroke(keepInit: keepInit, finish: { ret2 in
                    ret += ret2
                    finish(ret)
                }, cursor: cursor)
            }
            else {
                finish(ret)
            }
        }
        RemoteData.boardDatabase.add(operation)
    }
    
    func destoryAllStroke() {
        let t = Date()
        deleteImages(before: t)
        readAllStroke(keepInit: true) { ids in
            guard let str = RemoteData.ComressData(src: "clear all".data(using: .utf8)!, key: self.keyBytes) else {
                return
            }
            guard let cmdstr = RemoteData.ComressData(src: "cls".data(using: .utf8)!, key: self.keyBytes) else {
                return
            }

            let newRecord = CKRecord(recordType: "Board")
            newRecord["board"] = self.boardId
            newRecord["time"] = t
            newRecord["stroke"] = str
            newRecord["cmd"] = cmdstr
            newRecord["active"] = 1

            DispatchQueue.global().async {
                for id in ids {
                    RemoteClone.deleteRecord(remoteId: id.recordName)
                }
            }
            
            if ids.count > 400 {
                let r = (ids.count - 1) / 400
                for i in 0..<r {
                    let del = ids[i*400..<(i+1)*400]
                    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: Array(del))
                    operation.savePolicy = .allKeys
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                        
                        guard operationError == nil else {
                            print(operationError?.localizedDescription as Any)
                            print(operationError as Any)
                            return
                        }
                    }
                    RemoteData.boardDatabase.add(operation)
                }
                
                let del = ids[r*400..<ids.count]
                let operation = CKModifyRecordsOperation(recordsToSave: [newRecord], recordIDsToDelete: Array(del))
                operation.savePolicy = .allKeys
                operation.perRecordCompletionBlock = { record, error in
                    if let error = error {
                        print(error.localizedDescription)
                        print(error as Any)
                        return
                    }
                    RemoteClone.addRecord(remote: record)
                }
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
            else {
                let operation = CKModifyRecordsOperation(recordsToSave: [newRecord], recordIDsToDelete: ids)
                operation.savePolicy = .allKeys
                operation.perRecordCompletionBlock = { record, error in
                    if let error = error {
                        print(error.localizedDescription)
                        print(error as Any)
                        return
                    }
                    RemoteClone.addRecord(remote: record)
                }
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
        }
    }
    
    func destoryBoard() {
        deleteImages(before: Date())
        readAllStroke(keepInit: false) { ids in
            DispatchQueue.global().async {
                for id in ids {
                    RemoteClone.deleteRecord(remoteId: id.recordName)
                }
            }
            
            if ids.count > 400 {
                let r = (ids.count - 1) / 400
                for i in 0..<r {
                    let del = ids[i*400..<(i+1)*400]
                    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: Array(del))
                    operation.savePolicy = .allKeys
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                        
                        guard operationError == nil else {
                            print(operationError?.localizedDescription as Any)
                            print(operationError as Any)
                            return
                        }
                    }
                    RemoteData.boardDatabase.add(operation)
                }
                
                let del = ids[r*400..<ids.count]
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: Array(del))
                operation.savePolicy = .allKeys
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
            else {
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                operation.savePolicy = .allKeys
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
        }
    }
    
    func subscribe(finish: (()->Void)? = nil) {
        let subscription = CKQuerySubscription(recordType: "Board", predicate: NSPredicate(format: "board == %@", boardId), options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldBadge = true
        subscription.notificationInfo = notificationInfo
        
        let modifyOperation = CKModifySubscriptionsOperation()
        modifyOperation.subscriptionsToSave = [subscription]
        modifyOperation.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            if let error = error {
                print("error occurred: \(error)")
            }

            guard let savedSubscriptions = savedSubscriptions else {
                print("subscribe: null")
                finish?()
                return
            }
            for s in savedSubscriptions {
                print("subscribe \(s.subscriptionID)")
            }
            finish?()
        }
        RemoteData.boardDatabase.add(modifyOperation)
    }
    
    func unsubscribe(finish: (()->Void)? = nil) {
        RemoteData.boardDatabase.fetchAllSubscriptions { subscriptions, error in
            if let error = error {
                print("error occurred: \(error)")
            }
            
            guard let subscriptions = subscriptions else {
                print("unsubscribe: null")
                finish?()
                return
            }
            
            let modifyOperation = CKModifySubscriptionsOperation()
            modifyOperation.subscriptionIDsToDelete = subscriptions.map { $0.subscriptionID }
            modifyOperation.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
                if let error = error {
                    print("error occurred: \(error)")
                }
                guard let deletedSubscriptions = deletedSubscriptions else {
                    print("subscribe: null")
                    finish?()
                    return
                }
                for s in deletedSubscriptions {
                    print("unsubscribe \(s)")
                }
                finish?()
            }
            
            RemoteData.boardDatabase.add(modifyOperation)
        }
    }
    
    func resetBadge() {
        let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)
        badgeResetOperation.modifyBadgeCompletionBlock = { error in
            if let error = error {
                print("error occurred: \(error)")
            }
            else {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
        }
        CKContainer(identifier: "iCloud.info.lithium03.whiteboard").add(badgeResetOperation)
    }
    
    
    func addImage(image: UIImage, finish: @escaping (Bool?)->Void) -> String? {
        guard let data = image.pngData() else {
            return nil
        }
        guard let encryptedData = RemoteData.EncryptData(plain: data, key: keyBytes) else {
            return nil
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try encryptedData.write(to: url)
        }
        catch {
            print("Error info: \(error)")
            return nil
        }
        let ckAsset = CKAsset(fileURL: url)
        
        let newRecord = CKRecord(recordType: "Image")
        newRecord["board"] = boardId
        newRecord["time"] = Date()
        newRecord["image"] = ckAsset

        let finish: (Bool?)->Void = { success in
            try? FileManager.default.removeItem(at: url)
            finish(success)
        }
        
        RemoteData.isValidBoard(boardId: boardId, keyBytes: keyBytes) { exist, valid in
            guard let exist = exist else {
                finish(nil)
                return
            }
            guard exist, valid else {
                finish(false)
                return
            }

            let operation = CKModifyRecordsOperation(recordsToSave: [newRecord], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInteractive
            operation.perRecordCompletionBlock = { record, error in
                if let error = error {
                    print(error.localizedDescription)
                    print(error as Any)
                    return
                }
            }
            operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                
                guard operationError == nil else {
                    print(operationError?.localizedDescription as Any)
                    print(operationError as Any)
                    return
                }
                finish(true)
            }
            RemoteData.boardDatabase.add(operation)
        }
        
        return newRecord.recordID.recordName
    }
    
    func getImage(recordId: String, finish: @escaping (UIImage?)->Void) {
        RemoteData.isValidBoard(boardId: boardId, keyBytes: keyBytes) { exist, valid in
            guard let exist = exist else {
                finish(nil)
                return
            }
            guard exist, valid else {
                finish(nil)
                return
            }

            let operation = CKFetchRecordsOperation(recordIDs: [
                CKRecord.ID(recordName: recordId)])
            operation.qualityOfService = .userInteractive
            operation.fetchRecordsCompletionBlock = { records, error in
                if let error = error {
                    print(error.localizedDescription)
                    print(error as Any)
                    finish(nil)
                    return
                }
                guard let records = records else {
                    finish(nil)
                    return
                }
                guard let record = records[CKRecord.ID(recordName: recordId)] else {
                    finish(nil)
                    return
                }
                guard let ckAsset = record["image"] as? CKAsset else {
                    finish(nil)
                    return
                }
                guard let fileUrl = ckAsset.fileURL else {
                    finish(nil)
                    return
                }
                guard let data = try? Data(contentsOf: fileUrl) else {
                    finish(nil)
                    return
                }
                guard let decryptedData = RemoteData.DecryptData(chipter: data, key: self.keyBytes) else {
                    finish(nil)
                    return
                }
                finish(UIImage(data: decryptedData))
            }
            RemoteData.boardDatabase.add(operation)
        }
    }
    
    func readImageId(before: Date, finish: @escaping ([CKRecord.ID])->Void, cursor: CKQueryOperation.Cursor? = nil) {
        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        }
        else {
            let query = CKQuery(recordType: "Image", predicate: NSPredicate(format: "board == %@ && time <= %@", boardId, before as NSDate))
            query.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            operation = CKQueryOperation(query: query)
        }
        var ret: [CKRecord.ID] = []
        operation.recordFetchedBlock = { record in
            ret += [record.recordID]
        }
        operation.queryCompletionBlock = { (cursor, error) in
            if error != nil {
                print(error?.localizedDescription as Any)
                print(error as Any)
            }
            if let cursor = cursor {
                self.readImageId(before: before, finish: { ret2 in
                    ret += ret2
                    finish(ret)
                }, cursor: cursor)
            }
            else {
                finish(ret)
            }
        }
        RemoteData.boardDatabase.add(operation)
    }

    func deleteImages(before: Date) {
        readImageId(before: before) { ids in
            DispatchQueue.global().async {
                for id in ids {
                    PasteImageCache.deleteImage(recordId: id.recordName)
                }
            }
            
            if ids.count > 400 {
                let r = (ids.count - 1) / 400
                for i in 0..<r {
                    let del = ids[i*400..<(i+1)*400]
                    let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: Array(del))
                    operation.savePolicy = .allKeys
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                        
                        guard operationError == nil else {
                            print(operationError?.localizedDescription as Any)
                            print(operationError as Any)
                            return
                        }
                    }
                    RemoteData.boardDatabase.add(operation)
                }
                
                let del = ids[r*400..<ids.count]
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: Array(del))
                operation.savePolicy = .allKeys
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
            else {
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                operation.savePolicy = .allKeys
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
                    
                    guard operationError == nil else {
                        print(operationError?.localizedDescription as Any)
                        print(operationError as Any)
                        return
                    }
                }
                RemoteData.boardDatabase.add(operation)
            }
        }
    }
}
