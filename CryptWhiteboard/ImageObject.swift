//
//  ImageObject.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/23.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit

class ImageObject: DrawObject {

    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {
        let imObj = ImageObject(recordId: recordId, data: data, cmd: cmd)
        group.enter()
        imObj?.loadImage(container: container) { success in
            group.leave()
        }
        return imObj
    }
    
    var image: UIImage?
    var imageId: String
    var keepAspectRatio = true
    private var point1: CGPoint?
    private var point2: CGPoint?
    private var activeIdx: Int?

    func loadImage(container: DrawObjectContaier, finish: @escaping (Bool)->Void) {
        image = PasteImageCache.getImage(recordId: imageId)
        if image != nil {
            finish(true)
            return
        }
        guard let getter = container.imageGetter else {
            finish(false)
            return
        }
        getter(imageId) { [weak self] retIm in
            guard let retIm = retIm else {
                finish(false)
                return
            }
            self?.image = retIm
            finish(true)
        }
    }
    
    func setFitSize(center: CGPoint) {
        guard var size = image?.size else {
            return
        }
        if size.width > 2000 {
            size = CGSize(width: 2000, height: 2000 * size.height / size.width)
        }
        if size.height > 2000 {
            size = CGSize(width: 2000 * size.width / size.height, height: 2000)
        }

        point1 = center
        point2 = center
        point1!.x -= size.width / 2
        point2!.x += size.width / 2
        point1!.y -= size.height / 2
        point2!.y += size.height / 2
    }
    
    override var rawHitPath: UIBezierPath {
        if let p1 = point1, let p2 = point2 {
            return UIBezierPath(rect: CGRect(origin: p1, size: CGSize(width: p2.x - p1.x, height: p2.y - p1.y)))
        }
        return UIBezierPath()
    }
    
    override func objectSelectionInside(point: CGPoint) -> Bool {
        return hitPath.contains(point)
    }

    init(imageId: String) {
        self.imageId = imageId
        super.init()
    }

