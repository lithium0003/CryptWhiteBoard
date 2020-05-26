//
//  DrawObject.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/05.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

class DrawObject: Equatable {

    static let group = DispatchGroup()
    
    static func == (lhs: DrawObject, rhs: DrawObject) -> Bool {
        return lhs.id == rhs.id
    }

    class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {
        if cmd.starts(with: "pen") || cmd.starts(with: "apen") || cmd.starts(with: "spen") || cmd.starts(with: "sfpen") {
            return Line.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "delete") {
            return DeleteLine.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "objectDeleter") {
            return ObjectDeleter.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "cut") || cmd.starts(with: "selection") {
            return SelectionObject.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "objects") {
            return ObjectSelector.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "text") {
            return TextObject.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        if cmd.starts(with: "image") {
            return ImageObject.create(recordId: recordId, data: data, cmd: cmd, container: container)
        }
        return nil
    }
    
    // MARK: Properties

    private let id = UUID()
    
    var recordId: String?
    
    var objects: [DrawObject] = []
    var deltaVector: CGVector = .zero
    var rotateCenter: CGPoint = .zero
    var rotateAngle: CGFloat = 0

    var rawHitPath: UIBezierPath {
        return UIBezierPath()
    }

    var hitPath: UIBezierPath {
        return rawHitPath
    }
    
    var transform: CGAffineTransform = .identity
    
    var rect: CGRect {
        let path = hitPath
        return path.bounds
    }
    
    var rawRect: CGRect {
        let path = rawHitPath
        return path.bounds
    }
    
    func objectSelectionInside(point: CGPoint) -> Bool {
        return false
    }

    var objectSelectionOutlineImage: UIImage {
        let path = rawHitPath
        return areaImage(path: path, color: .white)
    }

    init() {
    }
    
    init?(recordId: String?, data: Data, cmd: String) {
        return nil
    }
    
    func getLocationData() -> Data {
        return .init()
    }
    
    @discardableResult
    func save(writer: (_ cmd: String, _ data: Data, _ finish: @escaping (Bool?)->Void) -> String?, finish: ((Bool?)->Void)? = nil) -> String? {
        return nil
    }
    
    func drawInContext(_ context: CGContext) {
    }
    
    func drawFrozenContext(in context: CGContext) {
    }
    
    func dragObject(delta: CGVector) -> CGRect {
        return .null
    }

    func areaImage(path: UIBezierPath, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: rawRect)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.setFillColor(color.cgColor)
            rendererContext.cgContext.addPath(path.cgPath)
            rendererContext.cgContext.fillPath()
            rendererContext.cgContext.restoreGState()
        })
    }
    
    func convertGray(_ inImage: UIImage)->CGImage? {
        guard let cgImage = inImage.cgImage else {
            return nil
        }
        
        guard let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 8, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), renderingIntent: .defaultIntent) else {
            return nil
        }
        guard let sourceBuffer = try? vImage_Buffer(cgImage: cgImage, format: format) else {
            return nil
        }
        defer {
            sourceBuffer.free()
        }
        return try? sourceBuffer.createCGImage(format: format)
    }
    
}
