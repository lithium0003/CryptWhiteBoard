//
//  SelectionObject.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/05.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

// MARK:- SelectionObject

class SelectionObject: DrawObject {

    weak var container: DrawObjectContaier?

    var clear: Bool = false
    var fillColor: UIColor = .clear
    var drawColor: UIColor = .clear
    var drawWidth: CGFloat = 0.0
    var threshold: Float = 0.0 {
        didSet {
            onThresholdChanged()
        }
    }
    func onThresholdChanged() {
    }

    var calcurationStart: ((Bool)->Void)?
    var selectionUpdated: ((CGRect)->Void)?
    
    var bounds: CGRect = .null
    var scale: CGFloat = 0.0
    

    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {
        var recvData = data
        if cmd.starts(with: "cut") {
            recvData = Data()
            var t: Int = 1
            recvData.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
            recvData.append(data)
        }
        
        var DRed: CGFloat = 0
        var DGreen: CGFloat = 0
        var DBlue: CGFloat = 0
        var DAlpha: CGFloat = 0
        var FRed: CGFloat = 0
        var FGreen: CGFloat = 0
        var FBlue: CGFloat = 0
        var FAlpha: CGFloat = 0
        var clear: Bool = false
        var penWidth: CGFloat = 0.0
        let commands = cmd.starts(with: "cut") ? "selection;clear=1".split(separator: ";") : cmd.split(separator: ";")
        for c in commands {
            if c.starts(with: "clear=") {
                if c.starts(with: "clear=1") {
                    clear = true
                }
            }
            if c.starts(with: "DR=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("DR=") != nil {
                    DRed = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "FR=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("FR=") != nil {
                    FRed = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "DG=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("DG=") != nil {
                    DGreen = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "FG=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("FG=") != nil {
                    FGreen = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "DB=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("DB=") != nil {
                    DBlue = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "FB=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("FB=") != nil {
                    FBlue = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "DA=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("DA=") != nil {
                    DAlpha = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "FA=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("FA=") != nil {
                    FAlpha = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "DW=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("DW=") != nil {
                    penWidth = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
        }

        let selection = SelectionObject.create(data: recvData, container: container)
        selection.drawColor = UIColor(red: DRed, green: DGreen, blue: DBlue, alpha: DAlpha)
        selection.drawWidth = penWidth
        selection.fillColor = UIColor(red: FRed, green: FGreen, blue: FBlue, alpha: FAlpha)
        selection.clear = clear
        selection.recordId = recordId
        return selection
    }

    class func create(data: Data, container: DrawObjectContaier) -> SelectionObject {
        let t = data.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        let newobject = { () -> SelectionObject in
            switch t {
            case 0:
                return MultiSelection(container: container, data: data.advanced(by: MemoryLayout<Int>.size))
            case 1:
                return RectSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 2:
                return PenSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 3:
                return LineSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 4:
                return CircleSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 5:
                return EllipseSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 6:
                return SplineSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            case 7:
                return MagicSelection(data: data.advanced(by: MemoryLayout<Int>.size))
            default:
                return SelectionObject(data: data.advanced(by: MemoryLayout<Int>.size))
            }
        }()
        newobject.bounds = container.windowRect
        newobject.scale = container.windowScale
        newobject.container = container
        return newobject
    }

    override init() {
        super.init()
    }
    
    init(bounds: CGRect, scale: CGFloat) {
        super.init()
        self.bounds = bounds
        self.scale = scale
    }
    
    init(data: Data) {
        super.init()
    }
    
    func cloneSelection() -> SelectionObject {
        guard let container = container else {
            fatalError()
        }
        let stroke = getLocationData()
        return SelectionObject.create(data: stroke, container: container)
    }
    
    var plusSelectionPath: UIBezierPath {
        return .init()
    }
    
    override var rawHitPath: UIBezierPath {
        return plusSelectionPath
    }
    
    func finishSelect() {
    }
    
    func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        return .null
    }

    func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        return .null
    }
    
    func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        return .null
    }
    
    func cancel() -> CGRect {
        return .null
    }
    
    func isInside(_ touch: UITouch, in view: UIView) -> Bool {
        let point = touch.preciseLocation(in: view)
        let line = hitPath.cgPath.copy(strokingWithWidth: 10.0, lineCap: .round, lineJoin: .round, miterLimit: 10.0)
        return hitPath.contains(point) || line.contains(point)
    }

    func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        return false
    }

    var didSelected: Bool {
        return true
    }
    
    func copy(from image: CGImage) -> UIImage? {
        return nil
    }
    
    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {

        var Red: CGFloat = 0
        var Green: CGFloat = 0
        var Blue: CGFloat = 0
        var Alpha: CGFloat = 0
        fillColor.getRed(&Red, green: &Green, blue: &Blue, alpha: &Alpha)
        var cmd = String(format: "selection;FR=%f;FG=%f;FB=%f;FA=%f", Red, Green, Blue, Alpha)
        drawColor.getRed(&Red, green: &Green, blue: &Blue, alpha: &Alpha)
        cmd += String(format: ";DR=%f;DG=%f;DB=%f;DA=%f;DW=%.1f", Red, Green, Blue, Alpha, drawWidth)
        if clear {
            cmd += ";clear=1"
        }
        
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }
}

// MARK:- ComplexSelectionObject

class ComplexSelectionObject: SelectionObject {

    var selIndicateColor = UIColor.blue.withAlphaComponent(0.25)
    
    var minusSelectionPath: UIBezierPath {
        return .init()
    }

    var allSelectionPath: UIBezierPath {
        let path = plusSelectionPath
        path.append(minusSelectionPath)
        return path
    }
    
    override var rawHitPath: UIBezierPath {
        return allSelectionPath
    }
    
    override var objectSelectionOutlineImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: rawRect)
        return renderer.image(actions: { rendererContext in
            UIGraphicsPushContext(rendererContext.cgContext)
            let path = plusSelectionPath
            areaImage(path: path, color: .white).draw(at: rawRect.origin)
            if !minusSelectionPath.isEmpty {
                let path = minusSelectionPath
                areaImage(path: path, color: .black).draw(at: rawRect.origin)
            }
            UIGraphicsPopContext()
        })
    }

    override func objectSelectionInside(point: CGPoint) -> Bool {
        let path1 = minusSelectionPath
        if path1.contains(point) {
            return false
        }
        let path2 = plusSelectionPath
        if path2.contains(point) {
            return true
        }
        return false
    }
    
    var selectionWhiteImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
            let path1 = plusSelectionPath
            rendererContext.cgContext.addPath(path1.cgPath)
            rendererContext.cgContext.fillPath()
            rendererContext.cgContext.restoreGState()
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            let path2 = minusSelectionPath
            rendererContext.cgContext.addPath(path2.cgPath)
            rendererContext.cgContext.fillPath()
            rendererContext.cgContext.restoreGState()
        })
    }

    func drawPaingInternal(_ context: CGContext, color: UIColor) {
        let fillImage = { ()->UIImage? in
            let renderer = UIGraphicsImageRenderer(bounds: self.bounds)
            let im = renderer.image(actions: { rendererContext in
                rendererContext.cgContext.setFillColor(color.cgColor)
                rendererContext.cgContext.fill(.infinite)
            })
            guard let cgImage = im.cgImage else {
                return nil
            }
            guard let mask = convertGray(selectionWhiteImage) else {
                return nil
            }
            guard let result = cgImage.masking(mask) else {
                return nil
            }
            return UIImage(cgImage: result, scale: self.scale, orientation: .up)
        }()
        
        UIGraphicsPushContext(context)
        fillImage?.draw(at: .zero)
        UIGraphicsPopContext()
    }

    override func drawInContext(_ context: CGContext) {
        drawPaingInternal(context, color: selIndicateColor)
        
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [3.0, 5.0])
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let path = allSelectionPath
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()
    }

    var outlineBounds: CGRect {
        let path = plusSelectionPath
        path.append(minusSelectionPath)
        return path.bounds.insetBy(dx: -drawWidth, dy: -drawWidth)
    }
    var outlineMaskBase: UIImage?
    func setOutlineMaskBase() {
        let renderer = UIGraphicsImageRenderer(bounds: outlineBounds)
        outlineMaskBase = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)

            let plusPath = plusSelectionPath
            let minusPath = minusSelectionPath

            let plusedge = UIBezierPath(cgPath: plusPath.cgPath.copy(strokingWithWidth: drawWidth, lineCap: .round, lineJoin: .round, miterLimit: 10.0))
            let minusedge = UIBezierPath(cgPath: minusPath.cgPath.copy(strokingWithWidth: drawWidth, lineCap: .round, lineJoin: .round, miterLimit: 10.0))

            let internalBlackImage: (_ edge: UIBezierPath, _ path: UIBezierPath) -> UIImage = { (e,p) in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                let im = renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
                    rendererContext.cgContext.addPath(p.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                    
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.clear.cgColor)
                    rendererContext.cgContext.setBlendMode(.clear)
                    rendererContext.cgContext.addPath(e.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                })
                return UIImage(cgImage: im.cgImage!, scale: self.scale, orientation: .downMirrored)
            }

            let internalWhiteImage: (_ edge: UIBezierPath, _ path: UIBezierPath) -> UIImage = { (e,p) in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                let im = renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.addPath(p.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                    
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.clear.cgColor)
                    rendererContext.cgContext.setBlendMode(.clear)
                    rendererContext.cgContext.addPath(e.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                })
                return UIImage(cgImage: im.cgImage!, scale: self.scale, orientation: .downMirrored)
            }
            
            let imPosMask = { () -> UIImage in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                return renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.fill(.infinite)
                    UIGraphicsPushContext(rendererContext.cgContext)
                    internalBlackImage(plusedge,plusPath).draw(at: .zero)
                    internalBlackImage(minusedge,minusPath).draw(at: .zero)
                    UIGraphicsPopContext()
                })
            }()

            let imNegMask = { () -> UIImage in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                return renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.fill(.infinite)
                    UIGraphicsPushContext(rendererContext.cgContext)
                    internalWhiteImage(plusedge,plusPath).draw(at: .zero)
                    internalBlackImage(minusedge,minusPath).draw(at: .zero)
                    UIGraphicsPopContext()
                })
            }()
            
            guard let posmask = convertGray(imPosMask) else {
                return
            }
            guard let negmask = convertGray(imNegMask) else {
                return
            }

            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: self.outlineBounds, mask: posmask)
            rendererContext.cgContext.addPath(plusPath.cgPath)
            rendererContext.cgContext.setStrokeColor(UIColor.white.cgColor)
            rendererContext.cgContext.setLineWidth(self.drawWidth)
            rendererContext.cgContext.setLineCap(.round)
            rendererContext.cgContext.setLineJoin(.round)
            rendererContext.cgContext.strokePath()
            rendererContext.cgContext.restoreGState()

            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: self.outlineBounds, mask: negmask)
            rendererContext.cgContext.addPath(minusPath.cgPath)
            rendererContext.cgContext.setStrokeColor(UIColor.white.cgColor)
            rendererContext.cgContext.setLineWidth(self.drawWidth)
            rendererContext.cgContext.setLineCap(.round)
            rendererContext.cgContext.setLineJoin(.round)
            rendererContext.cgContext.strokePath()
            rendererContext.cgContext.restoreGState()
        })
    }
    var outlineMask: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)
            rendererContext.cgContext.translateBy(x: 0, y: bounds.height)
            rendererContext.cgContext.scaleBy(x: 1.0, y: -1.0)
            UIGraphicsPushContext(rendererContext.cgContext)
            if outlineMaskBase == nil {
                setOutlineMaskBase()
            }
            outlineMaskBase?.draw(at: self.outlineBounds.origin)
            UIGraphicsPopContext()
        })
    }
    
    var imFlipMask: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)
            rendererContext.cgContext.translateBy(x: 0, y: self.bounds.height)
            rendererContext.cgContext.scaleBy(x: 1.0, y: -1.0)
            let plusPath = plusSelectionPath
            UIGraphicsPushContext(rendererContext.cgContext)
            areaImage(path: plusPath, color: .white).draw(at: rect.origin)
            if !minusSelectionPath.isEmpty {
                let minusPath = minusSelectionPath
                areaImage(path: minusPath, color: .black).draw(at: rect.origin)
            }
            UIGraphicsPopContext()
        })
    }
    
    override func drawFrozenContext(in context: CGContext) {

        if clear {
            guard let flipMask = convertGray(imFlipMask) else {
                return
            }

            context.saveGState()
            context.clip(to: bounds, mask: flipMask)
            context.setBlendMode(.copy)
            context.setFillColor(fillColor.cgColor)
            context.fill(bounds)
            context.restoreGState()
        }
        else {
            guard let flipMask = convertGray(imFlipMask) else {
                return
            }

            context.saveGState()
            context.clip(to: bounds, mask: flipMask)
            context.setFillColor(fillColor.cgColor)
            context.fill(bounds)
            context.restoreGState()
        }
        
        guard let mask = convertGray(outlineMask) else {
            return
        }

        context.saveGState()
        context.clip(to: bounds, mask: mask)
        context.setFillColor(drawColor.cgColor)
        context.fill(bounds)
        context.restoreGState()
    }

    override func copy(from image: CGImage) -> UIImage? {
        guard !plusSelectionPath.isEmpty else {
            return nil
        }

        guard let flipMask = convertGray(imFlipMask) else {
            return nil
        }
        
        let plusPath = plusSelectionPath
        
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let im = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: bounds, mask: flipMask)
            rendererContext.cgContext.draw(image, in: bounds)
            rendererContext.cgContext.restoreGState()
        })
        if let croped = im.cgImage?.cropping(to: plusPath.bounds) {
            return UIImage(cgImage: croped)
        }
        else {
            return nil
        }
    }
}

