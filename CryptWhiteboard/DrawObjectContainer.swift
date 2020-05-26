//
//  DrawObjectContainer.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/11.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

class DrawObjectContaier {
    let boardId: String
    private let imageCache: ImageCache
    let windowRect: CGRect
    let windowScale: CGFloat
    private var semaphore = DispatchSemaphore(value: 1)
    private let frozenContext: CGContext
    private(set) var frozenImage: CGImage? {
        didSet {
            if oldValue != frozenImage, let image = frozenImage {
                onImageChanged?(image)
            }
        }
    }
    var onImageChanged: ((CGImage)->Void)?
    var onNeedUpdate: (()->Void)?
    var progressAnimate: ((Float?, String)->Void)? 
    var objectWriter: ((String, Data, @escaping (Bool?) -> Void) -> String?)?
    var finishChecker: ((Bool?) -> Void)?
    var imageGetter: ((String, @escaping (UIImage?)->Void)->Void)?
    
    private var cachedHash: String = ""
    private var finishedObjects: [DrawObject] = []
    private var pendingObjects: [String] = []
    private var maybeRemoveHash: [String] = []
    
    var snapshotImage: UIImage? {
        guard let frozenImage = frozenImage else {
            return nil
        }
        let renderer = UIGraphicsImageRenderer(size: windowRect.size)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.draw(frozenImage, in: windowRect)
        })
    }
    
    init(rect: CGRect, scale: CGFloat, boardId: String, writer: ((String, Data, @escaping (Bool?) -> Void) -> String?)?, imageGetter: ((String, @escaping (UIImage?)->Void)->Void)?, finishChecker: ((Bool?) -> Void)? = nil) {
        windowRect = rect
        windowScale = scale
        self.boardId = boardId
        imageCache = ImageCache(board: boardId)
        objectWriter = writer
        self.imageGetter = imageGetter
        self.finishChecker = finishChecker
        
        var size = windowRect.size
        size.width *= scale
        size.height *= scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let context: CGContext = CGContext(data: nil,
                                           width: Int(size.width),
                                           height: Int(size.height),
                                           bitsPerComponent: 8,
                                           bytesPerRow: 0,
                                           space: colorSpace,
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        context.concatenate(transform)
        frozenContext = context
    }
    
    func hitTestObject(point: CGPoint) -> [DrawObject] {
        var result = [DrawObject]()
        let fixedFinishedObjects = finishedObjects.filter({
            if let id = $0.recordId, pendingObjects.contains(id) {
                return false
            }
            return true
        })
        for obj in fixedFinishedObjects {
            if obj.objectSelectionInside(point: point) {
                result.append(obj)
            }
        }
        return result
    }
    
    func hitTestSelection(selection: SelectionObject) -> [DrawObject] {
        var result = [DrawObject]()
        let fixedFinishedObjects = finishedObjects.filter({
            if let id = $0.recordId, pendingObjects.contains(id) {
                return false
            }
            return true
        })
        guard let mask = selection.convertGray(selection.objectSelectionOutlineImage) else {
            return []
        }
        for obj in fixedFinishedObjects {
            if selection.hitPath.bounds.contains(obj.rect), !obj.rect.isEmpty {
                let renderer = UIGraphicsImageRenderer(bounds: obj.rect)
                let targetIm = renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.fill(.infinite)
                    rendererContext.cgContext.clip(to: selection.rect, mask: mask)
                    rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
                    rendererContext.cgContext.addPath(obj.hitPath.cgPath)
                    rendererContext.cgContext.fillPath()
                })
                guard let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 8, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), renderingIntent: .defaultIntent) else {
                    return []
                }
                guard let cgImage = targetIm.cgImage, var originalBuffer = try? vImage_Buffer(cgImage: cgImage, format: format) else {
                    return []
                }
                defer {
                    originalBuffer.free()
                }

                var histogramBin = [vImagePixelCount](repeating: 0, count: 256)
                vImageHistogramCalculation_Planar8(&originalBuffer, &histogramBin, vImage_Flags(kvImageNoFlags))

                if histogramBin.first! > 0 {
                    result.append(obj)
                }
            }
        }
        return result
    }
    
    @discardableResult
    func useContext(timeout: DispatchTime? = nil, execute: @escaping (CGContext)->Void) -> Bool {
        if let timeout = timeout {
            guard semaphore.wait(timeout: timeout) == .success else {
                return false
            }
        }
        else {
            semaphore.wait()
        }
        DispatchQueue.global().async {
            execute(self.frozenContext)
            self.frozenImage = self.frozenContext.makeImage()
            self.semaphore.signal()
        }
        return true
    }
    
    func removeFinishedObject(recordId: String) {
        let removed = finishedObjects.filter({ $0.recordId != recordId })
        if finishedObjects.count != removed.count {
            var fixedFinishedObjects = finishedObjects.filter({
                if let id = $0.recordId, pendingObjects.contains(id) {
                    return false
                }
                return true
            })
            var hash = ""
            for obj in fixedFinishedObjects {
                if let id = obj.recordId {
                    hash = ImageCache.getKey(prev: hash, current: id)
                }
                if !maybeRemoveHash.contains(hash) {
                    maybeRemoveHash += [hash]
                }
            }
            finishedObjects = removed
            hash = ""
            fixedFinishedObjects = finishedObjects.filter({
                if let id = $0.recordId, pendingObjects.contains(id) {
                    return false
                }
                return true
            })
            for obj in fixedFinishedObjects {
                if let id = obj.recordId {
                    hash = ImageCache.getKey(prev: hash, current: id)
                }
                maybeRemoveHash = maybeRemoveHash.filter({ $0 != hash})
            }
            cachedHash = hash
            
            print("delete unused cache \(maybeRemoveHash.count)")
            for h in maybeRemoveHash {
                imageCache.deleteImage(key: h)
            }
            maybeRemoveHash = []
        }
    }

    @discardableResult
    func registerObject(newItem: DrawObject) -> String? {
        guard let writer = objectWriter else {
            return nil
        }
        return newItem.save(writer: writer, finish: finishChecker)
    }
    
    func addActiveObject(newItem: DrawObject) {
        finishedObjects += [newItem]
        if let id = newItem.recordId {
            cachedHash = ImageCache.getKey(prev: cachedHash, current: id)
        }
        print("active \(finishedObjects.count)")
        semaphore.wait()
        newItem.drawFrozenContext(in: frozenContext)
        frozenImage = frozenContext.makeImage()
        semaphore.signal()
        if finishedObjects.count % 10 == 0 {
            let hash = cachedHash
            DispatchQueue.global().async {
                self.storeFrozenContext(image: self.frozenImage, hash: hash)
            }
        }
        onNeedUpdate?()
    }

    func addFinishedObject(newItem: DrawObject) {
        finishedObjects += [newItem]
        if let id = newItem.recordId {
            cachedHash = ImageCache.getKey(prev: cachedHash, current: id)
        }
        print("store \(finishedObjects.count)")
    }

    func retrieveObject(recordId: String) -> DrawObject? {
        let data = finishedObjects.first(where: { $0.recordId == recordId })
        setPendingObject(recordId: recordId, pending: true)
        return data
    }
    
    func setPendingObject(recordId: String, pending: Bool) {
        if pending {
            if finishedObjects.firstIndex(where: { $0.recordId == recordId }) != nil, pendingObjects.firstIndex(where: { $0 == recordId }) == nil {
                pendingObjects.append(recordId)
            }
        }
        else {
            if finishedObjects.firstIndex(where: { $0.recordId == recordId }) != nil, let idx = pendingObjects.firstIndex(where: { $0 == recordId }) {
                pendingObjects.remove(at: idx)
            }
        }
    }
    
    private func storeFrozenContext(image: CGImage?, hash: String) {
        maybeRemoveHash = maybeRemoveHash.filter({ $0 != hash})
        print("save Image", hash)
        imageCache.setImage(key: hash, image: image)
    }

    func frozenContextDraw() {
        var hash = ""
        var hashCache: [String] = []
        let fixedFinishedObjects = finishedObjects.filter({
            if let id = $0.recordId, pendingObjects.contains(id) {
                return false
            }
            return true
        })
        for obj in fixedFinishedObjects {
            if let id = obj.recordId {
                hash = ImageCache.getKey(prev: hash, current: id)
            }
            hashCache += [hash]
            maybeRemoveHash = maybeRemoveHash.filter({ $0 != hash})
        }
        cachedHash = hash
        let group = DispatchGroup()
        var hitkey = -1
        var hitImage: CGImage?
        for (i,h) in hashCache.enumerated().reversed() {
            group.enter()
            imageCache.getImage(key: h) { image in
                if let image = image {
                    hitImage = image
                    hitkey = i
                }
                group.leave()
            }
            group.wait()
            if hitkey >= 0 {
                break
            }
        }
        print("delete unused cache \(maybeRemoveHash.count)")
        for h in maybeRemoveHash {
            imageCache.deleteImage(key: h)
        }
        maybeRemoveHash = []
        
        print("image: ",hitkey)
        semaphore.wait()
        frozenContext.clear(windowRect)
        semaphore.signal()
        
        if let im = hitImage {
            semaphore.wait()
            frozenContext.draw(im, in: windowRect)
            semaphore.signal()
        }
        
        for (idx,(obj,key)) in zip(fixedFinishedObjects, hashCache).enumerated() {
            if idx <= hitkey {
                continue
            }
            let p = Float(idx)/Float(fixedFinishedObjects.count)
            let str = "\(idx) / \(fixedFinishedObjects.count) " + String(format: "(%.2f%%)", p * 100)
            progressAnimate?(p, str)
            semaphore.wait()
            obj.drawFrozenContext(in: frozenContext)
            let group = DispatchGroup()
            if idx % 10 == 0 {
                group.enter()
                imageCache.setImage(key: key, image: frozenContext.makeImage()) {
                    group.leave()
                }
            }
            group.notify(queue: .global()) {
                self.semaphore.signal()
            }
        }

        semaphore.wait()
        frozenImage = frozenContext.makeImage()
        semaphore.signal()
        onNeedUpdate?()
    }
    
    func cls(time: Date?) {
        var hash = ""
        let fixedFinishedObjects = finishedObjects.filter({
            if let id = $0.recordId, pendingObjects.contains(id) {
                return false
            }
            return true
        })
        for obj in fixedFinishedObjects {
            if let id = obj.recordId {
                hash = ImageCache.getKey(prev: hash, current: id)
                if !maybeRemoveHash.contains(hash) {
                    maybeRemoveHash += [hash]
                }
            }
        }
        cachedHash = ""
        finishedObjects.removeAll()
        pendingObjects.removeAll()
        imageCache.clearImages(before: time)
    }
    
    func clearAll() {
        imageCache.clearImages()
        finishedObjects.removeAll()
        pendingObjects.removeAll()
        cachedHash = ""
        frozenContextDraw()
    }
}