    override init?(recordId: String?, data: Data, cmd: String) {
        imageId = ""
        super.init()
        self.recordId = recordId
        
        let commands = cmd.split(separator: ";")
        for c in commands {
            if c.starts(with: "keepratio=") {
                if c.starts(with: "keepratio=1") {
                    keepAspectRatio = true
                }
            }
        }
        
        var nextData = data
        let x = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Double.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Double>.size)
        let y = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Double.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Double>.size)
        let w = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Double.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Double>.size)
        let h = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Double.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Double>.size)
        let targetRect = CGRect(x: x, y: y, width: w, height: h)
        point1 = targetRect.origin
        point2 = CGPoint(x: point1!.x + targetRect.width, y: point1!.y + targetRect.height)
        
        imageId = String(bytes: nextData, encoding: .utf8) ?? ""
    }
    
    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {
        
        var cmd = "image"
        if keepAspectRatio {
            cmd += ";keepratio=1"
        }
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }
    
    override func getLocationData() -> Data {
        var data = Data()
        var targetRect = CGRect.null
        if let p1 = point1, let p2 = point2 {
            targetRect = CGRect(origin: p1, size: CGSize(width: p2.x - p1.x, height: p2.y - p1.y))
        }
        var x = Double(targetRect.origin.x)
        var y = Double(targetRect.origin.y)
        var w = Double(targetRect.width)
        var h = Double(targetRect.height)
        data.append(Data(bytes: &x, count: MemoryLayout<Double>.size))
        data.append(Data(bytes: &y, count: MemoryLayout<Double>.size))
        data.append(Data(bytes: &w, count: MemoryLayout<Double>.size))
        data.append(Data(bytes: &h, count: MemoryLayout<Double>.size))
        
        data.append(imageId.data(using: .utf8)!)
        return data
    }
    
    override func drawInContext(_ context: CGContext) {
        guard let p1 = point1, let p2 = point2 else {
            return
        }
        
        let targetRect = CGRect(origin: p1, size: CGSize(width: p2.x - p1.x, height: p2.y - p1.y))
        let points = [p1, p2, .init(x: p1.x, y: p2.y), .init(x: p2.x, y: p1.y)]

        UIGraphicsPushContext(context)
        image?.draw(in: targetRect)
        UIGraphicsPopContext()

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(2.5)
        context.setLineDash(phase: 0, lengths: [4.0, 4.0])
        context.setStrokeColor(UIColor.black.cgColor)
        context.stroke(targetRect)
        context.restoreGState()

        context.saveGState()
        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        for p in points {
            context.addArc(center: p, radius: 4.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.setFillColor(UIColor.black.cgColor)
        for p in points {
            context.addArc(center: p, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.restoreGState()
    }
    
    override func drawFrozenContext(in context: CGContext) {
        guard let p1 = point1, let p2 = point2 else {
            return
        }
        let targetRect = CGRect(origin: p1, size: CGSize(width: p2.x - p1.x, height: p2.y - p1.y))

        UIGraphicsPushContext(context)
        image?.draw(in: targetRect)
        UIGraphicsPopContext()
    }
    
    func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        activeIdx = nil
        let p = touch.preciseLocation(in: view)
        if let p1 = point1, let p2 = point2 {
            let points = [p1, p2, .init(x: p1.x, y: p2.y), .init(x: p2.x, y: p1.y)]
            for (idx, point) in points.enumerated() {
                let rect = CGRect(origin: point, size: .zero)
                if rect.insetBy(dx: -15, dy: -15).contains(p) {
                    activeIdx = idx
                    break
                }
            }
            return rect.insetBy(dx: -10, dy: -10)
        }
        point1 = touch.preciseLocation(in: view)
        return CGRect(x: point1!.x, y: point1!.y, width: 0, height: 0)
    }

    func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        let oldRect = rect
        guard let aidx = activeIdx else {
            point2 = touch.preciseLocation(in: view)
            if keepAspectRatio, let size = image?.size {
                let r = size.height / size.width
                guard let p1 = point1, let p2 = point2 else {
                    return rect.union(oldRect).insetBy(dx: -10, dy: -10)
                }
                point2 = CGPoint(x: p2.x, y: (p2.x - p1.x) * r + p1.y)
            }
            return rect.union(oldRect).insetBy(dx: -10, dy: -10)
        }
        guard let p1 = point1, let p2 = point2 else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let p = touch.preciseLocation(in: view)
        switch aidx {
        case 0:
            point1 = p
        case 1:
            point2 = p
        case 2:
            point1 = .init(x: p.x, y: p1.y)
            point2 = .init(x: p2.x, y: p.y)
        case 3:
            point1 = .init(x: p1.x, y: p.y)
            point2 = .init(x: p.x, y: p2.y)
        default:
            break
        }
        if keepAspectRatio, let size = image?.size {
            let r = size.height / size.width
            guard let p1 = point1, let p2 = point2 else {
                return rect.union(oldRect).insetBy(dx: -10, dy: -10)
            }
            if aidx != 3{
                point2 = CGPoint(x: p2.x, y: (p2.x - p1.x) * r + p1.y)
            }
            else {
                point1 = CGPoint(x: p1.x, y: p2.y - (p2.x - p1.x) * r)
            }
        }
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }
    
    func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        if cancel {
            return self.cancel()
        }
        let oldRect = rect
        guard let aidx = activeIdx else {
            point2 = touch.preciseLocation(in: view)
            if keepAspectRatio, let size = image?.size {
                let r = size.height / size.width
                guard let p1 = point1, let p2 = point2 else {
                    return rect.union(oldRect).insetBy(dx: -10, dy: -10)
                }
                point2 = CGPoint(x: p2.x, y: (p2.x - p1.x) * r + p1.y)
            }
            return rect.union(oldRect).insetBy(dx: -10, dy: -10)
        }
        guard let p1 = point1, let p2 = point2 else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let p = touch.preciseLocation(in: view)
        switch aidx {
        case 0:
            point1 = p
        case 1:
            point2 = p
        case 2:
            point1 = .init(x: p.x, y: p1.y)
            point2 = .init(x: p2.x, y: p.y)
        case 3:
            point1 = .init(x: p1.x, y: p.y)
            point2 = .init(x: p.x, y: p2.y)
        default:
            break
        }
        activeIdx = nil
        if keepAspectRatio, let size = image?.size {
            let r = size.height / size.width
            guard let p1 = point1, let p2 = point2 else {
                return rect.union(oldRect).insetBy(dx: -10, dy: -10)
            }
            if aidx != 3{
                point2 = CGPoint(x: p2.x, y: (p2.x - p1.x) * r + p1.y)
            }
            else {
                point1 = CGPoint(x: p1.x, y: p2.y - (p2.x - p1.x) * r)
            }
        }
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }
    
    func cancel() -> CGRect {
        let oldRect = rect
        point1 = nil
        point2 = nil
        return oldRect.insetBy(dx: -10, dy: -10)
    }

    override func dragObject(delta: CGVector) -> CGRect {
        let oldRect = rect.insetBy(dx: -10, dy: -10)
        if let p1 = point1 {
            point1 = CGPoint(x: p1.x + delta.dx, y: p1.y + delta.dy)
        }
        if let p2 = point2 {
            point2 = CGPoint(x: p2.x + delta.dx, y: p2.y + delta.dy)
        }
        return rect.insetBy(dx: -10, dy: -10).union(oldRect)
    }
    
    func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        let p = touch.preciseLocation(in: view)
        guard let p1 = point1, let p2 = point2 else {
            return false
        }
        for point in [p1, p2, .init(x: p1.x, y: p2.y), .init(x: p2.x, y: p1.y)] {
            let rect = CGRect(origin: point, size: .zero)
            if rect.insetBy(dx: -15, dy: -15).contains(p) {
                return true
            }
        }
        return false
    }

}