// MARK:- SimpleSelectionObject

class SimpleSelectionObject: ComplexSelectionObject {
    
    override func drawFrozenContext(in context: CGContext) {
        let plusPath = plusSelectionPath

        var alpha = CGFloat(0)
        fillColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        if clear {
            context.saveGState()
            context.addPath(plusPath.cgPath)
            context.clip()
            context.setBlendMode(.copy)
            context.addPath(plusPath.cgPath)
            context.setFillColor(fillColor.cgColor)
            context.fill(bounds)
            context.restoreGState()
        }
        else {
            context.saveGState()
            context.addPath(plusPath.cgPath)
            context.setFillColor(fillColor.cgColor)
            context.fillPath()
            context.restoreGState()
        }
        
        drawColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        if alpha > 0 {
            context.saveGState()
            context.addPath(plusPath.cgPath)
            context.setStrokeColor(drawColor.cgColor)
            context.setLineWidth(drawWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            context.restoreGState()
        }
    }
}


// MARK:- MultiSelection

class MultiSelection: ComplexSelectionObject {
    
    var activeIdx: Int?
    var addObjectIdx: [Int] = []
    var delObjectIdx: [Int] = []

    init(container: DrawObjectContaier) {
        super.init()
        self.container = container
        self.bounds = container.windowRect
        self.scale = container.windowScale
    }

    init(container: DrawObjectContaier, data: Data) {
        super.init()
        self.container = container
        self.bounds = container.windowRect
        self.scale = container.windowScale

        var nextData = data
        while !nextData.isEmpty {
            let (next, add, id) = convertData(data: nextData)
            nextData = next
            guard let sel = container.retrieveObject(recordId: id) else {
                continue
            }
            if add > 0 {
                objects += [sel]
                addObjectIdx += [objects.count - 1]
            }
            else if add < 0 {
                objects += [sel]
                delObjectIdx += [objects.count - 1]
            }
        }
    }

    private func convertData(data: Data) -> (Data, Int, String) {
        let a = data.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        var nextData = data.advanced(by: MemoryLayout<Int>.size)
        let count = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Int>.size)
        let idData = nextData.subdata(in: 0..<count)
        let id = String(bytes: idData, encoding: .utf8)!
        if nextData.count <= count {
            nextData = Data()
        }
        else {
            nextData = nextData.advanced(by: count)
        }
        return (nextData, a, id)
    }
    
    override func getLocationData() -> Data {
        guard let container = container else {
            fatalError()
        }
        
        var data = Data()
        var t = Int(0)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        
        for (idx, obj) in objects.enumerated() {
            guard let sel = obj as? SelectionObject else {
                continue
            }
            if addObjectIdx.contains(idx) {
                var a = Int(1)
                data.append(Data(bytes: &a, count: MemoryLayout<Int>.size))
            }
            else if delObjectIdx.contains(idx) {
                var a = Int(-1)
                data.append(Data(bytes: &a, count: MemoryLayout<Int>.size))
            }
            else {
                continue
            }
            guard let recordId = container.registerObject(newItem: sel) else {
                continue
            }
            let idData = recordId.data(using: .utf8)!
            var count = idData.count
            data.append(Data(bytes: &count, count: MemoryLayout<Int>.size))
            data.append(idData)
        }
        
        return data
    }

    override func cloneSelection() -> SelectionObject {
        guard let container = container else {
            fatalError()
        }
        let newObject = MultiSelection(container: container)
        for (i, obj) in objects.enumerated() {
            guard let sel = obj as? SelectionObject else {
                continue
            }
            newObject.objects += [sel.cloneSelection()]
            if addObjectIdx.contains(i) {
                newObject.addObjectIdx += [newObject.objects.count - 1]
            }
            if delObjectIdx.contains(i) {
                newObject.delObjectIdx += [newObject.objects.count - 1]
            }
        }
        return newObject
    }
    
    override func dragObject(delta: CGVector) -> CGRect {
        var updateRect = CGRect.null
        if let aIdx = activeIdx, let sel = objects[aIdx] as? SelectionObject {
            updateRect = sel.dragObject(delta: delta)
        }
        else {
            for obj in objects {
                guard let sel = obj as? SelectionObject else {
                    continue
                }
                updateRect = updateRect.union(sel.dragObject(delta: delta))
            }
        }
        return updateRect.insetBy(dx: -10, dy: -10)
    }

    override var plusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        for idx in addObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            path.append(sel.plusSelectionPath)
            if !sel.minusSelectionPath.isEmpty {
                path.append(sel.minusSelectionPath.reversing())
            }
        }
        return path
    }

    override var minusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        for idx in delObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            path.append(sel.plusSelectionPath)
            if !sel.minusSelectionPath.isEmpty {
                path.append(sel.minusSelectionPath.reversing())
            }
        }
        return path
    }

    override var rawHitPath: UIBezierPath {
        var path = allSelectionPath
        if let aIdx = activeIdx, let sel = objects[aIdx] as? SelectionObject {
            path = sel.rawHitPath
        }
        return path
    }
    
    override var objectSelectionOutlineImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: rawRect)
        return renderer.image(actions: { rendererContext in
            UIGraphicsPushContext(rendererContext.cgContext)
            for idx in addObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                areaImage(path: path, color: .white).draw(at: rawRect.origin)
            }
            for idx in delObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                areaImage(path: path, color: .black).draw(at: rawRect.origin)
            }
            UIGraphicsPopContext()
        })
    }

    override func objectSelectionInside(point: CGPoint) -> Bool {
        for idx in delObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            let plusPath = sel.plusSelectionPath
            let minusPath = sel.minusSelectionPath
            if !minusPath.isEmpty, minusPath.contains(point) {
                continue
            }
            if plusPath.contains(point) {
                return false
            }
        }
        for idx in addObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            let plusPath = sel.plusSelectionPath
            let minusPath = sel.minusSelectionPath
            if !minusPath.isEmpty, minusPath.contains(point) {
                continue
            }
            if plusPath.contains(point) {
                return true
            }
        }
        return false
    }

    func addUnion(selection: SelectionObject) {
        objects += [selection]
        addObjectIdx += [objects.count - 1]
        activeIdx = objects.count - 1
    }

    func addRemove(selection: SelectionObject) {
        objects += [selection]
        delObjectIdx += [objects.count - 1]
        activeIdx = objects.count - 1
    }
    
    func delete(index: Int) {
        objects.remove(at: index)
        addObjectIdx = addObjectIdx.filter({ $0 != index}).map({ $0 < index ? $0 : $0 - 1 })
        delObjectIdx = delObjectIdx.filter({ $0 != index}).map({ $0 < index ? $0 : $0 - 1 })
    }
    
    override func finishSelect() {
        guard let aIdx = activeIdx else {
            return
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return
        }
        sel.finishSelect()
        activeIdx = nil
    }
    
    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        guard let aIdx = activeIdx, let sel = objects[aIdx] as? SelectionObject else {
            return false
        }
        return sel.continueEditing(touch, in: view)
    }

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        guard let aIdx = activeIdx else {
            return .null
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return .null
        }
        return rect.union(sel.beginTouch(touch, in: view)).insetBy(dx: -10, dy: -10)
    }
    
    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        guard let aIdx = activeIdx else {
            return .null
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return .null
        }
        return rect.union(sel.moveTouch(touch, in: view)).insetBy(dx: -10, dy: -10)
    }
    
    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        guard let aIdx = activeIdx else {
            return .null
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return .null
        }
        return rect.union(sel.finishTouch(touch, in: view, cancel: cancel)).insetBy(dx: -10, dy: -10)
    }
    
    override func cancel() -> CGRect {
        guard let aIdx = activeIdx else {
            return .null
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return .null
        }
        return rect.union(sel.cancel()).insetBy(dx: -10, dy: -10)
    }

    override var didSelected: Bool {
        guard let aIdx = activeIdx else {
            return true
        }
        guard let sel = objects[aIdx] as? SelectionObject else {
            return true
        }
        return sel.didSelected
    }
        
    override func drawInContext(_ context: CGContext) {
        if let aIdx = activeIdx, let sel = objects[aIdx] as? ComplexSelectionObject {
            sel.selIndicateColor = UIColor.red.withAlphaComponent(0.2)
            sel.drawInContext(context)
        }
        super.drawInContext(context)
    }
    
    override var selectionWhiteImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
            for idx in addObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                rendererContext.cgContext.addPath(path.cgPath)
                rendererContext.cgContext.fillPath()
            }
            rendererContext.cgContext.restoreGState()
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            for idx in delObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                rendererContext.cgContext.addPath(path.cgPath)
                rendererContext.cgContext.fillPath()
            }
            rendererContext.cgContext.restoreGState()
        })
    }

    var plusPaths: [UIBezierPath] {
        var paths = [UIBezierPath]()
        for idx in addObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            let path = UIBezierPath()
            path.append(sel.plusSelectionPath)
            if !sel.minusSelectionPath.isEmpty {
                path.append(sel.minusSelectionPath.reversing())
            }
            paths += [path]
        }
        return paths
    }
    
    var minusPaths: [UIBezierPath] {
        var paths = [UIBezierPath]()
        for idx in delObjectIdx {
            guard let sel = objects[idx] as? ComplexSelectionObject else {
                continue
            }
            let path = UIBezierPath()
            path.append(sel.plusSelectionPath)
            if !sel.minusSelectionPath.isEmpty {
                path.append(sel.minusSelectionPath.reversing())
            }
            paths += [path]
        }
        return paths
    }
    
    override var outlineBounds: CGRect {
        let path = UIBezierPath()
        for p in plusPaths {
            path.append(p)
        }
        for p in minusPaths {
            path.append(p)
        }
        return path.bounds.insetBy(dx: -drawWidth, dy: -drawWidth)
    }
    override func setOutlineMaskBase() {
        let renderer = UIGraphicsImageRenderer(bounds: outlineBounds)
        outlineMaskBase = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)

            var plusEdges = [UIBezierPath]()
            for path in plusPaths {
                plusEdges += [UIBezierPath(cgPath: path.cgPath.copy(strokingWithWidth: drawWidth, lineCap: .round, lineJoin: .round, miterLimit: 10.0))]
            }
            var minusEdges = [UIBezierPath]()
            for path in minusPaths {
                minusEdges += [UIBezierPath(cgPath: path.cgPath.copy(strokingWithWidth: drawWidth, lineCap: .round, lineJoin: .round, miterLimit: 10.0))]
            }

            let internalBlackImage: (_ edge: UIBezierPath, _ path: UIBezierPath) -> UIImage = { (e,p) in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                let im = renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
                    rendererContext.cgContext.addPath(p.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                    
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.clear.cgColor)
                    rendererContext.cgContext.setBlendMode(.clear)
                    rendererContext.cgContext.addPath(e.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                })
                return UIImage(cgImage: im.cgImage!, scale: self.scale, orientation: .downMirrored)
            }

            let internalWhiteImage: (_ edge: UIBezierPath, _ path: UIBezierPath) -> UIImage = { (e,p) in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                let im = renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.addPath(p.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                    
                    rendererContext.cgContext.saveGState()
                    rendererContext.cgContext.setFillColor(UIColor.clear.cgColor)
                    rendererContext.cgContext.setBlendMode(.clear)
                    rendererContext.cgContext.addPath(e.cgPath)
                    rendererContext.cgContext.fillPath()
                    rendererContext.cgContext.restoreGState()
                })
                return UIImage(cgImage: im.cgImage!, scale: self.scale, orientation: .downMirrored)
            }
            
            let imPosMask = { () -> UIImage in
                let renderer = UIGraphicsImageRenderer(bounds: outlineBounds)
                return renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                    rendererContext.cgContext.fill(.infinite)
                    UIGraphicsPushContext(rendererContext.cgContext)
                    for (p, e) in zip(plusPaths, plusEdges) {
                        internalBlackImage(e,p).draw(at: outlineBounds.origin)
                    }
                    for (p, e) in zip(minusPaths, minusEdges) {
                        internalBlackImage(e,p).draw(at: outlineBounds.origin)
                    }
                    UIGraphicsPopContext()
                })
            }()

            let imNegMask = { () -> UIImage in
                let renderer = UIGraphicsImageRenderer(bounds: self.outlineBounds)
                return renderer.image(actions: { rendererContext in
                    rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
                    rendererContext.cgContext.fill(.infinite)
                    UIGraphicsPushContext(rendererContext.cgContext)
                    for (p, e) in zip(plusPaths, plusEdges) {
                        internalWhiteImage(e,p).draw(at: outlineBounds.origin)
                    }
                    for (p, e) in zip(minusPaths, minusEdges) {
                        internalBlackImage(e,p).draw(at: outlineBounds.origin)
                    }
                    UIGraphicsPopContext()
                })
            }()
            
            guard let posmask = convertGray(imPosMask) else {
                return
            }
            guard let negmask = convertGray(imNegMask) else {
                return
            }
            
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: outlineBounds, mask: posmask)
            for p in plusPaths {
                rendererContext.cgContext.addPath(p.cgPath)
                rendererContext.cgContext.setStrokeColor(UIColor.white.cgColor)
                rendererContext.cgContext.setLineWidth(self.drawWidth)
                rendererContext.cgContext.setLineCap(.round)
                rendererContext.cgContext.setLineJoin(.round)
                rendererContext.cgContext.strokePath()
            }
            rendererContext.cgContext.restoreGState()

            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: self.outlineBounds, mask: negmask)
            for p in minusPaths {
                rendererContext.cgContext.addPath(p.cgPath)
                rendererContext.cgContext.setStrokeColor(UIColor.white.cgColor)
                rendererContext.cgContext.setLineWidth(self.drawWidth)
                rendererContext.cgContext.setLineCap(.round)
                rendererContext.cgContext.setLineJoin(.round)
                rendererContext.cgContext.strokePath()
            }
            rendererContext.cgContext.restoreGState()
        })
    }
    
    override var imFlipMask: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)
            rendererContext.cgContext.translateBy(x: 0, y: self.bounds.height)
            rendererContext.cgContext.scaleBy(x: 1.0, y: -1.0)
            UIGraphicsPushContext(rendererContext.cgContext)
            for idx in addObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                areaImage(path: path, color: .white).draw(at: rect.origin)
            }
            for idx in delObjectIdx {
                guard let sel = objects[idx] as? ComplexSelectionObject else {
                    continue
                }
                let path = UIBezierPath()
                path.append(sel.plusSelectionPath)
                if !sel.minusSelectionPath.isEmpty {
                    path.append(sel.minusSelectionPath.reversing())
                }
                areaImage(path: path, color: .black).draw(at: rect.origin)
            }
            UIGraphicsPopContext()
        })
    }

    override func copy(from image: CGImage) -> UIImage? {
        guard !plusSelectionPath.isEmpty else {
            return nil
        }

        guard let flipMask = convertGray(imFlipMask) else {
            return nil
        }

        guard let provider = flipMask.dataProvider else {
            return nil
        }
        guard let pixelData = provider.data else {
            return nil
        }

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let bytesPerPixel = flipMask.bitsPerPixel / 8
        let bytesPerRow = flipMask.bytesPerRow
        
        let areaMinX = Int(rect.minX * scale)
        let areaMinY = Int(rect.minY * scale)
        let areaMaxX = Int(rect.maxX * scale)
        let areaMaxY = Int(rect.maxY * scale)
        
        var minX = flipMask.width
        var maxX = 0
        var minY = flipMask.height
        var maxY = 0
        
        for y in areaMinY..<areaMaxY {
            for x in areaMinX..<areaMaxX {
                let pixelInfo: Int = bytesPerRow * (flipMask.height - y) + x * bytesPerPixel

                let r = data[pixelInfo]
                let g = data[pixelInfo+1]
                let b = data[pixelInfo+2]
                //let a = data[pixelInfo+3]
                
                if r == 0 && g == 0 && b == 0 {
                    continue
                }
                if x < minX {
                    minX = x
                }
                if x > maxX {
                    maxX = x
                }
                if y < minY {
                    minY = y
                }
                if y > maxY {
                    maxY = y
                }
            }
        }
        print(minX,maxX,minY,maxY)
        guard minX < maxX && minY < maxY else {
            return nil
        }
        
        let cliprect = CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale, width: CGFloat(maxX - minX) / scale, height: CGFloat(maxY - minY) / scale)
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let im = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: self.bounds, mask: flipMask)
            rendererContext.cgContext.draw(image, in: bounds)
            rendererContext.cgContext.restoreGState()
        })
        if let croped = im.cgImage?.cropping(to: cliprect) {
            return UIImage(cgImage: croped)
        }
        else {
            return nil
        }
    }
}

