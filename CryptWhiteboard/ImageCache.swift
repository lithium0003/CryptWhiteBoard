//
//  ImageCache.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/06.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import CommonCrypto
import UIKit
import CoreData

class ImageCache {
    
    let board: String
    
    init(board: String) {
        self.board = board
    }
    
    private lazy var viewContext = {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }()
        
    class func sha512(data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA512($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
    
    class func getKey(prev: String, current: String) -> String {
        let content = prev + current
        let hash = sha512(data: content.data(using: .utf8)!)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func getImage(key: String, finish: @escaping (CGImage?)->Void) {
        if Thread.isMainThread {
            guard let viewContext = self.viewContext else {
                DispatchQueue.global().async {
                    finish(nil)
                }
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (key == %@)", self.board, key)
            if let fetchedData = try? viewContext.fetch(fetchRequest), let item = fetchedData.first, let data = item.image {
                DispatchQueue.global().async {
                    finish(UIImage(data: data)?.cgImage)
                }
            }
            else {
                DispatchQueue.global().async {
                    finish(nil)
                }
            }
            return
        }
        DispatchQueue.main.async {
            guard let viewContext = self.viewContext else {
                DispatchQueue.global().async {
                    finish(nil)
                }
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (key == %@)", self.board, key)
            if let fetchedData = try? viewContext.fetch(fetchRequest), let item = fetchedData.first, let data = item.image {
                DispatchQueue.global().async {
                    finish(UIImage(data: data)?.cgImage)
                }
            }
            else {
                DispatchQueue.global().async {
                    finish(nil)
                }
            }
        }
    }
    
    func setImage(key: String, image: CGImage?, finish: (()->Void)? = nil) {
        if Thread.isMainThread {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            if let image = image {
                let newRecord = CaptureData(context: viewContext)
                newRecord.key = key
                newRecord.image = UIImage(cgImage: image).pngData()
                newRecord.board = self.board
                newRecord.time = Date()
                try? viewContext.save()
            }
            return
        }
        DispatchQueue.main.async {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            if let image = image {
                let newRecord = CaptureData(context: viewContext)
                newRecord.key = key
                newRecord.image = UIImage(cgImage: image).pngData()
                newRecord.board = self.board
                newRecord.time = Date()
                try? viewContext.save()
            }
        }
    }
    
    func deleteImage(key: String, finish: (()->Void)? = nil) {
        if Thread.isMainThread {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (key == %@)", self.board, key)
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
            }
        }
        DispatchQueue.main.async {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(board == %@) && (key == %@)", self.board, key)
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
            }
        }
    }
    
    func clearImages(before: Date? = nil, finish: (()->Void)? = nil) {
        if Thread.isMainThread {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            if let before = before {
                fetchRequest.predicate = NSPredicate(format: "(board == %@) && (time < %@)", self.board, before as NSDate)
            }
            else {
                fetchRequest.predicate = NSPredicate(format: "board == %@", self.board)
            }
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
            return
        }
        DispatchQueue.main.async {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = self.viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            if let before = before {
                fetchRequest.predicate = NSPredicate(format: "(board == %@) && (time < %@)", self.board, before as NSDate)
            }
            else {
                fetchRequest.predicate = NSPredicate(format: "board == %@", self.board)
            }
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
        }
    }

    class func clearAll(finish: (()->Void)? = nil) {
        let viewContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        if Thread.isMainThread {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(value: true)
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
            return
        }
        DispatchQueue.main.async {
            defer {
                DispatchQueue.global().async {
                    finish?()
                }
            }
            guard let viewContext = viewContext else {
                return
            }
            let fetchRequest:NSFetchRequest<CaptureData> = CaptureData.fetchRequest()
            fetchRequest.predicate = NSPredicate(value: true)
            if let fetchedData = try? viewContext.fetch(fetchRequest) {
                for item in fetchedData {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
            return
        }
    }
}
