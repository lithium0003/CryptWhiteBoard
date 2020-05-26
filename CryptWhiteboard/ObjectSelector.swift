//
//  ObjectSelector.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/17.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

class ObjectSelector: DrawObject {

    weak var container: DrawObjectContaier?
    
    struct DrawColors {
        var fillColor: UIColor
        var drawColor: UIColor
        var drawWidth: CGFloat
    }
    var orgColors: [DrawColors] = []
    
    var fillColor: UIColor = .clear
    var drawColor: UIColor = .clear
    var drawWidth: CGFloat = 0.0
    var clear = false
    
    enum Mode {
        case done
        case add
        case rotate
    }
    var mode: Mode = .done
    
    private(set) var needRegister = false
    
    var overrideColor = false
    var bounds: CGRect = .null
    var scale: CGFloat = 0.0
    
    var point1: CGPoint?
    var point2: CGPoint?
    var activeIdx: Int?
    var zeroAnglePositive: Bool?
    
    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {

        var DRed: CGFloat = 0
        var DGreen: CGFloat = 0
        var DBlue: CGFloat = 0
        var DAlpha: CGFloat = 0
        var FRed: CGFloat = 0
        var FGreen: CGFloat = 0
        var FBlue: CGFloat = 0
        var FAlpha: CGFloat = 0
        var penWidth: CGFloat = 0.0
        var useColor = false
        var clear = false
        var deltaVec: CGVector = .zero
        var center: CGPoint = .zero
        var rotate: CGFloat = 0
        let commands = cmd.split(separator: ";")
        for c in commands {
            if c.starts(with: "usecolor=") {
                if c.starts(with: "usecolor=1") {
                    useColor = true
                }
            }
            if c.starts(with: "clear=") {
                if c.starts(with: "clear=1") {
                    clear = true
                }
            }
            if c.starts(with: "transfer=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("transfer=") != nil {
                    let x = CGFloat(scanner.scanDouble() ?? 0.0)
                    if scanner.scanString(",") != nil {
                        let y = CGFloat(scanner.scanDouble() ?? 0.0)
                        deltaVec = CGVector(dx: x, dy: y)
                    }
                }
            }
            if c.starts(with: "rotate=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("rotate=") != nil {
                    let x = CGFloat(scanner.scanDouble() ?? 0.0)
                    if scanner.scanString(",") != nil {
                        let y = CGFloat(scanner.scanDouble() ?? 0.0)
                        if scanner.scanString(",") != nil {
                            let a = CGFloat(scanner.scanDouble() ?? 0.0)
                            rotate = a
                            center = CGPoint(x: x, y: y)
                        }
                    }
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

        let selection = ObjectSelector(container: container, data: data)
        selection.drawColor = UIColor(red: DRed, green: DGreen, blue: DBlue, alpha: DAlpha)
        selection.drawWidth = penWidth
        selection.fillColor = UIColor(red: FRed, green: FGreen, blue: FBlue, alpha: FAlpha)
        selection.recordId = recordId
        selection.clear = clear
        selection.overrideColor = useColor
        if deltaVec != .zero {
            _ = selection.translateObject(delta: deltaVec)
        }
        if rotate != 0 {
            _ = selection.rotateObject(center: center, angle: rotate)
        }
        return selection
    }

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
            let (next, id) = convertData(data: nextData)
            nextData = next
            guard let sel = container.retrieveObject(recordId: id) else {
                continue
            }
            objects += [sel]
            orgColors += [orgColor(sel)]
        }
    }

    let orgColor: (DrawObject)->ObjectSelector.DrawColors = { selection in
        if let line = selection as? Line {
            return DrawColors(fillColor: .clear, drawColor: line.penColor, drawWidth: line.penSize)
        }
        else if let text = selection as? TextObject {
            return DrawColors(fillColor: .clear, drawColor: text.textColor, drawWidth: 0)
        }
        else if let sel = selection as? SelectionObject {
            return DrawColors(fillColor: sel.fillColor, drawColor: sel.drawColor, drawWidth: sel.drawWidth)
        }
        else if let osel = selection as? ObjectSelector {
            return DrawColors(fillColor: osel.fillColor, drawColor: osel.drawColor, drawWidth: osel.drawWidth)
        }
        return DrawColors(fillColor: .clear, drawColor: .clear, drawWidth: 0)
    }

    private func convertData(data: Data) -> (Data, String) {
        var nextData = data
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
        return (nextData, id)
    }

    override func getLocationData() -> Data {
        var data = Data()
        
        for obj in objects {
            guard let recordId = obj.recordId else {
                continue
            }
            let idData = recordId.data(using: .utf8)!
            var count = idData.count
            data.append(Data(bytes: &count, count: MemoryLayout<Int>.size))
            data.append(idData)
        }
        
        return data
    }

    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {

        var Red: CGFloat = 0
        var Green: CGFloat = 0
        var Blue: CGFloat = 0
        var Alpha: CGFloat = 0
        fillColor.getRed(&Red, green: &Green, blue: &Blue, alpha: &Alpha)
        var cmd = String(format: "objects;FR=%f;FG=%f;FB=%f;FA=%f", Red, Green, Blue, Alpha)
        drawColor.getRed(&Red, green: &Green, blue: &Blue, alpha: &Alpha)
        cmd += String(format: ";DR=%f;DG=%f;DB=%f;DA=%f;DW=%.1f", Red, Green, Blue, Alpha, drawWidth)
        if overrideColor {
            cmd += ";usecolor=1"
        }
        if clear {
            cmd += ";clear=1"
        }
        if deltaVector != .zero {
            cmd += String(format: ";transfer=%f,%f", deltaVector.dx, deltaVector.dy)
        }
        let angle = fmod(rotateAngle, .pi * 2)
        if angle != 0 {
            cmd += String(format: ";rotate=%f,%f,%f", rotateCenter.x, rotateCenter.y, angle)
        }
        
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }

    override func objectSelectionInside(point: CGPoint) -> Bool {
        if clear {
            return false
        }
        let p = point.applying(transform.inverted())
        for obj in objects {
            if obj.objectSelectionInside(point: p) {
                return true
            }
        }
        return false
    }
    
    func rotateFinished(_ touch: UITouch, in view: UIView) -> Bool {
        let p = touch.preciseLocation(in: view)
        if let p1 = point1, let p2 = point2 {
            let points = [p1, p2]
            for point in points {
                let rect = CGRect(origin: point, size: .zero)
                if rect.insetBy(dx: -15, dy: -15).contains(p) {
                    return false
                }
            }
            return true
        }
        return false
    }
    
    func translateObject(delta: CGVector) -> CGRect {
        mode = .done
        needRegister = true
        let oldRect = rect
        deltaVector.dx += delta.dx
        deltaVector.dy += delta.dy
        transform = CGAffineTransform(translationX: deltaVector.dx, y: deltaVector.dy)
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }

    func rotateObject(center: CGPoint, angle: CGFloat) -> CGRect {
        mode = .rotate
        needRegister = true
        let oldRect = rect
        rotateCenter = center
        rotateAngle = angle
        var t = CGAffineTransform(translationX: -center.x, y: -center.y)
        t = t.concatenating(CGAffineTransform(rotationAngle: angle))
        t = t.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        transform = t
        return rect.union(oldRect).insetBy(dx: -10, dy: -10)
    }

    override var rawHitPath: UIBezierPath {
        let path = UIBezierPath()
        if clear {
            return path
        }
        
        for obj in objects {
            path.append(obj.hitPath)
        }
        return path
    }

    override var hitPath: UIBezierPath {
        let path = rawHitPath
        path.apply(transform)
        return path
    }

    override var objectSelectionOutlineImage: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: rect)
        return renderer.image(actions: { rendererContext in
            rendererContext.cgContext.concatenate(transform)
            UIGraphicsPushContext(rendererContext.cgContext)
            for obj in objects {
                obj.objectSelectionOutlineImage.draw(at: obj.rect.origin)
            }
            UIGraphicsPopContext()
        })
    }

    var imMaskRawRect: CGRect {
        return rawRect.insetBy(dx: -20, dy: -20)
    }
    var imMaskRect: CGRect {
        return rect.insetBy(dx: -20, dy: -20)
    }
    var imMaskBase: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: imMaskRect)
        return renderer.image(actions: { rendererContext in
            let im = UIImage(cgImage: objectSelectionOutlineImage.cgImage!, scale: scale, orientation: .downMirrored)
            rendererContext.cgContext.setFillColor(UIColor.black.cgColor)
            rendererContext.cgContext.fill(.infinite)
            UIGraphicsPushContext(rendererContext.cgContext)
            im.draw(at: rect.origin)
            UIGraphicsPopContext()
        })
    }
    private func dilateImage(input: UIImage)->UIImage? {
        guard let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 8, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), renderingIntent: .defaultIntent) else {
            return nil
        }
        guard var inputBuffer = try? vImage_Buffer(cgImage: input.cgImage!, format: format) else {
            return nil
        }
        defer {
            inputBuffer.free()
        }

        guard var destinationBuffer = try? vImage_Buffer(width: Int(inputBuffer.width),
                                                         height: Int(inputBuffer.height),
                                                         bitsPerPixel: format.bitsPerPixel) else {
                                                            fatalError("Error creating destination buffers.")
        }
        defer {
            destinationBuffer.free()
        }

        
        let kr = 20.0
        let kernelSize = Int(kr)*2+1
        var kernel = [UInt8](repeating: 0, count: kernelSize*kernelSize)
        for iy in 0..<kernelSize {
            for ix in 0..<kernelSize {
                kernel[ix + iy * kernelSize] = 255
            }
        }
        
        vImageDilate_Planar8(&inputBuffer, &destinationBuffer, 0, 0, kernel, vImagePixelCount(kernelSize), vImagePixelCount(kernelSize), vImage_Flags(kvImageNoFlags))

        if let cgImage = try? destinationBuffer.createCGImage(format: format) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    var imMaskDilated: UIImage?
    func setMaskImage() {
        imMaskDilated = objects.count > 0 ? dilateImage(input: imMaskBase) : nil
    }

    func add(selection: DrawObject) {
        guard let container = container else {
            return
        }
        guard let id = selection.recordId else {
            return
        }
        container.setPendingObject(recordId: id, pending: true)

        objects += [selection]
        orgColors += [orgColor(selection)]
    }

    func delete(selection: DrawObject) {
        guard let container = container else {
            return
        }
        guard let id = selection.recordId else {
            return
        }
        if let i = objects.firstIndex(where: { $0.recordId == id }) {
            let backObj = objects.remove(at: i)
            let orgColor = orgColors.remove(at: i)
            if let line = backObj as? Line {
                line.penColor = orgColor.drawColor
                line.penSize = orgColor.drawWidth
            }
            else if let text = backObj as? TextObject {
                text.textColor = orgColor.drawColor
            }
            else if let sel = backObj as? SelectionObject {
                sel.fillColor = orgColor.fillColor
                sel.drawWidth = orgColor.drawWidth
                sel.drawColor = orgColor.drawColor
            }
            else if let osel = backObj as? ObjectSelector {
                osel.fillColor = orgColor.fillColor
                osel.drawWidth = orgColor.drawWidth
                osel.drawColor = orgColor.drawColor
            }
            container.setPendingObject(recordId: id, pending: false)
        }
    }

    func cancelAll() {
        if objects.count > 0 {
            for o in objects {
                delete(selection: o)
            }
            container?.frozenContextDraw()
        }
    }
    
    private func doRotate(p1: CGPoint, p2: CGPoint, plusAxis: Bool?) -> CGRect {
        guard let plusAxis = plusAxis else {
            return (CGRect(origin: p1, size: .zero).insetBy(dx: -200, dy: -200)).union(CGRect(origin: p2, size: .zero).insetBy(dx: -50, dy: -50)).union(rotateObject(center: p1, angle: 0)).insetBy(dx: -50, dy: -50)
        }
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        if sqrt(dx * dx + dy * dy) < 20 {
            return (CGRect(origin: p1, size: .zero).insetBy(dx: -200, dy: -200)).union(CGRect(origin: p2, size: .zero).insetBy(dx: -50, dy: -50)).insetBy(dx: -50, dy: -50)
        }
        if plusAxis {
            let angle = atan2(p2.y - p1.y, p2.x - p1.x)
            return (CGRect(origin: p1, size: .zero).insetBy(dx: -200, dy: -200)).union(CGRect(origin: p2, size: .zero).insetBy(dx: -50, dy: -50)).union(rotateObject(center: p1, angle: angle)).insetBy(dx: -50, dy: -50)
        }
        else {
            let angle = atan2(p2.y - p1.y, p2.x - p1.x) + .pi
            return (CGRect(origin: p1, size: .zero).insetBy(dx: -200, dy: -200)).union(CGRect(origin: p2, size: .zero).insetBy(dx: -50, dy: -50)).union(rotateObject(center: p1, angle: angle)).insetBy(dx: -50, dy: -50)
        }
    }
    
    func beginTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        if mode == .rotate {
            activeIdx = nil
            let p = touch.preciseLocation(in: view)
            if let p1 = point1, let p2 = point2 {
                let points = [p1, p2]
                for (idx, point) in points.enumerated() {
                    let rect = CGRect(origin: point, size: .zero)
                    if rect.insetBy(dx: -15, dy: -15).contains(p) {
                        activeIdx = idx
                        break
                    }
                }
                return rect.union(CGRect(origin: p, size: .zero).insetBy(dx: -200, dy: -200)).insetBy(dx: -50, dy: -50)
            }
            zeroAnglePositive = nil
            point1 = p
            point2 = p
            return doRotate(p1: p, p2: p, plusAxis: zeroAnglePositive)
        }
        return .null
    }

    func moveTouch(_ touch: UITouch, in view: UIView) -> CGRect {
        if mode == .rotate {
            let p = touch.preciseLocation(in: view)
            guard let aidx = activeIdx else {
                point2 = p
                guard let p1 = point1, let p2 = point2 else {
                    return rect.insetBy(dx: -50, dy: -50)
                }
                if zeroAnglePositive == nil {
                    let dx = p2.x - p1.x
                    let dy = p2.y - p1.y
                    if sqrt(dx * dx + dy * dy) > 20 {
                        if p2.x - p1.x > 0 {
                            zeroAnglePositive = true
                        }
                        else {
                            zeroAnglePositive = false
                        }
                    }
                }
                return doRotate(p1: p1, p2: p2, plusAxis: zeroAnglePositive)
            }
            guard let p1 = point1, let p2 = point2 else {
                return rect.insetBy(dx: -10, dy: -10)
            }
            if zeroAnglePositive == nil {
                if p2.x - p1.x > 0 {
                    zeroAnglePositive = true
                }
                else {
                    zeroAnglePositive = false
                }
            }
            switch aidx {
            case 0:
                point1 = p
            case 1:
                point2 = p
            default:
                break
            }
            return doRotate(p1: p1, p2: p2, plusAxis: zeroAnglePositive)
        }
        return .null
    }
    
    func finishTouch(_ touch: UITouch, in view: UIView, cancel: Bool) -> CGRect {
        guard let container = container else {
            return .null
        }
        
        if cancel {
            return self.cancel()
        }
        
        let p = touch.preciseLocation(in: view)
        if mode == .add {
            var fix = false
            let oldRect = rect

            let objs = container.hitTestObject(point: p)
            for o in objs {
                if objects.first(where: { $0.recordId == o.recordId }) == nil {
                    add(selection: o)
                    fix = true
                }
            }

            for o in objects.filter({ target in
                !objs.contains(where: { $0.recordId == target.recordId }) &&  target.objectSelectionInside(point: p) }) {
                delete(selection: o)
                fix = true
            }

            if fix {
                selectionImage = nil
                imMaskDilated = nil
                container.frozenContextDraw()
            }
            else {
                mode = .done
            }
            return oldRect.union(rect).insetBy(dx: -50, dy: -50)
        }
        else if mode == .rotate {
            let p = touch.preciseLocation(in: view)
            guard let aidx = activeIdx else {
                point2 = p
                guard let p1 = point1, let p2 = point2 else {
                    return rect.insetBy(dx: -50, dy: -50)
                }
                
                return doRotate(p1: p1, p2: p2, plusAxis: zeroAnglePositive)
            }
            guard let p1 = point1, let p2 = point2 else {
                return rect.insetBy(dx: -10, dy: -10)
            }
            if zeroAnglePositive == nil {
                if p2.x - p1.x > 0 {
                    zeroAnglePositive = true
                }
                else {
                    zeroAnglePositive = false
                }
            }
            switch aidx {
            case 0:
                point1 = p
            case 1:
                point2 = p
            default:
                break
            }
            activeIdx = nil
            return doRotate(p1: p1, p2: p2, plusAxis: zeroAnglePositive)
        }
        return .null
    }
    
    func cancel() -> CGRect {
        return rect.insetBy(dx: -100, dy: -100)
    }

    func fixColor() {
        mode = .done
        overrideColor = true
        needRegister = true
    }
    
    func setClear() {
        mode = .done
        clear = true
        needRegister = true
    }
    
    func finalizeSelection() {
        selectionImage = nil
        imMaskDilated = nil
        for obj in objects {
            guard let osel = obj as? ObjectSelector else {
                continue
            }
            osel.finalizeSelection()
        }
    }
    
    var selectionImage: UIImage?
    func setSelectionImage() {
        let renderer = UIGraphicsImageRenderer(bounds: imMaskRawRect)
        selectionImage = renderer.image(actions: { rendererContext in
            for obj in objects {
                obj.drawFrozenContext(in: rendererContext.cgContext)
            }
            if imMaskDilated == nil {
                setMaskImage()
            }
            guard let dilated = imMaskDilated, let mask = convertGray(dilated) else {
                return
            }
            rendererContext.cgContext.saveGState()
            rendererContext.cgContext.clip(to: imMaskRawRect, mask: mask)
            rendererContext.cgContext.setFillColor(UIColor.red.withAlphaComponent(0.25).cgColor)
            rendererContext.cgContext.fill(.infinite)
            rendererContext.cgContext.restoreGState()
        })
    }
    
    override func drawInContext(_ context: CGContext) {
        
        context.saveGState()
        context.concatenate(transform)
        UIGraphicsPushContext(context)
        if selectionImage == nil {
            setSelectionImage()
        }
        selectionImage?.draw(at: imMaskRawRect.origin)
        UIGraphicsPopContext()
        context.concatenate(transform.inverted())
        context.restoreGState()

        guard let p1 = point1, let p2 = point2, mode == .rotate else {
            return
        }
        
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [2.0, 3.0])
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: p1.x - 200, y: p1.y))
        context.addLine(to: CGPoint(x: p1.x + 200, y: p1.y))
        context.strokePath()
        context.restoreGState()

        let path = UIBezierPath()
        path.move(to: p1)
        path.addLine(to: p2)
        
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [3.0, 5.0])
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        for p in [p1, p2] {
            context.addArc(center: p, radius: 4.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.fillPath()
        }
        context.setFillColor(UIColor.black.cgColor)
        context.addArc(center: p2, radius: 2.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()
        context.setFillColor(UIColor.red.cgColor)
        context.addArc(center: p1, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.fillPath()
        context.restoreGState()
    }

    override func drawFrozenContext(in context: CGContext) {
        guard !clear else {
            return
        }
        
        context.concatenate(transform)
        if overrideColor {
            context.saveGState()
            var alpha = CGFloat(0)
            // fill
            fillColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            if alpha > 0 {
                context.setAlpha(alpha)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                for (obj,color) in zip(objects,orgColors) {
                    var a = CGFloat(0)
                    color.fillColor.getRed(nil, green: nil, blue: nil, alpha: &a)
                    if let sel = obj as? SelectionObject {
                        sel.fillColor = fillColor.withAlphaComponent(1.0)
                        sel.drawColor = .clear
                        sel.drawWidth = 0
                    }
                    else if let osel = obj as? ObjectSelector {
                        osel.overrideColor = true
                        osel.fillColor = fillColor.withAlphaComponent(1.0)
                        osel.drawColor = .clear
                        osel.drawWidth = 0
                    }
                    else {
                        continue
                    }
                    obj.drawFrozenContext(in: context)
                }
                context.endTransparencyLayer()
            }
            // draw
            drawColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            if alpha > 0 {
                context.setAlpha(alpha)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                for (obj,color) in zip(objects,orgColors) {
                    var a = CGFloat(0)
                    color.drawColor.getRed(nil, green: nil, blue: nil, alpha: &a)
                    if let line = obj as? Line, a > 0 {
                        line.penSize = drawWidth
                        line.penColor = drawColor.withAlphaComponent(1.0)
                    }
                    else if let text = obj as? TextObject, a > 0 {
                        text.textColor = drawColor.withAlphaComponent(1.0)
                    }
                    else if let sel = obj as? SelectionObject, a > 0 {
                        sel.fillColor = .clear
                        sel.drawColor = drawColor.withAlphaComponent(1.0)
                        sel.drawWidth = drawWidth
                    }
                    else if let osel = obj as? ObjectSelector {
                        osel.overrideColor = true
                        osel.fillColor = .clear
                        osel.drawColor = drawColor.withAlphaComponent(1.0)
                        osel.drawWidth = drawWidth
                    }
                    else {
                        continue
                    }
                    obj.drawFrozenContext(in: context)
                }
                context.endTransparencyLayer()
            }
            context.restoreGState()
        }
        else {
            for obj in objects {
                obj.drawFrozenContext(in: context)
            }
        }
        context.concatenate(transform.inverted())
    }
}