// MARK:- RectSelection

class RectSelection: SimpleSelectionObject {
    
    var point1: CGPoint?
    var point2: CGPoint?
    var activeIdx: Int?

    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init()
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        if strokePoints.count == 2 {
            point1 = strokePoints[0]
            point2 = strokePoints[1]
        }
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

    override var plusSelectionPath: UIBezierPath {
        guard let p1 = point1, let p2 = point2 else {
            return UIBezierPath()
        }
        return UIBezierPath(rect: CGRect(x: p1.x, y: p1.y, width: p2.x - p1.x, height: p2.y - p1.y))
    }
    
    override func getLocationData() -> Data {
        guard let p1 = point1, let p2 = point2 else {
            return .init()
        }

        var data = Data()
        var t = Int(1)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in [p1, p2] {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
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

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
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

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        let oldRect = rect
        guard let aidx = activeIdx else {
            point2 = touch.preciseLocation(in: view)
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
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        if cancel {
            return self.cancel()
        }
        let oldRect = rect
        guard let aidx = activeIdx else {
            point2 = touch.preciseLocation(in: view)
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
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }

    override func cancel() -> CGRect {
        let oldRect = rect
        point1 = nil
        point2 = nil
        return oldRect.insetBy(dx: -10, dy: -10)
    }
    
    override func drawInContext(_ context: CGContext) {
        super.drawInContext(context)
        
        guard let p1 = point1, let p2 = point2 else {
            return
        }
        let points = [p1, p2, .init(x: p1.x, y: p2.y), .init(x: p2.x, y: p1.y)]

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
}

// MARK:- PenSelection

class PenSelection: SimpleSelectionObject {
    
    var points: [CGPoint] = []
    
    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init()
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        points = strokePoints
    }
    
    override func dragObject(delta: CGVector) -> CGRect {
        let oldRect = rect.insetBy(dx: -10, dy: -10)

        var fixedPoints: [CGPoint] = []
        for i in 0..<points.count {
            let p = CGPoint(x: points[i].x + delta.dx, y: points[i].y + delta.dy)
            fixedPoints += [p]
        }
        points = fixedPoints
        return rect.insetBy(dx: -10, dy: -10).union(oldRect)
    }

    override var plusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        if let p0 = points.first {
            path.move(to: p0)
        }
        for p in points {
            path.addLine(to: p)
        }
        return path
    }
    
    override func getLocationData() -> Data {
        guard points.count > 0 else {
            return .init()
        }

        var data = Data()
        var t = Int(2)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in points {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        points = [touch.preciseLocation(in: view)]
        return CGRect(x: points[0].x, y: points[0].y, width: 0, height: 0).insetBy(dx: -10, dy: -10)
    }

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        let p = touch.preciseLocation(in: view)
        points += [p]
        return rect.insetBy(dx: -10, dy: -10)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        let p = touch.preciseLocation(in: view)
        points += [p]
        if cancel {
            let oldRect = rect
            points = []
            return oldRect.insetBy(dx: -10, dy: -10)
        }
        return rect.insetBy(dx: -10, dy: -10)
    }

    override func cancel() -> CGRect {
        let oldRect = rect
        points = []
        return oldRect.insetBy(dx: -10, dy: -10)
    }
}

// MARK:- LineSelection

class LineSelection: SimpleSelectionObject {
    
    var points: [CGPoint] = []
    var activeIdx: Int?
    var isOpen = true
    
    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init(data: data)
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        points = strokePoints
        if let p0 = points.first, let pe = points.last {
            isOpen = p0 != pe
        }
        else {
            isOpen = false
        }
        if !isOpen {
            points = points.dropLast()
        }
    }
    
    override func getLocationData() -> Data {
        guard points.count > 0 else {
            return .init()
        }

        var data = Data()
        var t = Int(3)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in points {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        if !isOpen, let p = points.first {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override var didSelected: Bool {
        return !isOpen
    }
    
    override func dragObject(delta: CGVector) -> CGRect {
        let oldRect = rect.insetBy(dx: -10, dy: -10)

        var fixedPoints: [CGPoint] = []
        for i in 0..<points.count {
            let p = CGPoint(x: points[i].x + delta.dx, y: points[i].y + delta.dy)
            fixedPoints += [p]
        }
        points = fixedPoints
        return rect.insetBy(dx: -10, dy: -10).union(oldRect)
    }

    override var plusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        guard let p0 = points.first else {
            return .init()
        }
        path.move(to: p0)
        for p in points {
            path.addLine(to: p)
        }
        if !isOpen {
            path.close()
        }
        return path
    }
    
    override var rawHitPath: UIBezierPath {
        guard isOpen else {
            return plusSelectionPath
        }
        guard points.count > 1 else {
            return .init()
        }
        
        var pointsA: [CGPoint] = []
        var pointsB: [CGPoint] = []

        var angle: CGFloat = 0
        for i in 0..<points.count-1 {
            let p1 = points[i]
            let p2 = points[i+1]
            angle = atan2(p2.y - p1.y, p2.x - p1.x)
            pointsA += [CGPoint(x: p1.x + 10 * cos(angle + .pi / 2), y: p1.y + 10 * sin(angle + .pi / 2))]
            pointsB += [CGPoint(x: p1.x + 10 * cos(angle - .pi / 2), y: p1.y + 10 * sin(angle - .pi / 2))]
            pointsA += [CGPoint(x: p2.x + 10 * cos(angle + .pi / 2), y: p2.y + 10 * sin(angle + .pi / 2))]
            pointsB += [CGPoint(x: p2.x + 10 * cos(angle - .pi / 2), y: p2.y + 10 * sin(angle - .pi / 2))]
        }
        let p1 = points.last!
        pointsA += [CGPoint(x: p1.x + 10 * cos(angle + .pi / 2), y: p1.y + 10 * sin(angle + .pi / 2))]
        pointsB += [CGPoint(x: p1.x + 10 * cos(angle - .pi / 2), y: p1.y + 10 * sin(angle - .pi / 2))]

        let path = UIBezierPath()
        path.move(to: pointsA.first!)
        for p in pointsA {
            path.addLine(to: p)
        }
        for p in pointsB.reversed() {
            path.addLine(to: p)
        }
        path.close()
        
        return path
    }
    
    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        let p = touch.preciseLocation(in: view)
        for point in points {
            let rect = CGRect(origin: point, size: .zero)
            if rect.insetBy(dx: -15, dy: -15).contains(p) {
                return true
            }
        }
        return false
    }
    
    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        if points.isEmpty {
            points = [touch.preciseLocation(in: view)]
            activeIdx = points.count
            isOpen = true
            points += [touch.preciseLocation(in: view)]
            return rect.insetBy(dx: -10, dy: -10)
        }
        else {
            activeIdx = nil
            let p = touch.preciseLocation(in: view)
            for (idx, point) in points.enumerated() {
                let rect = CGRect(origin: point, size: .zero)
                if rect.insetBy(dx: -15, dy: -15).contains(p) {
                    activeIdx = idx
                    break
                }
            }
            if let aidx = activeIdx {
                if isOpen && points.count > 2 && aidx == 0 {
                    isOpen = false
                    return rect.insetBy(dx: -10, dy: -10)
                }
                points[aidx] = p
                return rect.insetBy(dx: -10, dy: -10)
            }
            activeIdx = points.count
            points += [p]
            return rect.insetBy(dx: -10, dy: -10)
        }
    }

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        guard let aidx = activeIdx else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let oldrect = rect.insetBy(dx: -10, dy: -10)
        let p = touch.preciseLocation(in: view)
        points[aidx] = p
        return rect.insetBy(dx: -10, dy: -10).union(oldrect)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        if cancel {
            return self.cancel()
        }

        let p = touch.preciseLocation(in: view)
        guard let aidx = activeIdx else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let oldrect = rect.insetBy(dx: -10, dy: -10)
        points[aidx] = p
        activeIdx = nil
        return rect.insetBy(dx: -10, dy: -10).union(oldrect)
    }

    override func cancel() -> CGRect {
        let rect = self.rect
        points = []
        activeIdx = nil
        isOpen = true
        return rect.insetBy(dx: -10, dy: -10)
    }
    
    override func drawInContext(_ context: CGContext) {
        super.drawInContext(context)
        
        context.saveGState()
        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        for p in points {
            context.addArc(center: p, radius: 4.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.setFillColor(UIColor.black.cgColor)
        for (i, p) in points.enumerated() {
            if isOpen && i == points.count - 1 {
                context.setFillColor(UIColor.systemRed.cgColor)
            }
            context.addArc(center: p, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.restoreGState()
    }
}

// MARK:- CircleSelection

class CircleSelection: SimpleSelectionObject {
    
    var point1: CGPoint?
    var point2: CGPoint?
    
    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init()
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        if strokePoints.count == 2 {
            point1 = strokePoints[0]
            point2 = strokePoints[1]
        }
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

    override var plusSelectionPath: UIBezierPath {
        guard let p1 = point1, let p2 = point2 else {
            return .init()
        }
        let r = sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y))
        let path = UIBezierPath(arcCenter: p1, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        return path
    }
        
    override func getLocationData() -> Data {
        guard let p1 = point1, let p2 = point2 else {
            return .init()
        }

        var data = Data()
        var t = Int(4)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in [p1, p2] {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        guard let p1 = point1, let p2 = point2 else {
            return false
        }
        let r = sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y))
        let p = touch.preciseLocation(in: view)
        if abs(sqrt((p.x - p1.x) * (p.x - p1.x) + (p.y - p1.y) * (p.y - p1.y)) - r) < 10 {
            return true
        }
        return false
    }

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        if point1 != nil {
            let oldRect = rect
            point2 = touch.preciseLocation(in: view)
            return rect.union(oldRect).insetBy(dx: -10, dy: -10)
        }
        point1 = touch.preciseLocation(in: view)
        return CGRect(x: point1!.x, y: point1!.y, width: 0, height: 0)
    }

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        var oldrect: CGRect = .null
        if point1 != nil, point2 != nil {
            oldrect = rect.insetBy(dx: -10, dy: -10)
        }
        point2 = touch.preciseLocation(in: view)
        return rect.insetBy(dx: -10, dy: -10).union(oldrect)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        var oldrect: CGRect = .null
        if point1 != nil, point2 != nil {
            oldrect = rect.insetBy(dx: -10, dy: -10)
        }
        point2 = touch.preciseLocation(in: view)
        if cancel {
            point1 = nil
            point2 = nil
        }
        if point1 != nil, point2 != nil {
            return rect.insetBy(dx: -10, dy: -10).union(oldrect)
        }
        return oldrect
    }

    override func cancel() -> CGRect {
        var oldrect: CGRect = .null
        if point1 != nil, point2 != nil {
            oldrect = rect.insetBy(dx: -10, dy: -10)
        }
        point1 = nil
        point2 = nil
        return oldrect
    }
    
    override func drawInContext(_ context: CGContext) {
        super.drawInContext(context)
        
        guard let p1 = point1 else {
            return
        }
        
        context.saveGState()
        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.addArc(center: p1, radius: 4.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()
        context.setFillColor(UIColor.black.cgColor)
        context.addArc(center: p1, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()
        context.restoreGState()
    }
}


// MARK:- EllipseSelection

class EllipseSelection: SimpleSelectionObject {
    
    var point1: CGPoint?
    var point2: CGPoint?
    var activeIdx: Int?
    var anchorPoint: CGPoint?
    
    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init()
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        if strokePoints.count == 2 {
            point1 = strokePoints[0]
            point2 = strokePoints[1]
        }
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

    override var plusSelectionPath: UIBezierPath {
        guard let p1 = point1, let p2 = point2 else {
            return .init()
        }
        let path = UIBezierPath(ovalIn: CGRect(x: p1.x, y: p1.y, width: p2.x - p1.x, height: p2.y - p1.y))
        return path
    }
    
    override func getLocationData() -> Data {
        guard let p1 = point1, let p2 = point2 else {
            return .init()
        }

        var data = Data()
        var t = Int(5)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in [p1, p2] {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        guard let p1 = point1, let p2 = point2 else {
            return false
        }
        let p = touch.preciseLocation(in: view)
        let a1 = CGPoint(x: min(p1.x, p2.x), y: min(p1.y, p2.y))
        let a2 = CGPoint(x: max(p1.x, p2.x), y: max(p1.y, p2.y))
        let path = UIBezierPath(ovalIn: CGRect(x: a1.x - 10, y: a1.y - 10, width: a2.x - a1.x + 20, height: a2.y - a1.y + 20))
        path.append(UIBezierPath(ovalIn: CGRect(x: a1.x + 10, y: a1.y + 10, width: a2.x - a1.x -  20, height: a2.y - a1.y - 20)))
        path.usesEvenOddFillRule = true
        return path.contains(p)
    }

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        guard let p1 = point1, let p2 = point2 else {
            point1 = touch.preciseLocation(in: view)
            return CGRect(x: point1!.x, y: point1!.y, width: 0, height: 0)
        }
        let p = touch.preciseLocation(in: view)
        if p.x < (p1.x + p2.x) / 2 {
            if p.y < (p1.y + p2.y) / 2 {
                activeIdx = 0
                let a = CGPoint(x: min(p1.x, p2.x), y: min(p1.y, p2.y))
                anchorPoint = .init(x: a.x - p.x, y: a.y - p.y)
            }
            else {
                activeIdx = 1
                let a = CGPoint(x: min(p1.x, p2.x), y: max(p1.y, p2.y))
                anchorPoint = .init(x: a.x - p.x, y: a.y - p.y)
            }
        }
        else {
            if p.y < (p1.y + p2.y) / 2 {
                activeIdx = 2
                let a = CGPoint(x: max(p1.x, p2.x), y: min(p1.y, p2.y))
                anchorPoint = .init(x: a.x - p.x, y: a.y - p.y)
            }
            else {
                activeIdx = 3
                let a = CGPoint(x: max(p1.x, p2.x), y: max(p1.y, p2.y))
                anchorPoint = .init(x: a.x - p.x, y: a.y - p.y)
            }
        }
        return rect.insetBy(dx: -10, dy: -10)
    }

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        let oldrect = rect
        let p = touch.preciseLocation(in: view)
        guard let p1 = point1, let p2 = point2,
            let aIdx = activeIdx, let anchor = anchorPoint else {
            point2 = p
            return rect.union(oldrect).insetBy(dx: -10, dy: -10)
        }
        let delta = CGPoint(x: p.x + anchor.x, y: p.y + anchor.y)
        var xi = 0
        var yi = 0
        switch aIdx {
        case 0:
            if p1.x > p2.x {
                xi = 1
            }
            if p1.y > p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 1:
            if p1.x > p2.x {
                xi = 1
            }
            if p1.y < p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 2:
            if p1.x < p2.x {
                xi = 1
            }
            if p1.y > p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 3:
            if p1.x < p2.x {
                xi = 1
            }
            if p1.y < p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        default:
            break
        }
        return rect.union(oldrect).insetBy(dx: -10, dy: -10)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        if cancel {
            return self.cancel()
        }
        let oldrect = rect
        let p = touch.preciseLocation(in: view)
        guard let p1 = point1, let p2 = point2,
            let aIdx = activeIdx, let anchor = anchorPoint else {
            point2 = p
            return rect.union(oldrect).insetBy(dx: -10, dy: -10)
        }
        let delta = CGPoint(x: p.x + anchor.x, y: p.y + anchor.y)
        var xi = 0
        var yi = 0
        switch aIdx {
        case 0:
            if p1.x > p2.x {
                xi = 1
            }
            if p1.y > p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 1:
            if p1.x > p2.x {
                xi = 1
            }
            if p1.y < p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 2:
            if p1.x < p2.x {
                xi = 1
            }
            if p1.y > p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        case 3:
            if p1.x < p2.x {
                xi = 1
            }
            if p1.y < p2.y {
                yi = 1
            }
            point1 = .init(x: xi == 0 ? delta.x : p1.x, y: yi == 0 ? delta.y : p1.y)
            point2 = .init(x: xi == 1 ? delta.x : p2.x, y: yi == 1 ? delta.y : p2.y)
        default:
            break
        }
        activeIdx = nil
        anchorPoint = nil
        return rect.union(oldrect).insetBy(dx: -10, dy: -10)
    }

    override func cancel() -> CGRect {
        let oldrect = rect
        point1 = nil
        point2 = nil
        return oldrect.insetBy(dx: -10, dy: -10)
    }
}


// MARK:- SplineSelection

class SplineSelection: SimpleSelectionObject {
    
    var points: [CGPoint] = []
    var activeIdx: Int?
    var isOpen = true
    
    override init() {
        super.init()
    }
    
    override init(data: Data) {
        super.init()
        
        var strokePoints: [CGPoint] = []
        data.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        points = strokePoints
        if let p0 = points.first, let pe = points.last {
            isOpen = p0 != pe
        }
        else {
            isOpen = false
        }
    }
    
    override func getLocationData() -> Data {
        guard points.count > 0 else {
            return .init()
        }

        var data = Data()
        var t = Int(6)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        for p in points {
            var x1 = Double(p.x)
            var y1 = Double(p.y)
            data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
            data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
        }
        return data
    }

    override var didSelected: Bool {
        return !isOpen
    }
    
    override func dragObject(delta: CGVector) -> CGRect {
        let oldRect = activeRect.insetBy(dx: -10, dy: -10)

        var fixedPoints: [CGPoint] = []
        for i in 0..<points.count {
            let p = CGPoint(x: points[i].x + delta.dx, y: points[i].y + delta.dy)
            fixedPoints += [p]
        }
        points = fixedPoints
        return activeRect.insetBy(dx: -10, dy: -10).union(oldRect)
    }

    override var plusSelectionPath: UIBezierPath {
        guard let p0 = points.first else {
            return .init()
        }
        let path = UIBezierPath()
        path.move(to: p0)
        for i in 0..<(points.count - 1) / 3 {
            let c1 = points[1 + i * 3]
            let c2 = points[2 + i * 3]
            let p2 = points[3 + i * 3]
            path.addCurve(to: p2, controlPoint1: c1, controlPoint2: c2)
        }
        if points.count % 3 == 2 {
            let p2 = points[points.count - 1]
            path.addLine(to: p2)
        }
        if !isOpen {
            path.close()
        }
        return path
    }
    
    override var rawHitPath: UIBezierPath {
        guard isOpen else {
            return plusSelectionPath
        }
        guard points.count > 1 else {
            return .init()
        }
        
        var pointsA: [CGPoint] = []
        var pointsB: [CGPoint] = []

        for i in 0..<(points.count - 1) / 3 {
            let p1 = points[0 + i * 3]
            let c1 = points[1 + i * 3]
            let c2 = points[2 + i * 3]
            let p2 = points[3 + i * 3]
            
            let angle1 = atan2(c1.y - p1.y, c1.x - p1.x)
            let angle2 = atan2(c2.y - p2.y, c2.x - p2.x)

            pointsA += [CGPoint(x: p1.x + 20 * cos(angle1 + .pi / 2), y: p1.y + 20 * sin(angle1 + .pi / 2))]
            pointsA += [CGPoint(x: c1.x + 20 * cos(angle1 + .pi / 2), y: c1.y + 20 * sin(angle1 + .pi / 2))]
            pointsA += [CGPoint(x: c2.x + 20 * cos(angle2 + .pi / 2), y: c2.y + 20 * sin(angle2 + .pi / 2))]
            pointsA += [CGPoint(x: p2.x + 20 * cos(angle2 + .pi / 2), y: p2.y + 20 * sin(angle2 + .pi / 2))]
            
            pointsB += [CGPoint(x: p1.x + 20 * cos(angle1 - .pi / 2), y: p1.y + 20 * sin(angle1 - .pi / 2))]
            pointsB += [CGPoint(x: c1.x + 20 * cos(angle1 - .pi / 2), y: c1.y + 20 * sin(angle1 - .pi / 2))]
            pointsB += [CGPoint(x: c2.x + 20 * cos(angle2 - .pi / 2), y: c2.y + 20 * sin(angle2 - .pi / 2))]
            pointsB += [CGPoint(x: p2.x + 20 * cos(angle2 - .pi / 2), y: p2.y + 20 * sin(angle2 - .pi / 2))]
        }
        if points.count % 3 == 2 {
            let p1 = points[points.count - 2]
            let p2 = points[points.count - 1]

            let angle1 = atan2(p2.y - p1.y, p2.x - p1.x)
            pointsA += [CGPoint(x: p1.x + 20 * cos(angle1 + .pi / 2), y: p1.y + 20 * sin(angle1 + .pi / 2))]
            pointsA += [CGPoint(x: p2.x + 20 * cos(angle1 + .pi / 2), y: p2.y + 20 * sin(angle1 + .pi / 2))]

            pointsB += [CGPoint(x: p1.x + 20 * cos(angle1 - .pi / 2), y: p1.y + 20 * sin(angle1 - .pi / 2))]
            pointsB += [CGPoint(x: p2.x + 20 * cos(angle1 - .pi / 2), y: p2.y + 20 * sin(angle1 - .pi / 2))]
        }
        let path = UIBezierPath()
        if pointsA.count > 3 {
            for i in 0..<pointsA.count / 4 {
                let p1 = pointsA[0 + i * 4]
                let c1 = pointsA[1 + i * 4]
                let c2 = pointsB[2 + i * 4]
                let p2 = pointsB[3 + i * 4]
                let p3 = pointsB[0 + i * 4]
                let c3 = pointsB[1 + i * 4]
                let c4 = pointsA[2 + i * 4]
                let p4 = pointsA[3 + i * 4]
                path.move(to: p1)
                path.addCurve(to: p2, controlPoint1: c1, controlPoint2: c2)
                path.addLine(to: p4)
                path.addCurve(to: p3, controlPoint1: c4, controlPoint2: c3)
                path.move(to: p1)
                path.addLine(to: c1)
                path.addLine(to: c3)
                path.addLine(to: p3)
                path.addLine(to: p1)
                path.move(to: p2)
                path.addLine(to: c2)
                path.addLine(to: c4)
                path.addLine(to: p4)
                path.addLine(to: p2)
            }
        }
        if pointsA.count % 4 == 2 {
            let p1a = pointsA[pointsA.count - 2]
            let p1b = pointsB[pointsB.count - 2]
            let p2a = pointsA[pointsA.count - 1]
            let p2b = pointsB[pointsB.count - 1]
            path.move(to: p1a)
            path.addLine(to: p2a)
            path.addLine(to: p2b)
            path.addLine(to: p1b)
            path.addLine(to: p1a)
        }

        return path
    }
    
    var activeRect: CGRect {
        guard let p0 = points.first else {
            return .null
        }
        var outRect = CGRect(x: p0.x, y: p0.y, width: 0, height: 0)
        for p in points {
            outRect = outRect.union(CGRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        return outRect
    }

    override func continueEditing(_ touch: UITouch, in view: UIView) -> Bool {
        let p = touch.preciseLocation(in: view)
        for point in points {
            let rect = CGRect(origin: point, size: .zero)
            if rect.insetBy(dx: -15, dy: -15).contains(p) {
                return true
            }
        }
        return false
    }
    
    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        if points.isEmpty {
            points = [touch.preciseLocation(in: view)]
            activeIdx = points.count
            isOpen = true
            points += [touch.preciseLocation(in: view)]
            return activeRect.insetBy(dx: -10, dy: -10)
        }
        else {
            activeIdx = nil
            let p = touch.preciseLocation(in: view)
            var a: [Int] = []
            for (idx, point) in points.enumerated() {
                let rect = CGRect(origin: point, size: .zero)
                if rect.insetBy(dx: -15, dy: -15).contains(p) {
                    a += [idx]
                }
            }
            for ai in a {
                if (ai - 1) % 3 == 1 {
                    activeIdx = ai
                    break
                }
            }
            if activeIdx == nil {
                for ai in a {
                    if (ai - 1) % 3 == 2 {
                        activeIdx = ai
                        break
                    }
                }
            }
            if activeIdx == nil {
                activeIdx = a.first
            }
            if let aidx = activeIdx {
                if isOpen && points.count > 2 && aidx == 0 {
                    isOpen = false
                    points += [p]
                    return rect.insetBy(dx: -10, dy: -10)
                }
                points[aidx] = p
                return rect.insetBy(dx: -10, dy: -10)
            }
            activeIdx = points.count
            points += [p]
            return activeRect.insetBy(dx: -10, dy: -10)
        }
    }

    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        guard let aidx = activeIdx else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let oldrect = activeRect.insetBy(dx: -10, dy: -10)
        let p = touch.preciseLocation(in: view)
        points[aidx] = p
        if !isOpen, aidx == 0 {
            points[points.count - 1] = p
        }
        if !isOpen, aidx == points.count - 1 {
            points[0] = p
        }
        return activeRect.insetBy(dx: -10, dy: -10).union(oldrect)
    }

    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        if cancel {
            return self.cancel()
        }

        let p = touch.preciseLocation(in: view)
        guard let aidx = activeIdx else {
            return rect.insetBy(dx: -10, dy: -10)
        }
        let oldrect = activeRect.insetBy(dx: -10, dy: -10)
        points[aidx] = p
        if !isOpen, aidx == 0 {
            points[points.count - 1] = p
        }
        if !isOpen, aidx == points.count - 1 {
            points[0] = p
        }
        activeIdx = nil
        
        if points.count % 3 == 2 {
            let p0 = points[points.count - 2]
            let p1 = points[points.count - 1]
            let delta = CGVector(dx: p1.x - p0.x, dy: p1.y - p0.y)
            points = points.dropLast()
            points += [CGPoint(x: p0.x + delta.dx / 3, y: p0.y + delta.dy / 3),
                       CGPoint(x: p1.x - delta.dx / 3, y: p1.y - delta.dy / 3),
                       p1]
        }
        
        return activeRect.insetBy(dx: -10, dy: -10).union(oldrect)
    }

    override func cancel() -> CGRect {
        let rect = activeRect
        points = []
        activeIdx = nil
        isOpen = true
        return rect.insetBy(dx: -10, dy: -10)
    }
    
    override func drawInContext(_ context: CGContext) {
        super.drawInContext(context)
        
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [])
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for i in 0..<(points.count - 1) / 3 {
            let p1 = points[0 + i * 3]
            let c1 = points[1 + i * 3]
            let c2 = points[2 + i * 3]
            let p2 = points[3 + i * 3]
            context.move(to: p1)
            context.addLine(to: c1)
            context.strokePath()
            context.move(to: p2)
            context.addLine(to: c2)
            context.strokePath()
        }

        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineDash(phase: 0, lengths: [1.0, 3.0])
        context.setLineWidth(1.0)
        for i in 0..<(points.count - 1) / 3 {
            let p1 = points[0 + i * 3]
            let c1 = points[1 + i * 3]
            let c2 = points[2 + i * 3]
            let p2 = points[3 + i * 3]
            context.move(to: p1)
            context.addLine(to: c1)
            context.strokePath()
            context.move(to: p2)
            context.addLine(to: c2)
            context.strokePath()
        }

        context.setFillColor(UIColor.white.cgColor)
        for p in points {
            context.addArc(center: p, radius: 4.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        for (i, p) in points.enumerated() {
            context.setFillColor(UIColor.black.cgColor)
            if isOpen && i == points.count - 1 {
                context.setFillColor(UIColor.systemRed.cgColor)
            }
            else if i > 0 {
                switch i % 3 {
                case 1:
                    context.setFillColor(UIColor.systemGreen.cgColor)
                case 2:
                    context.setFillColor(UIColor.systemBlue.cgColor)
                default:
                    break
                }
            }
            context.addArc(center: p, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.restoreGState()
    }
}

// MARK:- MagicSelection

class MagicSelection: ComplexSelectionObject {
    
    struct SelectedArea {
        var isPlus: Bool
        var points: [CGPoint]
    }
    var selection: [SelectedArea] = []
    
    var startPoint: CGPoint?
    var image: CGImage?
    
    override init() {
        super.init()
    }

    override init(data: Data) {
        super.init()
        
        var nextData = data
        while !nextData.isEmpty {
            let (next, newItem) = convertData(data: nextData)
            nextData = next
            selection += [newItem]
        }
    }

    private func convertData(data: Data) -> (Data, SelectedArea) {
        let t = data.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        var nextData = data.advanced(by: MemoryLayout<Int>.size)
        let count = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Int>.size)
        let pointData = nextData.subdata(in: 0..<count)
        var strokePoints: [CGPoint] = []
        pointData.withUnsafeBytes { pointer -> Void in
            let points = Array(pointer.bindMemory(to: Double.self))
            var count = 0
            var x: CGFloat = 0
            for p in points {
                if count % 2 == 0 {
                    x = CGFloat(p)
                }
                else {
                    strokePoints += [CGPoint(x: x, y: CGFloat(p))]
                }
                count += 1
            }
        }
        let item = SelectedArea(isPlus: t > 0, points: strokePoints)
        
        if nextData.count <= count {
            nextData = Data()
        }
        else {
            nextData = nextData.advanced(by: count)
        }
        return (nextData, item)
    }
    
    override func getLocationData() -> Data {
        var data = Data()
        var t = Int(7)
        data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
        
        for item in selection {
            var t = Int(-1)
            if item.isPlus {
                t = 1
            }
            var count = item.points.count * MemoryLayout<Double>.size * 2
            data.append(Data(bytes: &t, count: MemoryLayout<Int>.size))
            data.append(Data(bytes: &count, count: MemoryLayout<Int>.size))
            for p in item.points {
                var x = Double(p.x)
                var y = Double(p.y)
                data.append(Data(bytes: &x, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &y, count: MemoryLayout<Double>.size))
            }
        }
        return data
    }

    override func dragObject(delta: CGVector) -> CGRect {
        let oldRect = rect
        for i in 0..<selection.count {
            for j in 0..<selection[i].points.count {
                let org = selection[i].points[j]
                selection[i].points[j] = CGPoint(x: org.x + delta.dx, y: org.y + delta.dy)
            }
        }
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }

    override var plusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        for sel in selection {
            guard sel.isPlus else {
                continue
            }
            guard let p0 = sel.points.first else {
                continue
            }
            let subpath = UIBezierPath()
            subpath.move(to: p0)
            for p in sel.points {
                subpath.addLine(to: p)
            }
            subpath.close()
            path.append(subpath)
        }
        return path
    }

    override var minusSelectionPath: UIBezierPath {
        let path = UIBezierPath()
        for sel in selection {
            guard !sel.isPlus else {
                continue
            }
            guard let p0 = sel.points.first else {
                continue
            }
            let subpath = UIBezierPath()
            subpath.move(to: p0)
            for p in sel.points {
                subpath.addLine(to: p)
            }
            subpath.close()
            path.append(subpath)
        }
        return path
    }

    override func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        selection = []
        captureImage()
        let p = touch.preciseLocation(in: view)
        startPoint = p
        return CGRect(origin: p, size: .zero).insetBy(dx: -60, dy: -60)
    }
    
    override func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        var oldRect = CGRect.null
        if let startPoint = startPoint {
            oldRect = CGRect(origin: startPoint, size: .zero)
        }
        let p = touch.preciseLocation(in: view)
        startPoint = p
        return oldRect.union(CGRect(origin: p, size: .zero)).insetBy(dx: -60, dy: -60)
    }
    
    override func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        let p = touch.preciseLocation(in: view)
        startPoint = p
        DispatchQueue.global().async {
            self.getSelection()
            DispatchQueue.main.async {
                self.selectionUpdated?(self.rect.insetBy(dx: -60, dy: -60))
            }
        }
        calcurationStart?(true)
        return rect.union(CGRect(origin: p, size: .zero)).insetBy(dx: -60, dy: -60)
    }
    
    override func cancel() -> CGRect {
        let oldRect = rect
        startPoint = nil
        selection = []
        return oldRect.insetBy(dx: -60, dy: -60)
    }
    
    override func drawInContext(_ context: CGContext) {
        super.drawInContext(context)
        
        guard let startPoint = startPoint else {
            return
        }
        guard selection.count == 0 else {
            return
        }
        let x = startPoint.x
        let y = startPoint.y
        
        context.saveGState()
        context.move(to: CGPoint(x: x, y: y - 50))
        context.addLine(to: CGPoint(x: x, y: y - 3))
        context.move(to: CGPoint(x: x, y: y + 3))
        context.addLine(to: CGPoint(x: x, y: y + 50))
        context.move(to: CGPoint(x: x - 50, y: y))
        context.addLine(to: CGPoint(x: x - 3, y: y))
        context.move(to: CGPoint(x: x + 3, y: y))
        context.addLine(to: CGPoint(x: x + 50, y: y))
        context.setLineWidth(3.0)
        context.setStrokeColor(UIColor.white.cgColor)
        context.strokePath()
        context.move(to: CGPoint(x: x, y: y - 49))
        context.addLine(to: CGPoint(x: x, y: y - 3))
        context.move(to: CGPoint(x: x, y: y + 3))
        context.addLine(to: CGPoint(x: x, y: y + 49))
        context.move(to: CGPoint(x: x - 49, y: y))
        context.addLine(to: CGPoint(x: x - 3, y: y))
        context.move(to: CGPoint(x: x + 3, y: y))
        context.addLine(to: CGPoint(x: x + 49, y: y))
        context.setLineWidth(1.0)
        context.setStrokeColor(UIColor.black.cgColor)
        context.strokePath()
        context.restoreGState()
    }

    private func captureImage() {
        image = container?.frozenImage
    }
    
    private func getSelection() {
        selection = []
        guard let startPoint = startPoint else {
            return
        }
        guard let image = image else {
            return
        }
        guard startPoint.x >= 0, startPoint.y >= 0, Int(startPoint.x * scale) < image.width, Int(startPoint.y * scale) < image.height else {
            return
        }
        
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let whitebackimage = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
            rendererContext.fill(.infinite)
            rendererContext.cgContext.draw(image, in: bounds)
        })
        
        guard let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), renderingIntent: .defaultIntent) else {
            return
        }
        guard var originalBuffer = try? vImage_Buffer(cgImage: whitebackimage.cgImage!, format: format) else {
            return
        }
        defer {
            originalBuffer.free()
        }

        let componentCount = format.componentCount
        var argbSourcePlanarBuffers: [vImage_Buffer] = (0 ..< componentCount).map { _ in
            guard let buffer = try? vImage_Buffer(width: Int(originalBuffer.width),
                                                  height: Int(originalBuffer.height),
                                                  bitsPerPixel: format.bitsPerComponent) else {
                                                    fatalError("Error creating source buffers.")
            }
            
            return buffer
        }
        defer {
            for buffer in argbSourcePlanarBuffers {
                buffer.free()
            }
        }

        vImageConvert_ARGB8888toPlanar8(&originalBuffer, &argbSourcePlanarBuffers[0], &argbSourcePlanarBuffers[1], &argbSourcePlanarBuffers[2], &argbSourcePlanarBuffers[3], vImage_Flags(kvImageNoFlags))
        
        var argbDestinationPlanarBuffers: [vImage_Buffer] = (0 ..< componentCount).map { _ in
            guard let buffer = try? vImage_Buffer(width: Int(originalBuffer.width),
                                                  height: Int(originalBuffer.height),
                                                  bitsPerPixel: format.bitsPerComponent) else {
                                                    fatalError("Error creating destination buffers.")
            }
            
            return buffer
        }
        defer {
            for buffer in argbDestinationPlanarBuffers {
                buffer.free()
            }
        }

        // get start point color
        let cx = Int(startPoint.x * scale)
        let cy = Int(startPoint.y * scale)

        let littleEndian = image.byteOrderInfo == .order16Little || image.byteOrderInfo == .order32Little
        let alphaIndex = littleEndian ? 0 : componentCount - 1
        
        for index in 0 ..< componentCount where index != alphaIndex {
            let target = argbSourcePlanarBuffers[index].data.bindMemory(to: UInt8.self, capacity: argbSourcePlanarBuffers[index].rowBytes * Int(argbSourcePlanarBuffers[index].height))[cx + cy * argbSourcePlanarBuffers[index].rowBytes]
            var lookUpTable = (0...255).map {
                return Pixel_8(abs(Int($0) - Int(target)))
            }
            
            vImageTableLookUp_Planar8(&argbSourcePlanarBuffers[index],
                                      &argbDestinationPlanarBuffers[index],
                                      &lookUpTable,
                                      vImage_Flags(kvImageNoFlags))
        }
        
        guard var destinationBuffer = try? vImage_Buffer(width: Int(originalBuffer.width),
                                                         height: Int(originalBuffer.height),
                                                         bitsPerPixel: format.bitsPerPixel) else {
                                                            fatalError("Error creating destination buffers.")
        }
        defer {
            destinationBuffer.free()
        }
        vImageConvert_Planar8toARGB8888(&argbDestinationPlanarBuffers[0], &argbDestinationPlanarBuffers[1], &argbDestinationPlanarBuffers[2], &argbDestinationPlanarBuffers[3], &destinationBuffer, vImage_Flags(kvImageNoFlags))

        let w = Int(originalBuffer.width)
        let h = Int(originalBuffer.height)
        guard var sourceBuffer = try? vImage_Buffer(width: w, height: h, bitsPerPixel: 8) else {
            return
        }
        defer {
            sourceBuffer.free()
        }

        let divisor: Int32 = 0x1000
        let fDivisor = Float(divisor)

        var coefficientsMatrix = [
            Int16(0.3333 * fDivisor),
            Int16(0.3333 * fDivisor),
            Int16(0.3333 * fDivisor)
        ]
        
        let preBias: [Int16] = [0, 0, 0, 0]
        let postBias: Int32 = 0

        vImageMatrixMultiply_ARGB8888ToPlanar8(&destinationBuffer, &sourceBuffer, &coefficientsMatrix, divisor, preBias, postBias, vImage_Flags(kvImageNoFlags))
        
        guard var workBuffer = try? vImage_Buffer(width: w, height: h, bitsPerPixel: 8) else {
            return
        }
        defer {
            workBuffer.free()
        }

        var lookUpTable = (0...255).map {
            return Pixel_8((Float($0) / 255.0) <= threshold ? 255 : 0)
        }

        vImageTableLookUp_Planar8(&sourceBuffer,
                                  &workBuffer,
                                  &lookUpTable,
                                  vImage_Flags(kvImageNoFlags))

        guard var dataBuffer = try? vImage_Buffer(width: w, height: h, bitsPerPixel: 8) else {
            return
        }
        defer {
            dataBuffer.free()
        }

        let kr = 1.5
        let kernelSize = Int(kr)*2+1
        var kernel = [UInt8](repeating: 0, count: kernelSize*kernelSize)
        for iy in 0..<kernelSize {
            for ix in 0..<kernelSize {
                kernel[ix + iy * kernelSize] = 255
            }
        }
        
        vImageDilate_Planar8(&workBuffer, &dataBuffer, 0, 0, kernel, vImagePixelCount(kernelSize), vImagePixelCount(kernelSize), vImage_Flags(kvImageNoFlags))
        
        let datap = dataBuffer.data.bindMemory(to: UInt8.self, capacity: workBuffer.rowBytes * Int(workBuffer.height))

        var fillbuffer = UnsafeMutablePointer<Int32>.allocate(capacity: w*h)
        defer {
            fillbuffer.deallocate()
        }
        
        class searchFilltest {
            private var searchFill: [filledType]
            private var step: Int
            private let queue = DispatchQueue(label: "search")
            let xRange: Range<Int>
            let yRange: Range<Int>

            enum filledType: UInt8 {
                case empty
                case step1
                case step2
                case step2done
                case positiveAll
                case negativeAll
                case hitAll
                case doneHitAll
            }
            
            init(w: Int, h: Int) {
                searchFill = [filledType](repeating: .empty, count: (w/SearchOperation.split)*(h/SearchOperation.split))
                step = w/SearchOperation.split
                xRange = 0..<w/SearchOperation.split
                yRange = 0..<h/SearchOperation.split
            }
            
            func debugprint() {
                for y in yRange {
                    var str = ""
                    for x in xRange {
                        str += "\(searchFill[x + y * step].rawValue) "
                    }
                    print(str)
                }
            }
            
            func setIfMath(x: Int, y: Int, testValue: Set<filledType>, setValue: filledType) -> Bool {
                queue.sync {
                    if testValue.contains(searchFill[x + y * step]) {
                        searchFill[x + y * step] = setValue
                        return true
                    }
                    return false
                }
            }
            
            func set(x: Int, y: Int, value: filledType) {
                queue.async {
                    self.searchFill[x + y * self.step] = value
                }
            }
            
            func get(x: Int, y: Int) -> filledType {
                queue.sync {
                    searchFill[x + y * step]
                }
            }
        }
        let searchFill = searchFilltest(w: w, h: h)

        for y in 0..<h/SearchOperation.split {
            for x in 0..<w/SearchOperation.split {
                let start = y * SearchOperation.split * workBuffer.rowBytes + x * SearchOperation.split
                
                var testBuffer = vImage_Buffer(data: datap.advanced(by: start), height: vImagePixelCount(SearchOperation.split), width: vImagePixelCount(SearchOperation.split), rowBytes: workBuffer.rowBytes)
                
                var histogramBin = [vImagePixelCount](repeating: 0, count: 256)
                vImageHistogramCalculation_Planar8(&testBuffer, &histogramBin, vImage_Flags(kvImageNoFlags))
                
                if histogramBin.first! == 0 {
                    searchFill.set(x: x, y: y, value: .positiveAll)
                }
                if histogramBin.last! == 0 {
                    searchFill.set(x: x, y: y, value: .negativeAll)
                }
            }
        }
        
        class SearchOperation: Operation {
            static let split = 200

            let queue: OperationQueue
            let fillp: UnsafeMutablePointer<Int32>
            let datap: UnsafeMutablePointer<UInt8>
            let rowBytes: Int
            let width: Int
            let height: Int
            let rangeX: Range<Int>
            let rangeY: Range<Int>
            let sx: Int
            let sy: Int
            var searchFill: searchFilltest
            let vec = [(-1,0),(-1,-1),(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1)]
            var next = ArraySlice<(Int,Int)>()
            var remain: [(Int, Int)] = []
            
            init(queue: OperationQueue, fillp: UnsafeMutablePointer<Int32>, datap: UnsafeMutablePointer<UInt8>, rowBytes: Int, width: Int, height: Int, sx: Int, sy: Int, start: [(Int,Int)], searchFill: searchFilltest) {
                self.queue = queue
                self.fillp = fillp
                self.datap = datap
                self.rowBytes = rowBytes
                self.width = width
                self.height = height
                self.rangeX = sx*SearchOperation.split..<(sx+1)*SearchOperation.split
                self.rangeY = sy*SearchOperation.split..<(sy+1)*SearchOperation.split
                self.sx = sx
                self.sy = sy
                self.searchFill = searchFill
                next.append(contentsOf: start)
            }
            
            override func main() {
                guard !dependencies.contains(where: { $0.isCancelled }), !isCancelled else {
                    return
                }
                
                let f = searchFill.get(x: sx, y: sy)
                if f == .positiveAll {
                    searchFill.set(x: sx, y: sy, value: .hitAll)

                    if searchFill.yRange.contains(sy - 1) {
                        let f2 = searchFill.get(x: sx, y: sy - 1)
                        switch f2 {
                        case .empty, .step1:
                            for x in rangeX {
                                let y = rangeY.first! - 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if datap[x + y * rowBytes] > 0 {
                                    remain.append((x, y))
                                }
                            }
                        case .positiveAll:
                            let x = rangeX.first!
                            let y = rangeY.first! - 1
                            if x >= 0, y >= 0, x < width, y < height {
                                remain.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.yRange.contains(sy + 1) {
                        let f2 = searchFill.get(x: sx, y: sy + 1)
                        switch f2 {
                        case .empty, .step1:
                            for x in rangeX {
                                let y = rangeY.last! + 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if datap[x + y * rowBytes] > 0 {
                                    remain.append((x, y))
                                }
                            }
                        case .positiveAll:
                            let x = rangeX.first!
                            let y = rangeY.last! + 1
                            if x >= 0, y >= 0, x < width, y < height {
                                remain.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx - 1) {
                        let f2 = searchFill.get(x: sx - 1, y: sy)
                        switch f2 {
                        case .empty, .step1:
                            for y in rangeY {
                                let x = rangeX.first! - 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if datap[x + y * rowBytes] > 0 {
                                    remain.append((x, y))
                                }
                            }
                        case .positiveAll:
                            let x = rangeX.first! - 1
                            let y = rangeY.first!
                            if x >= 0, y >= 0, x < width, y < height {
                                remain.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx + 1) {
                        let f2 = searchFill.get(x: sx + 1, y: sy)
                        switch f2 {
                        case .empty, .step1:
                            for y in rangeY {
                                let x = rangeX.last! + 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if datap[x + y * rowBytes] > 0 {
                                    remain.append((x, y))
                                }
                            }
                        case .positiveAll:
                            let x = rangeX.last! + 1
                            let y = rangeY.first!
                            if x >= 0, y >= 0, x < width, y < height {
                                remain.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                }
                else if f == .step1 {
                    while !next.isEmpty {
                        guard let (px, py) = next.first else {
                            break
                        }
                        next = next.dropFirst()
                        
                        guard px >= 0, py >= 0, px < width, py < height else {
                            continue
                        }
                        guard rangeX.contains(px), rangeY.contains(py) else {
                            if datap[px + py * rowBytes] > 0 {
                                remain.append((px, py))
                            }
                            continue
                        }
                        guard datap[px + py * rowBytes] > 0 else {
                            continue
                        }
                        guard OSAtomicIncrement32(&fillp[px + py * width]) == 1 else {
                            continue
                        }

                        for (dx, dy) in vec {
                            let x = px + dx
                            let y = py + dy

                            guard x >= 0, y >= 0, x < width, y < height else {
                                continue
                            }
                            guard rangeX.contains(x), rangeY.contains(y) else {
                                if datap[x + y * rowBytes] > 0 {
                                    remain.append((x, y))
                                }
                                continue
                            }
                            guard fillp[x + y * width] == 0 else {
                                continue
                            }
                            guard datap[x + y * rowBytes] > 0 else {
                                continue
                            }
                            if !rangeX.contains(x + dx) && !rangeY.contains(y + dy) {
                                next.append((x, y))
                                continue
                            }
                            guard OSAtomicIncrement32(&fillp[x + y * width]) == 1 else {
                                continue
                            }
                            next.append((x + dx, y + dy))
                        }
                    }
                }

                guard remain.count > 0 else {
                    return
                }
                
                let leftnext = remain.filter({ $0.0 < rangeX.first! && rangeY.contains($0.1) })
                let rightnext = remain.filter({ $0.0 > rangeX.last! && rangeY.contains($0.1) })
                let upnext = remain.filter({ $0.1 < rangeY.first! && rangeX.contains($0.0) })
                let downnext = remain.filter({ $0.1 > rangeY.last! && rangeX.contains($0.0) })

                if leftnext.count > 0, searchFill.xRange.contains(sx - 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx - 1, y: sy) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx - 1, sy: sy, start: leftnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightnext.count > 0, searchFill.xRange.contains(sx + 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx + 1, y: sy) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx + 1, sy: sy, start: rightnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if upnext.count > 0, searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx, y: sy - 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx, y: sy - 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx, sy: sy - 1, start: upnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if downnext.count > 0, searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx, y: sy + 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx, y: sy + 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx, sy: sy + 1, start: downnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                
                let leftupnext = remain.filter({ $0.0 < rangeX.first! && $0.1 < rangeY.first! })
                let rightupnext = remain.filter({ $0.0 > rangeX.last! && $0.1 < rangeY.first! })
                let leftdownnext = remain.filter({ $0.0 < rangeX.first! && $0.1 > rangeY.last! })
                let rightdownnext = remain.filter({ $0.0 > rangeX.last! && $0.1 > rangeY.last! })

                if leftupnext.count > 0,
                    searchFill.xRange.contains(sx - 1),
                    searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy - 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx - 1, y: sy - 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx - 1, sy: sy - 1, start: leftupnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightupnext.count > 0,
                    searchFill.xRange.contains(sx + 1),
                    searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy - 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx + 1, y: sy - 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx + 1, sy: sy - 1, start: rightupnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if leftdownnext.count > 0,
                    searchFill.xRange.contains(sx - 1),
                    searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy + 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx - 1, y: sy + 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx - 1, sy: sy + 1, start: leftdownnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightdownnext.count > 0,
                    searchFill.xRange.contains(sx + 1),
                    searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy + 1, testValue: [.empty, .step1], setValue: .step1)
                        || searchFill.get(x: sx + 1, y: sy + 1) == .positiveAll) {
                    let operation = SearchOperation(queue: queue, fillp: fillp, datap: datap, rowBytes: rowBytes, width: width, height: height, sx: sx + 1, sy: sy + 1, start: rightdownnext, searchFill: searchFill)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
            }
        }

        let sx = cx / SearchOperation.split
        let sy = cy / SearchOperation.split

        searchFill.set(x: sx, y: sy, value: .step1)

        let queue = OperationQueue()
        let operation = SearchOperation(queue: queue, fillp: fillbuffer, datap: datap, rowBytes: workBuffer.rowBytes, width: w, height: h, sx: sx, sy: sy, start: [(cx,cy)], searchFill: searchFill)
        
        queue.addOperation(operation)
        queue.waitUntilAllOperationsAreFinished()
        
        //searchFill.debugprint()
        print("work")

        class resultStore {
            var result: [[(Int, Int)]] = []
            let queue = DispatchQueue(label: "store")
            
            func append(_ data: [(Int, Int)]) {
                queue.async {
                    self.result.append(data)
                }
            }
        }

        class PointOperation: Operation {
            let queue: OperationQueue
            let fillp: UnsafeMutablePointer<Int32>
            let width: Int
            let height: Int
            let rangeX: Range<Int>
            let rangeY: Range<Int>
            let sx: Int
            let sy: Int
            var searchFill: searchFilltest
            let result: resultStore
            var tmpResult: [(Int, Int)] = []
            var leftChain = false
            var rightChain = false
            var upChain = false
            var downChain = false

            var leftupChain = false
            var rightupChain = false
            var leftdownChain = false
            var rightdownChain = false

            init(queue: OperationQueue, fillp: UnsafeMutablePointer<Int32>, width: Int, height: Int, sx: Int, sy: Int, searchFill: searchFilltest, result: resultStore) {
                self.queue = queue
                self.fillp = fillp
                self.width = width
                self.height = height
                self.rangeX = sx*SearchOperation.split..<(sx+1)*SearchOperation.split
                self.rangeY = sy*SearchOperation.split..<(sy+1)*SearchOperation.split
                self.sx = sx
                self.sy = sy
                self.searchFill = searchFill
                self.result = result
            }

            override func main() {
                guard !dependencies.contains(where: { $0.isCancelled }), !isCancelled else {
                    return
                }
                
                let f = searchFill.get(x: sx, y: sy)
                if f == .hitAll {
                    searchFill.set(x: sx, y: sy, value: .doneHitAll)
                    
                    if searchFill.yRange.contains(sy - 1) {
                        let f2 = searchFill.get(x: sx, y: sy - 1)
                        switch f2 {
                        case .step1, .step2, .step2done:
                            for x in rangeX {
                                let y = rangeY.first! - 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if fillp[x + y * width] == 0 {
                                    tmpResult.append((x, y + 1))
                                }
                            }
                            if f2 == .step1 {
                                upChain = true
                                leftupChain = true
                                rightupChain = true
                            }
                        case .hitAll:
                            upChain = true
                            leftupChain = true
                            rightupChain = true
                        case .negativeAll:
                            for x in rangeX {
                                let y = rangeY.first!
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                tmpResult.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    else {
                        for x in rangeX {
                            let y = rangeY.first!
                            guard x >= 0, y >= 0, x < width, y < height else {
                                continue
                            }
                            tmpResult.append((x, y))
                        }
                    }

                    if searchFill.yRange.contains(sy + 1) {
                        let f2 = searchFill.get(x: sx, y: sy + 1)
                        switch f2 {
                        case .step1, .step2, .step2done:
                            for x in rangeX {
                                let y = rangeY.last! + 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if fillp[x + y * width] == 0 {
                                    tmpResult.append((x, y - 1))
                                }
                            }
                            if f2 == .step1 {
                                downChain = true
                                leftdownChain = true
                                rightdownChain = true
                            }
                        case .hitAll:
                            downChain = true
                            leftdownChain = true
                            rightdownChain = true
                        case .negativeAll:
                            for x in rangeX {
                                let y = rangeY.last!
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                tmpResult.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    else {
                        for x in rangeX {
                            let y = height - 1
                            guard x >= 0, y >= 0, x < width, y < height else {
                                continue
                            }
                            tmpResult.append((x, y))
                        }
                    }

                    if searchFill.xRange.contains(sx - 1) {
                        let f2 = searchFill.get(x: sx - 1, y: sy)
                        switch f2 {
                        case .step1, .step2, .step2done:
                            for y in rangeY {
                                let x = rangeX.first! - 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if fillp[x + y * width] == 0 {
                                    tmpResult.append((x + 1, y))
                                }
                            }
                            if f2 == .step1 {
                                leftChain = true
                                leftupChain = true
                                leftdownChain = true
                            }
                        case .hitAll:
                            leftChain = true
                            leftupChain = true
                            leftdownChain = true
                        case .negativeAll:
                            for y in rangeY {
                                let x = rangeX.first!
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                tmpResult.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    else {
                        for y in rangeY {
                            let x = rangeX.first!
                            guard x >= 0, y >= 0, x < width, y < height else {
                                continue
                            }
                            tmpResult.append((x, y))
                        }
                    }

                    if searchFill.xRange.contains(sx + 1) {
                        let f2 = searchFill.get(x: sx + 1, y: sy)
                        switch f2 {
                        case .step1, .step2, .step2done:
                            for y in rangeY {
                                let x = rangeX.last! + 1
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                if fillp[x + y * width] == 0 {
                                    tmpResult.append((x - 1, y))
                                }
                            }
                            if f2 == .step1 {
                                rightChain = true
                                rightupChain = true
                                rightdownChain = true
                            }
                        case .hitAll:
                            rightChain = true
                            rightupChain = true
                            rightdownChain = true
                        case .negativeAll:
                            for y in rangeY {
                                let x = rangeX.last!
                                guard x >= 0, y >= 0, x < width, y < height else {
                                    continue
                                }
                                tmpResult.append((x, y))
                            }
                        default:
                            break
                        }
                    }
                    else {
                        for y in rangeY {
                            let x = width - 1
                            guard x >= 0, y >= 0, x < width, y < height else {
                                continue
                            }
                            tmpResult.append((x, y))
                        }
                    }
                }
                else if f == .step2 {
                    searchFill.set(x: sx, y: sy, value: .step2done)

                    var prevY = [Int32](repeating: 0, count: rangeX.count + 2)
                    var prevX = [Int32](repeating: 0, count: rangeY.count + 2)
                    var nextY = [Int32](repeating: 0, count: rangeX.count + 2)
                    var nextX = [Int32](repeating: 0, count: rangeY.count + 2)
                    if searchFill.yRange.contains(sy - 1) {
                        let f2 = searchFill.get(x: sx, y: sy - 1)
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            for i in 1..<rangeY.count+1 {
                                prevY[i] = 1
                            }
                        case .negativeAll:
                            for i in 1..<rangeY.count+1 {
                                prevY[i] = 0
                            }
                        case .step1, .step2, .step2done:
                            let y = rangeY.first! - 1
                            for x in rangeX {
                                if x >= 0, y >= 0, x < width, y < height {
                                    prevY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                                }
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.yRange.contains(sy + 1) {
                        let f2 = searchFill.get(x: sx, y: sy + 1)
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            for i in 1..<rangeY.count+1 {
                                nextY[i] = 1
                            }
                        case .negativeAll:
                            for i in 1..<rangeY.count+1 {
                                nextY[i] = 0
                            }
                        case .step1, .step2, .step2done:
                            let y = rangeY.last! + 1
                            for x in rangeX {
                                if x >= 0, y >= 0, x < width, y < height {
                                    nextY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                                }
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx - 1) {
                        let f2 = searchFill.get(x: sx - 1, y: sy)
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            for i in 1..<rangeX.count+1 {
                                prevX[i] = 1
                            }
                        case .negativeAll:
                            for i in 1..<rangeX.count+1 {
                                prevX[i] = 0
                            }
                        case .step1, .step2, .step2done:
                            let x = rangeX.first! - 1
                            for y in rangeY {
                                if x >= 0, y >= 0, x < width, y < height {
                                    prevX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                                }
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx + 1) {
                        let f2 = searchFill.get(x: sx + 1, y: sy)
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            for i in 1..<rangeX.count+1 {
                                nextX[i] = 1
                            }
                        case .negativeAll:
                            for i in 1..<rangeX.count+1 {
                                nextX[i] = 0
                            }
                        case .step1, .step2, .step2done:
                            let x = rangeX.last! + 1
                            for y in rangeY {
                                if x >= 0, y >= 0, x < width, y < height {
                                    nextX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                                }
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx - 1), searchFill.yRange.contains(sy - 1) {
                        let f2 = searchFill.get(x: sx - 1, y: sy - 1)
                        let x = rangeX.first! - 1
                        let y = rangeY.first! - 1
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            prevX[y - rangeY.lowerBound + 1] = 1
                            prevY[x - rangeX.lowerBound + 1] = 1
                        case .step1, .step2, .step2done:
                            if x >= 0, y >= 0, x < width, y < height {
                                prevX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                                prevY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx + 1), searchFill.yRange.contains(sy - 1) {
                        let x = rangeX.last! + 1
                        let y = rangeY.first! - 1
                        let f2 = searchFill.get(x: sx + 1, y: sy - 1)
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            prevY[x - rangeX.lowerBound + 1] = 1
                            nextX[y - rangeY.lowerBound + 1] = 1
                        case .step1, .step2, .step2done:
                            if x >= 0, y >= 0, x < width, y < height {
                                prevY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                                nextX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx - 1), searchFill.yRange.contains(sy + 1) {
                        let f2 = searchFill.get(x: sx - 1, y: sy + 1)
                        let x = rangeX.first! - 1
                        let y = rangeY.last! + 1
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            prevX[y - rangeY.lowerBound + 1] = 1
                            nextY[x - rangeX.lowerBound + 1] = 1
                        case .step1, .step2, .step2done:
                            if x >= 0, y >= 0, x < width, y < height {
                                prevX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                                nextY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                            }
                        default:
                            break
                        }
                    }
                    if searchFill.xRange.contains(sx + 1), searchFill.yRange.contains(sy + 1) {
                        let f2 = searchFill.get(x: sx + 1, y: sy + 1)
                        let x = rangeX.last! + 1
                        let y = rangeY.last! + 1
                        switch f2 {
                        case .hitAll, .doneHitAll:
                            nextX[y - rangeY.lowerBound + 1] = 1
                            nextY[x - rangeX.lowerBound + 1] = 1
                        case .step1, .step2, .step2done:
                            if x >= 0, y >= 0, x < width, y < height {
                                nextX[y - rangeY.lowerBound + 1] = fillp[x + y * width]
                                nextY[x - rangeX.lowerBound + 1] = fillp[x + y * width]
                            }
                        default:
                            break
                        }
                    }

                    let checkValue: (Int, Int)->Void = { x, y in
                        if x - 1 >= 0 {
                            if self.rangeX.contains(x - 1) {
                                if self.fillp[x - 1 + y * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                self.leftChain = true
                                if prevX[y - self.rangeY.lowerBound + 1] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                        }
                        else {
                            self.tmpResult.append((x, y))
                        }
                        if y - 1 >= 0 {
                            if self.rangeY.contains(y - 1) {
                                if self.fillp[x + (y - 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                self.upChain = true
                                if prevY[x - self.rangeX.lowerBound + 1] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                        }
                        else {
                            self.tmpResult.append((x, y))
                        }
                        if x - 1 >= 0, y - 1 >= 0 {
                            if self.rangeX.contains(x - 1), self.rangeY.contains(y - 1) {
                                if self.fillp[x - 1 + (y - 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                if self.rangeX.contains(x - 1) {
                                    self.upChain = true
                                    if prevY[x - 1 - self.rangeX.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else if self.rangeY.contains(y - 1) {
                                    self.leftChain = true
                                    if prevX[y - 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else {
                                    self.leftupChain = true
                                    if prevX[y - 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                            }
                        }
                        if x + 1 < self.width {
                            if self.rangeX.contains(x + 1) {
                                if self.fillp[x + 1 + y * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                self.rightChain = true
                                if nextX[y - self.rangeY.lowerBound + 1] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                        }
                        else {
                            self.tmpResult.append((x, y))
                        }
                        if y + 1 < self.height {
                            if self.rangeY.contains(y + 1) {
                                if self.fillp[x + (y + 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                self.downChain = true
                                if nextY[x - self.rangeX.lowerBound + 1] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                        }
                        else {
                            self.tmpResult.append((x, y))
                        }
                        if x + 1 < self.width, y + 1 < self.height {
                            if self.rangeX.contains(x + 1), self.rangeY.contains(y + 1) {
                                if self.fillp[x + 1 + (y + 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                if self.rangeX.contains(x + 1) {
                                    self.rightChain = true
                                    if nextY[x + 1 - self.rangeX.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else if self.rangeY.contains(y + 1) {
                                    self.downChain = true
                                    if nextX[y + 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else {
                                    self.rightdownChain = true
                                    if nextX[y + 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                            }
                        }
                        if x - 1 >= 0, y + 1 < self.height {
                            if self.rangeX.contains(x - 1), self.rangeY.contains(y + 1) {
                                if self.fillp[x - 1 + (y + 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                if self.rangeX.contains(x - 1) {
                                    self.leftChain = true
                                    if nextY[x - 1 - self.rangeX.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else if self.rangeY.contains(y + 1) {
                                    self.downChain = true
                                    if prevX[y + 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else {
                                    self.leftdownChain = true
                                    if nextY[x - 1 - self.rangeX.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                            }
                        }
                        if x + 1 < self.width, y - 1 >= 0 {
                            if self.rangeX.contains(x + 1), self.rangeY.contains(y - 1) {
                                if self.fillp[x + 1 + (y - 1) * self.width] == 0 {
                                    self.tmpResult.append((x, y))
                                    return
                                }
                            }
                            else {
                                if self.rangeX.contains(x + 1) {
                                    self.upChain = true
                                    if prevY[x + 1 - self.rangeX.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else if self.rangeY.contains(y - 1) {
                                    self.rightChain = true
                                    if nextX[y - 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                                else {
                                    self.rightdownChain = true
                                    if nextX[y - 1 - self.rangeY.lowerBound + 1] == 0 {
                                        self.tmpResult.append((x, y))
                                        return
                                    }
                                }
                            }
                        }
                    }

                    for py in rangeY {
                        for px in rangeX {
                            if fillp[px + py * width] > 0 {
                                checkValue(px, py)
                            }
                        }
                    }
                }
                
                if !tmpResult.isEmpty {
                    result.append(tmpResult)
                }
                
                if leftChain, searchFill.xRange.contains(sx - 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx - 1, y: sy) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx - 1, sy: sy, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightChain, searchFill.xRange.contains(sx + 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx + 1, y: sy) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx + 1, sy: sy, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if upChain, searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx, y: sy - 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx, y: sy - 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx, sy: sy - 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if downChain, searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx, y: sy + 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx, y: sy + 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx, sy: sy + 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if leftupChain, searchFill.xRange.contains(sx - 1), searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy - 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx - 1, y: sy - 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx - 1, sy: sy - 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightupChain, searchFill.xRange.contains(sx + 1), searchFill.yRange.contains(sy - 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy - 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx + 1, y: sy - 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx + 1, sy: sy - 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if leftdownChain, searchFill.xRange.contains(sx - 1), searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx - 1, y: sy + 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx - 1, y: sy + 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx - 1, sy: sy + 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
                if rightdownChain, searchFill.xRange.contains(sx + 1), searchFill.yRange.contains(sy + 1),
                    (searchFill.setIfMath(x: sx + 1, y: sy + 1, testValue: [.step1], setValue: .step2)
                        || searchFill.get(x: sx + 1, y: sy + 1) == .hitAll) {
                    let operation = PointOperation(queue: queue, fillp: fillp, width: width, height: height, sx: sx + 1, sy: sy + 1, searchFill: searchFill, result: result)
                    operation.addDependency(self)
                    
                    queue.addOperation(operation)
                }
            }
        }

        searchFill.set(x: sx, y: sy, value: .step2)
        let result = resultStore()
        let operation2 = PointOperation(queue: queue, fillp: fillbuffer, width: w, height: h, sx: sx, sy: sy, searchFill: searchFill, result: result)
        
        queue.addOperation(operation2)
        queue.waitUntilAllOperationsAreFinished()

        print("work2")
        //searchFill.debugprint()
        //print(result.result)
        
        let firstPoints = result.result
            .filter({ !$0.isEmpty })
            .flatMap({ $0 })
            .sorted(by: { $0.0 < $1.0 })
            .sorted(by: { $0.1 < $1.1 })
        guard firstPoints.count > 0 else {
            return
        }
        
        //print(remainPoints)
        
        class ResultPath {
            var resultPaths = [[CGPoint]]()
            let storeQueue = DispatchQueue(label: "StorePath")
            
            func store(paths: [[CGPoint]]) {
                storeQueue.async {
                    self.resultPaths.append(contentsOf: paths)
                }
            }
        }
        
        class JointPointOperation: Operation {
            static let pathSearchSplit = 400
            
            let points: [(Int, Int)]
            let result: ResultPath
            let ix: Int
            let iy: Int
            
            init(ix: Int, iy: Int, points: [(Int, Int)], result: ResultPath) {
                self.points = points
                self.result = result
                self.ix = ix
                self.iy = iy
            }
            
            override func main() {
                guard !dependencies.contains(where: { $0.isCancelled }), !isCancelled else {
                    return
                }
                
                let s = JointPointOperation.pathSearchSplit
                let xrange = ix*s..<(ix+1)*s
                let yrange = iy*s..<(iy+1)*s
                let selPoints = points.filter({ xrange.contains($0.0) && yrange.contains($0.1) })

                guard selPoints.count > 0 else {
                    return
                }

                //let t1 = Date()
                
                var doneIdx = [Bool](repeating: false, count: selPoints.count)
                doneIdx[0] = true

                var tmpPath = [CGPoint]()
                var localResult = [[CGPoint]]()
                
                var curPoint = CGPoint(x: CGFloat(selPoints[0].0), y: CGFloat(selPoints[0].1))
                tmpPath.append(curPoint)

                let r: CGFloat = 2
                let r1: CGFloat = 1.5
                let offsetVec: [(CGFloat, CGFloat)] = [(r,0),(0,r),(-r,0),(0,-r),(r/sqrt(2),r/sqrt(2)),(r/sqrt(2),-r/sqrt(2)),(-r/sqrt(2),r/sqrt(2)),(-r/sqrt(2),-r/sqrt(2))]
                var offsetIdx = 0

                while !doneIdx.allSatisfy({ $0 }) {
                    let xp = Int(curPoint.x)
                    let yp = Int(curPoint.y)

                    let ids = selPoints.enumerated()
                        .filter({ !doneIdx[$0.offset] })
                        .filter({ (xp-Int(r1+1)...xp+Int(r1+1)).contains($0.element.0) && (yp-Int(r1+1)...yp+Int(r1+1)).contains($0.element.1) })
                        .filter({
                            let (x,y) = $0.element
                            let dx = CGFloat(x) - curPoint.x
                            let dy = CGFloat(y) - curPoint.y
                            return sqrt(dx * dx + dy * dy) < r1
                        })
                        .map({ $0.offset })
                    
                    if ids.count > 0 {
                        for i in ids {
                            doneIdx[i] = true
                        }
                        let (xsum, ysum) = ids.map({ selPoints[$0] })
                            .reduce((CGFloat(0), CGFloat(0)), { sum, next in
                                var (xsum, ysum) = sum
                                let (x,y) = next
                                xsum += CGFloat(x)
                                ysum += CGFloat(y)
                                return (xsum, ysum)
                            })
                        tmpPath.append(curPoint)
                        curPoint = CGPoint(x: xsum / CGFloat(ids.count), y: ysum / CGFloat(ids.count))
                        offsetIdx = 0
                    }
                    else {
                        if offsetIdx >= offsetVec.count {
                            if !tmpPath.isEmpty {
                                localResult.append(tmpPath)
                            }
                            tmpPath = []
                            
                            guard let next = doneIdx.firstIndex(where: { !$0 }) else {
                                break
                            }
                            curPoint = CGPoint(x: CGFloat(selPoints[next].0), y: CGFloat(selPoints[next].1))
                            tmpPath.append(curPoint)
                            continue
                        }
                        let (dx, dy) = offsetVec[offsetIdx]
                        if offsetIdx > 0 {
                            curPoint.x -= offsetVec[offsetIdx - 1].0
                            curPoint.y -= offsetVec[offsetIdx - 1].1
                        }
                        curPoint.x += dx
                        curPoint.y += dy
                        offsetIdx += 1
                    }
                }
                if !tmpPath.isEmpty {
                    localResult.append(tmpPath)
                }
                //print(-t1.timeIntervalSinceNow)
                
                if !localResult.isEmpty {
                    result.store(paths: localResult)
                }
            }
        }
        
        let pathjoinResult = ResultPath()
        var operations = [Operation]()
        for iy in 0..<h/JointPointOperation.pathSearchSplit {
            for ix in 0..<w/JointPointOperation.pathSearchSplit {
                operations += [JointPointOperation(ix: ix, iy: iy, points: firstPoints, result: pathjoinResult)]
            }
        }

        let t1 = Date()
        
        queue.addOperations(operations, waitUntilFinished: false)
        queue.waitUntilAllOperationsAreFinished()

        print(-t1.timeIntervalSinceNow)
        print("work3")

        let joinR: CGFloat = 10
        var closedPath = [[CGPoint]]()
        var openPath = [[CGPoint]]()
        for p in pathjoinResult.resultPaths {
            guard let p0 = p.first else {
                continue
            }
            guard let p1 = p.last else {
                continue
            }
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            if p.count > 10 && sqrt(dx * dx + dy * dy) < joinR {
                closedPath.append(p)
            }
            else {
                openPath.append(p)
            }
        }
        while !openPath.isEmpty {
            guard var path0 = openPath.last else {
                break
            }
            openPath = openPath.dropLast()
            guard path0.count > 0 else {
                continue
            }
            
            var found = true
            while found {
                found = false
                let p00 = path0.first!
                let p01 = path0.last!

                for i in 0..<openPath.count {
                    let path1 = openPath[i]
                    guard let p10 = path1.first else {
                        continue
                    }
                    guard let p11 = path1.last else {
                        continue
                    }
                    
                    let testpoint: (CGPoint, CGPoint)->Bool = {(p0,p1) in
                        let dx = p1.x - p0.x
                        let dy = p1.y - p0.y
                        return sqrt(dx * dx + dy * dy) < joinR
                    }
                    
                    if testpoint(p00, p10) {
                        var path2 = Array(path1.reversed())
                        path2.append(contentsOf: path0)
                        path0 = path2
                        openPath.remove(at: i)
                        found = true
                        break
                    }
                    if testpoint(p00, p11) {
                        var path2 = path1
                        path2.append(contentsOf: path0)
                        path0 = path2
                        openPath.remove(at: i)
                        found = true
                        break
                    }
                    if testpoint(p01, p10) {
                        var path2 = path0
                        path2.append(contentsOf: path1)
                        path0 = path2
                        openPath.remove(at: i)
                        found = true
                        break
                    }
                    if testpoint(p01, p11) {
                        var path2 = path0
                        path2.append(contentsOf: path1.reversed())
                        path0 = path2
                        openPath.remove(at: i)
                        found = true
                        break
                    }
                }

                let fixp00 = path0.first!
                let fixp01 = path0.last!
                let dx = fixp01.x - fixp00.x
                let dy = fixp01.y - fixp00.y
                if sqrt(dx * dx + dy * dy) < joinR {
                    break
                }
                continue
            }
            closedPath.append(path0)
        }
        
        print("work4")
        //print(closedPath)
        
        selection = []
        for p in closedPath {
            let fixp = p.map({ CGPoint(x: $0.x / scale, y: $0.y / scale) })
            guard let p0 = fixp.first else {
                continue
            }
            let path = UIBezierPath()
            path.move(to: p0)
            for p1 in fixp {
                path.addLine(to: p1)
            }
            path.close()
            
            let sel = SelectedArea(isPlus: path.contains(startPoint), points: fixp)
            selection.append(sel)
        }
        
        print("done")
    }
}
