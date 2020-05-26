//
//  DrawView.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/22.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit
import CloudKit
import Compression

class DrawView: UIView {
    enum InputMode {
        case pen
        case move
        case rectSelect
        case penSelect
        case colorpicker
        case lineSelect
        case splineSelect
        case circleSelect
        case ellipseSelect
        case magicSelect
        case objectSelect
        case text
        case paste
        case deletePen
        case objectDeleter
    }
    var prevEreserMode: InputMode = .deletePen
    var prevNormalMode: InputMode = .pen
    var inputMode: InputMode = .pen {
        didSet {
            switch inputMode {
            case .deletePen, .objectDeleter:
                prevEreserMode = inputMode
            default:
                prevNormalMode = inputMode
            }
            onInputModeChanged?(inputMode)
            finalizeSelection()
            DispatchQueue.main.async {
                self.setNeedsDisplay()
            }
        }
    }
    var isSelectionMode: Bool {
        switch inputMode {
        case .rectSelect:
            return true
        case .penSelect:
            return true
        case .lineSelect:
            return true
        case .splineSelect:
            return true
        case .circleSelect:
            return true
        case .ellipseSelect:
            return true
        case .magicSelect:
            return true
        default:
            return false
        }
    }
    enum SelectionModifyMode {
        case none
        case modify
        case append
        case remove
    }
    var selectionModifyMode = SelectionModifyMode.none
    
    var clipboardContentId: UUID?
    private var clipboardContentIdMap: [UUID: String] = [:]
    
    var onInputModeChanged: ((InputMode)->Void)?
    var onColorChanged: ((UIColor)->Void)?
    
    var remoteBoard: RemoteData!
    let reloadSemaphore = DispatchSemaphore(value: 1)
    
    var fillColor = UIColor.clear
    var penColor = UIColor.black
    var penSize: CGFloat = 3.0
    var textFont: UIFont = .systemFont(ofSize: 24.0)
    var usePenForce = false
    var usePenShading = false

    var magicThreshold: Float = 0.0 {
        didSet {
            selectObject?.threshold = magicThreshold
        }
    }
    
    var drawGrid = false
    
    var useFinger: Bool = true

    var snapshotImage: UIImage? {
        return objectContainer.snapshotImage
    }
    
    private var lastReloadTime: Date?
    private var reloadBlock = Date(timeIntervalSince1970: 0)
    private var readCallCount: Int64 = 0

    private var activeObjects = [DrawObject]()
    private var objectContainer: DrawObjectContaier!
    
    // Holds a map of `UITouch` objects to `Line` objects whose touch has not ended yet.
    private var activeLines: [UITouch: Line] = [:]
    
    // Holds a map of `UITouch` objects to `Line` objects whose touch has ended but still has points awaiting updates.
    private var pendingLines: [UITouch: Line] = [:]

    private var selectObject: SelectionObject?
    private var selecting: Bool = false
    private var tapSelection: Bool = false
    private var dragSelection: Bool = false
    private var dragAnchor: CGPoint?
    private var tapStartTime: Date?
    private var objectSelector: ObjectSelector?
    private var selectedTextObject: TextObject?
    private var selectedImageObject: ImageObject?
    private var objectDeleter: ObjectDeleter?
    
    class ColoerPickerObject {
        private var x: CGFloat
        private var y: CGFloat
        private var scale: CGFloat
        private var size: CGSize
        private var color: UIColor
        private var showPos: ShowPosition
        private var image: UIImage?
        private var pixelData: CFData?
        
        enum ShowPosition {
            case lefttop
            case righttop
            case rightbottom
            case leftbottom
        }
        
        var onColorChanged: ((UIColor)->Void)?
        
        init(x: CGFloat, y: CGFloat, scale: CGFloat, size: CGSize) {
            self.x = x
            self.y = y
            self.scale = scale
            self.size = size
            self.color = .clear
            showPos = .rightbottom
        }
        
        func update(frozenImage: CGImage?) {
            guard let cgImage = frozenImage else {
                return
            }
            let outRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            let renderer = UIGraphicsImageRenderer(bounds: outRect)
            image = renderer.image(actions: { rendererContext in
                rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
                rendererContext.fill(.infinite)
                rendererContext.cgContext.draw(cgImage, in: outRect)
            })
            guard let provider = image?.cgImage?.dataProvider else {
                return
            }
            pixelData = provider.data
        }
        
        func update(location: CGPoint, showPos: ShowPosition) {
            x = location.x
            y = location.y
            self.showPos = showPos
                   
            guard x > 0, y > 0, x < size.width, y < size.height else {
                return
            }
            update()
        }
        
        private func update() {
            if pixelData == nil {
                return
            }
            let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

            let bytesPerPixel = image!.cgImage!.bitsPerPixel / 8
            let bytesPerRow = image!.cgImage!.bytesPerRow
            let pixelInfo: Int = bytesPerRow * Int(y * scale) + Int(x * scale) * bytesPerPixel

            let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
            let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
            let b = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
            let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
            color = UIColor(red: r, green: g, blue: b, alpha: a)
            onColorChanged?(color)
        }
        
        func draw(in context: CGContext) {

            guard x > 0, y > 0, x < self.size.width, y < self.size.height else {
                return
            }

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

            context.saveGState()
            context.setShadow(offset: CGSize(width: 4, height: 5), blur: 10)
            context.setFillColor(color.cgColor)

            switch showPos {
            case .lefttop:
                context.setLineWidth(3.0)
                context.setStrokeColor(UIColor.white.cgColor)
                context.stroke(CGRect(x: x - 50, y: y - 50, width: 30, height: 30))

                context.setLineWidth(1.0)
                context.setStrokeColor(UIColor.black.cgColor)
                context.stroke(CGRect(x: x - 50, y: y - 50, width: 30, height: 30))

                context.fill(CGRect(x: x - 50, y: y - 50, width: 30, height: 30))
            case .righttop:
                context.setLineWidth(3.0)
                context.setStrokeColor(UIColor.white.cgColor)
                context.stroke(CGRect(x: x + 20, y: y - 50, width: 30, height: 30))

                context.setLineWidth(1.0)
                context.setStrokeColor(UIColor.black.cgColor)
                context.stroke(CGRect(x: x + 20, y: y - 50, width: 30, height: 30))

                context.fill(CGRect(x: x + 20, y: y - 50, width: 30, height: 30))
            case .rightbottom:
                context.setLineWidth(3.0)
                context.setStrokeColor(UIColor.white.cgColor)
                context.stroke(CGRect(x: x + 20, y: y + 20, width: 30, height: 30))

                context.setLineWidth(1.0)
                context.setStrokeColor(UIColor.black.cgColor)
                context.stroke(CGRect(x: x + 20, y: y + 20, width: 30, height: 30))

                context.fill(CGRect(x: x + 20, y: y + 20, width: 30, height: 30))
            case .leftbottom:
                context.setLineWidth(3.0)
                context.setStrokeColor(UIColor.white.cgColor)
                context.stroke(CGRect(x: x - 50, y: y + 20, width: 30, height: 30))

                context.setLineWidth(1.0)
                context.setStrokeColor(UIColor.black.cgColor)
                context.stroke(CGRect(x: x - 50, y: y + 20, width: 30, height: 30))

                context.fill(CGRect(x: x - 50, y: y + 20, width: 30, height: 30))
            }
            context.restoreGState()
        }
    }
    private var colorPicker: ColoerPickerObject?
    
    enum SelectionMenuResult {
        case modify
        case cut
        case draw
        case fill
        case clearfill
        case copy
        case export
        case object
        case cancel
    }
    var selectionMenuCalled: ((CGRect, @escaping (SelectionMenuResult)->Void)->Void)?

    enum SelectionModifyMenuResult {
        case append
        case remove
        case finish
        case clear
        case cancel
    }
    var selectionModifyMenuCalled: ((CGRect, @escaping (SelectionModifyMenuResult)->Void)->Void)?

    enum ObjectModifyMenuResult {
        case paint
        case rotate
        case clear
        case cancel
    }
    var objectMenuCalled: ((CGRect, @escaping (ObjectModifyMenuResult)->Void)->Void)?

    var textWindowCalled: ((CGRect, String, @escaping (UIFont)->Void, @escaping (String)->Void)->Void)?

    
    private var isLocked = false
    func lockBoard(lock: Bool) {
        isLocked = lock
        reloadAnimate?(isLocked)
        progressAnimate?(nil,"")
    }
    var reloadAnimate: ((Bool)->Void)?
    var progressAnimate: ((Float?, String)->Void)? {
        didSet {
            objectContainer?.progressAnimate = progressAnimate
        }
    }
    
    func finalizeSelection() {
        clearSelectionObject()
        clearObjectSelecter()
        registerText()
        registerImage()
        colorPicker = nil
    }
    
    override func didMoveToWindow() {
        guard let w = window else {
            return
        }
        objectContainer = DrawObjectContaier(rect: bounds, scale: w.screen.scale, boardId: remoteBoard.boardId, writer: { [weak self] (cmd, data, finish) in
            self?.remoteBoard.writeCommand(cmd: cmd, data: data, finish: finish)
            }, imageGetter: { [weak self] (recordId, finish) in
                self?.remoteBoard.getImage(recordId: recordId, finish: finish)
            }, finishChecker: { [weak self] (ret) in
                self?.testSuccess(success: ret)
            })
        objectContainer.onNeedUpdate = { [weak self] in
            if Thread.isMainThread {
                self?.setNeedsDisplay()
            }
            else {
                DispatchQueue.main.async {
                    self?.setNeedsDisplay()
                }
            }
        }
        objectContainer.progressAnimate = progressAnimate
        objectContainer.onImageChanged = { [weak self] image in
            self?.colorPicker?.update(frozenImage: image)
        }
    }
    
    private func drawGrid(in context: CGContext) {
        context.setLineDash(phase: 0, lengths: [2.0, 5.0])
        context.setLineWidth(2.0)
        context.setStrokeColor(UIColor.black.cgColor)
        for i in 1..<10 {
            let x = bounds.width * CGFloat(i) / 10
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
            context.strokePath()
        }
        for i in 1..<10 {
            let y = bounds.height * CGFloat(i) / 10
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
            context.strokePath()
        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        
        if let frozenImage = objectContainer.frozenImage {
            context.draw(frozenImage, in: self.bounds)
        }

        for obj in self.activeObjects {
            obj.drawInContext(context)
        }
        
        if let colorPicker = self.colorPicker {
            colorPicker.draw(in: context)
        }
        
        if self.drawGrid {
            self.drawGrid(in: context)
        }
    }

    // MARK: Actions

    func clear(keepActive: Bool = false) {
        if !keepActive {
            clearSelectionObject()
            clearObjectSelecter()
            selectedImageObject = nil
            selectedTextObject = nil
            colorPicker = nil
            activeObjects.removeAll()
        }
        activeLines.removeAll()
        pendingLines.removeAll()
    }

    // MARK: Convenience

    func drawTouches(_ touches: Set<UITouch>, withEvent event: UIEvent?) {
        var updateRect = CGRect.null

        for touch in touches {
            if !useFinger && touch.type != .pencil {
                continue
            }
            
            // Retrieve a line from `activeLines`. If no line exists, create one.
            let line: Line = activeLines[touch] ?? addActiveLineForTouch(touch)

            /*
                Remove prior predicted points and update the `updateRect` based on the removals. The touches
                used to create these points are predictions provided to offer additional data. They are stale
                by the time of the next event for this touch.
            */
            updateRect = updateRect.union(line.removePointsWithType(.predicted))

            /*
                Incorporate coalesced touch data. The data in the last touch in the returned array will match
                the data of the touch supplied to `coalescedTouchesForTouch(_:)`
            */
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? []
            let coalescedRect = addPointsOfType(.coalesced, for: coalescedTouches, to: line, in: updateRect)
            updateRect = updateRect.union(coalescedRect)

            /*
                Incorporate predicted touch data. This sample draws predicted touches differently; however,
                you may want to use them as inputs to smoothing algorithms rather than directly drawing them.
                Points derived from predicted touches should be removed from the line at the next event for
                this touch.
            */
            let predictedTouches = event?.predictedTouches(for: touch) ?? []
            let predictedRect = addPointsOfType(.predicted, for: predictedTouches, to: line, in: updateRect)
            updateRect = updateRect.union(predictedRect)
        }

        setNeedsDisplay(updateRect)
    }

    private func addActiveLineForTouch(_ touch: UITouch) -> Line {
        if inputMode == .deletePen {
            let newLine = DeleteLine(width: penSize, force: usePenForce, shading: usePenShading)

            activeLines[touch] = newLine

            activeObjects.append(newLine)

            return newLine
        }
        
        let newLine = Line(color: penColor, width: penSize, force: usePenForce, shading: usePenShading)

        activeLines[touch] = newLine

        activeObjects.append(newLine)

        return newLine
    }

    private func addPointsOfType(_ type: LinePoint.PointType, for touches: [UITouch], to line: Line, in updateRect: CGRect) -> CGRect {
        var accumulatedRect = CGRect.null
        var type = type

        for (idx, touch) in touches.enumerated() {
            let isPencil = touch.type == .pencil

            // The visualization displays non-`.pencil` touches differently.
            if !isPencil {
                type.formUnion(.finger)
            }

            // Touches with estimated properties require updates; add this information to the `PointType`.
            if !touch.estimatedProperties.isEmpty {
                type.formUnion(.needsUpdate)
            }

            // The last touch in a set of `.coalesced` touches is the originating touch. Track it differently.
            if type.contains(.coalesced) && idx == touches.count - 1 {
                type.subtract(.coalesced)
                type.formUnion(.standard)
            }

            let touchRect = line.addPointOfType(type, for: touch, in: self)
            accumulatedRect = accumulatedRect.union(touchRect)
        }

        return updateRect.union(accumulatedRect)
    }

    func endTouches(_ touches: Set<UITouch>, cancel: Bool) {
        var updateRect = CGRect.null

        for touch in touches {
            // Skip over touches that do not correspond to an active line.
            guard let line = activeLines[touch] else { continue }

            line.isActive = false
            
            // If this is a touch cancellation, cancel the associated line.
            if cancel { updateRect = updateRect.union(line.cancel()) }

            // If the line is complete (no points needing updates) or updating isn't enabled, move the line to the `frozenImage`.
            if line.isComplete {
                finishLine(line)
            }
            // Otherwise, add the line to our map of touches to lines pending update.
            else {
                pendingLines[touch] = line
            }

            // This touch is ending, remove the line corresponding to it from `activeLines`.
            activeLines.removeValue(forKey: touch)
        }

        setNeedsDisplay(updateRect)
    }

    func updateEstimatedPropertiesForTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            var isPending = false

            // Look to retrieve a line from `activeLines`. If no line exists, look it up in `pendingLines`.
            let possibleLine: Line? = activeLines[touch] ?? {
                let pendingLine = pendingLines[touch]
                isPending = pendingLine != nil
                return pendingLine
            }()

            // If no line is related to the touch, return as there is no additional work to do.
            guard let line = possibleLine else { return }

            switch line.updateWithTouch(touch) {
                case (true, let updateRect):
                    setNeedsDisplay(updateRect)
                default:
                    ()
            }

            // If this update updated the last point requiring an update, move the line to the `frozenImage`.
            if isPending && line.isComplete {
                finishLine(line)
                pendingLines.removeValue(forKey: touch)
            }
        }
    }

    private func finishLine(_ line: Line) {
        // Have the line draw any remaining segments into the `frozenContext`. All should be fixed now.
        line.finalizePoints()

        // Cease tracking this line now that it is finished.
        activeObjects.remove(at: activeObjects.firstIndex(of: line)!)

        // Save to database
        objectContainer.registerObject(newItem: line)
        objectContainer.addActiveObject(newItem: line)
    }

    private func startSelection() -> SelectionObject {
        if let prev = selectObject, !(prev is MultiSelection) {
            setNeedsDisplay(prev.cancel())
            return prev
        }
        let newObject = { () -> SelectionObject in
            if inputMode == .rectSelect {
                let select = RectSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .penSelect {
                let select = PenSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .lineSelect {
                let select = LineSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .circleSelect {
                let select = CircleSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .ellipseSelect {
                let select = EllipseSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .splineSelect {
                let select = SplineSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            if inputMode == .magicSelect {
                let select = MagicSelection()
                if selectObject == nil {
                    activeObjects.append(select)
                }
                return select
            }
            return SelectionObject()
        }()
        
        newObject.bounds = bounds
        newObject.scale = window!.screen.scale
        newObject.container = objectContainer
        newObject.threshold = magicThreshold
        newObject.calcurationStart = { [weak self] start in
            if start {
                self?.reloadAnimate?(true)
            }
        }
        newObject.selectionUpdated = { [weak self] updateRect in
            self?.reloadAnimate?(false)
            self?.setNeedsDisplay(updateRect)
        }
        return newObject
    }
    
    private func fillSelection(sel: SelectionObject, clear: Bool, color: UIColor) {
        guard let i = self.activeObjects.firstIndex(of: sel) else {
            return
        }
        activeObjects.remove(at: i)

        sel.clear = clear
        sel.fillColor = color
        
        objectContainer.registerObject(newItem: sel)
        objectContainer.addActiveObject(newItem: sel)

        let selection = sel.cloneSelection()
        activeObjects.append(selection)
        selectObject = selection
        setNeedsDisplay()
    }

    private func drawSelection(sel: SelectionObject) {
        guard let i = self.activeObjects.firstIndex(of: sel) else {
            return
        }
        activeObjects.remove(at: i)

        sel.clear = false
        sel.fillColor = .clear
        sel.drawColor = penColor
        sel.drawWidth = penSize

        objectContainer.registerObject(newItem: sel)
        objectContainer.addActiveObject(newItem: sel)

        let selection = sel.cloneSelection()
        activeObjects.append(selection)
        selectObject = selection
        setNeedsDisplay()
    }

    private func clearSelectionObject() {
        if let curSelction = selectObject {
            if selectionModifyMode == .none {
                if let i = activeObjects.firstIndex(of: curSelction) {
                    activeObjects.remove(at: i)
                }
                selectObject = nil
            }
            else {
                curSelction.finishSelect()
            }
        }
    }
    
    private func textSelectionStart(_ touch: UITouch) {
        dragAnchor = nil
        guard let curSelction = selectedTextObject else {
            // no selection started yet
            tapSelection = true
            selectedTextObject = TextObject(color: penColor, font: textFont)
            activeObjects.append(selectedTextObject!)
            setNeedsDisplay(selectedTextObject!.beginTouch(touch, in: self))
            return
        }

        if curSelction.continueEditing(touch, in: self) {
            setNeedsDisplay(curSelction.beginTouch(touch, in: self))
            return
        }
        
        tapSelection = true
        dragAnchor = touch.preciseLocation(in: self)
    }
    
    private func selectionStart(_ touch: UITouch) {
        dragAnchor = nil
        guard let curSelction = selectObject else {
            // no selection started yet
            selecting = true
            selectObject = startSelection()
            _ = selectObject?.beginTouch(touch, in: self)
            setNeedsDisplay()
            return
        }

        if selectionModifyMode != .none, let multiSelection = curSelction as? MultiSelection {
            // selection modify mode
            
            if selectionModifyMode == .modify {
                // object control
                if !curSelction.didSelected && !curSelction.continueEditing(touch, in: self) && curSelction.isInside(touch, in: self) {
                    // not finished but not continue editing
                    // and touch inside -> show menu
                }
                else {
                    guard curSelction.didSelected else {
                        // selection continued
                        selecting = true
                        _ = selectObject?.beginTouch(touch, in: self)
                        setNeedsDisplay()
                        return
                    }

                    guard !curSelction.continueEditing(touch, in: self) else {
                        // selection continued
                        selecting = true
                        _ = selectObject?.beginTouch(touch, in: self)
                        setNeedsDisplay()
                        return
                    }
                    guard curSelction.isInside(touch, in: self) else {
                        multiSelection.finishSelect()
                        setNeedsDisplay()
                        return
                    }

                    // selection finished and tap inside
                }
                tapSelection = true
                dragAnchor = touch.preciseLocation(in: self)
                return
            }
            else if selectionModifyMode == .append {
                let newObject = startSelection()
                multiSelection.addUnion(selection: newObject)
                _ = selectObject?.beginTouch(touch, in: self)
                setNeedsDisplay()
            }
            else if selectionModifyMode == .remove {
                let newObject = startSelection()
                multiSelection.addRemove(selection: newObject)
                _ = selectObject?.beginTouch(touch, in: self)
                setNeedsDisplay()
            }
            selectionModifyMode = .modify
            selecting = true
            return
        }
        
        if !curSelction.didSelected && !curSelction.continueEditing(touch, in: self) && curSelction.isInside(touch, in: self) {
            // not finished but not continue editing
            // and touch inside -> show menu
        }
        else {
            guard curSelction.didSelected else {
                // selection continued
                selecting = true
                _ = selectObject?.beginTouch(touch, in: self)
                setNeedsDisplay()
                return
            }

            guard !curSelction.continueEditing(touch, in: self) else {
                // selection continued
                selecting = true
                _ = selectObject?.beginTouch(touch, in: self)
                setNeedsDisplay()
                return
            }

            guard curSelction.isInside(touch, in: self) else {
                // clear selection and start another
                clearSelectionObject()

                selecting = true
                selectObject = startSelection()
                _ = selectObject?.beginTouch(touch, in: self)
                setNeedsDisplay()
                return
            }

            // selection finished and tap inside
        }

        tapSelection = true
        dragAnchor = touch.preciseLocation(in: self)
    }
    
    private func selectionShowMenu(_ touch: UITouch) {
        guard let curSelction = selectObject, tapSelection, !dragSelection else {
            return
        }
        let modifyCallback: (SelectionModifyMenuResult)->Void = { [weak self] ret in
            guard let self = self else {
                return
            }
            switch ret {
            case .append:
                self.selectionModifyMode = .append
            case .remove:
                self.selectionModifyMode = .remove
            case .finish:
                self.selectionModifyMode = .none
            case .clear:
                self.selectionModifyMode = .none
                self.clearSelectionObject()
            case .cancel:
                return
            }
            if let multi = curSelction as? MultiSelection {
                multi.finishSelect()
            }
            else if self.selectionModifyMode != .none {
                let multi = MultiSelection(container: self.objectContainer)
                self.selectObject = multi
                self.activeObjects.remove(at: self.activeObjects.firstIndex(of: curSelction)!)
                multi.addUnion(selection: curSelction)
                multi.finishSelect()
                self.activeObjects.append(multi)
            }
            self.setNeedsDisplay()
        }
        if selectionModifyMode != .none {
            selectionModifyMenuCalled?(curSelction.rect, modifyCallback)
            return
        }
        selectionMenuCalled?(curSelction.rect) { [weak self] ret in
            guard let self = self else {
                return
            }
            switch ret {
            case .modify:
                self.selectionModifyMenuCalled?(curSelction.rect, modifyCallback)
            case .cut:
                self.fillSelection(sel: curSelction, clear: true, color: .clear)
            case .draw:
                self.drawSelection(sel: curSelction)
            case .fill:
                self.fillSelection(sel: curSelction, clear: false, color: self.fillColor)
            case .clearfill:
                self.fillSelection(sel: curSelction, clear: true, color: self.fillColor)
            case .copy:
                guard let image = self.objectContainer.frozenImage else {
                    return
                }
                guard let copyed = curSelction.copy(from: image) else {
                    return
                }
                UIPasteboard.general.image = copyed
            case .export:
                guard let image = self.objectContainer.frozenImage else {
                    return
                }
                guard let copyed = curSelction.copy(from: image) else {
                    return
                }
                let activityVC = UIActivityViewController(activityItems: [copyed], applicationActivities: nil)

                let rect = curSelction.rect
                activityVC.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 0, height: 0)
                activityVC.popoverPresentationController?.sourceView = self
                
                self.parentViewController?.present(activityVC, animated: true, completion: nil)
            case .cancel:
                break
            case .object:
                self.inputMode = .objectSelect
                self.convertSelectionToObjectSelection(selection: curSelction)
            }
        }
    }
    
    private func convertSelectionToObjectSelection(selection: SelectionObject) {
        let newObject = ObjectSelector(container: objectContainer)
        newObject.mode = .add
        activeObjects.append(newObject)
        objectSelector = newObject
        
        for obj in objectContainer.hitTestSelection(selection: selection) {
            newObject.add(selection: obj)
        }
        objectContainer.frozenContextDraw()
    }
    
    private func changeToRotateMode(objSelect: ObjectSelector) {
        if objSelect.needRegister {
            clearObjectSelecter()
            
            let newObject = ObjectSelector(container: objectContainer)
            newObject.mode = .rotate
            newObject.add(selection: objSelect)
            activeObjects.append(newObject)
            objectSelector = newObject
            objectContainer.frozenContextDraw()
        }
        else {
            objSelect.mode = .rotate
        }
    }
    
    private func objectShowMenu(_ touch: UITouch) {
        guard let objSelect = objectSelector, !dragSelection else {
            return
        }
        guard objSelect.objects.count > 0 else {
            return
        }
        objectMenuCalled?(objSelect.rect) { [weak self] ret in
            guard let self = self else {
                return
            }
            switch ret {
            case .paint:
                objSelect.drawColor = self.penColor
                objSelect.drawWidth = self.penSize
                objSelect.fillColor = self.fillColor
                objSelect.fixColor()
                self.clearObjectSelecter()
            case .rotate:
                self.changeToRotateMode(objSelect: objSelect)
            case .clear:
                objSelect.setClear()
                self.clearObjectSelecter()
            case .cancel:
                return
            }
            self.setNeedsDisplay()
        }
    }
    
    private func textWindowShow(_ touch: UITouch) {
        guard let textSelection = selectedTextObject else {
            return
        }
        textWindowCalled?(textSelection.rect, textSelection.str, { [weak self] newFont in
            guard let self = self else {
                return
            }
            self.textFont = newFont
            textSelection.font = newFont
            self.setNeedsDisplay(textSelection.rect)
        }) { [weak self] str in
            guard let self = self else {
                return
            }
            textSelection.str = str
            self.setNeedsDisplay(textSelection.rect)
        }
    }
    
    private func windowAreaCheck(_ touch: UITouch) -> ColoerPickerObject.ShowPosition {
        let wp = touch.location(in: parentViewController?.view)
        var left = false
        var bottom = true
        if wp.x < parentViewController!.view.window!.bounds.width * 0.2 {
            left = false
        }
        if wp.x > parentViewController!.view.window!.bounds.width * 0.8 {
            left = true
        }
        if wp.y < parentViewController!.view.window!.bounds.height * 0.2 {
            bottom = true
        }
        if wp.y > parentViewController!.view.window!.bounds.height * 0.8 {
            bottom = false
        }
        if left {
            if bottom {
                return .leftbottom
            }
            return .lefttop
        }
        if bottom {
            return .rightbottom
        }
        return .righttop
    }
    
    private func objectSelectionStart(_ touch: UITouch) {
        dragAnchor = touch.preciseLocation(in: self)
        tapStartTime = Date()
        
        if let objSelction = objectSelector {
            let p = touch.preciseLocation(in: self)
            if objSelction.mode == .done, objSelction.needRegister, !objSelction.hitPath.contains(p) {
                objectContainer.registerObject(newItem: objSelction)
                objectContainer.addActiveObject(newItem: objSelction)
                if let i = activeObjects.firstIndex(of: objSelction) {
                    activeObjects.remove(at: i)
                }

                let newObject = ObjectSelector(container: objectContainer)
                newObject.mode = .add
                activeObjects.append(newObject)
                objectSelector = newObject
            }
            if objSelction.mode == .rotate, objSelction.rotateFinished(touch, in: self) {
                objectContainer.registerObject(newItem: objSelction)
                objectContainer.addActiveObject(newItem: objSelction)
                if let i = activeObjects.firstIndex(of: objSelction) {
                    activeObjects.remove(at: i)
                }

                let newObject = ObjectSelector(container: objectContainer)
                newObject.mode = .add
                activeObjects.append(newObject)
                objectSelector = newObject
            }
        }
        else {
            let newObject = ObjectSelector(container: objectContainer)
            newObject.mode = .add
            activeObjects.append(newObject)
            objectSelector = newObject
        }
        if let updateRect = objectSelector?.beginTouch(touch, in: self) {
            setNeedsDisplay(updateRect)
        }
    }
    
    private func clearObjectSelecter() {
        if let osel = objectSelector {
            if osel.objects.count > 0 {
                if osel.needRegister {
                    osel.finalizeSelection()
                    objectContainer.addActiveObject(newItem: osel)
                    objectContainer.registerObject(newItem: osel)
                 }
                else {
                    osel.cancelAll()
                }
            }

            if let i = activeObjects.firstIndex(of: osel) {
                activeObjects.remove(at: i)
            }
            objectSelector = nil
        }
    }

    private func registerText() {
        if let t = selectedTextObject {
            if !t.str.isEmpty {
                objectContainer.addActiveObject(newItem: t)
                objectContainer.registerObject(newItem: t)
            }

            if let i = activeObjects.firstIndex(of: t) {
                activeObjects.remove(at: i)
            }
            selectedTextObject = nil
            setNeedsDisplay()
        }
    }

    private func registerImage() {
        if let im = selectedImageObject {
            objectContainer.addActiveObject(newItem: im)
            objectContainer.registerObject(newItem: im)

            if let i = activeObjects.firstIndex(of: im) {
                activeObjects.remove(at: i)
            }
            selectedImageObject = nil
            setNeedsDisplay()
        }
    }

    // MARK: Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        reloadBlock = Date()
        guard !isLocked else {
            return
        }
        if inputMode == .pen || inputMode == .deletePen {
            drawTouches(touches, withEvent: event)
        }
        else if inputMode == .objectDeleter {
            objectDeleter = ObjectDeleter(container: objectContainer)
        }
        else if inputMode == .text, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            textSelectionStart(touch)
        }
        else if inputMode == .paste, let touch = touches.first, selectedTextObject != nil {
            if !useFinger && touch.type != .pencil {
                return
            }
            textSelectionStart(touch)
        }
        else if inputMode == .paste, let touch = touches.first, let imageObject = selectedImageObject {
            if !useFinger && touch.type != .pencil {
                return
            }
            dragAnchor = nil
            if imageObject.continueEditing(touch, in: self) {
                setNeedsDisplay(imageObject.beginTouch(touch, in: self))
                return
            }
            
            tapSelection = true
            dragAnchor = touch.preciseLocation(in: self)
        }
        else if isSelectionMode, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            selectionStart(touch)
        }
        else if inputMode == .objectSelect, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            objectSelectionStart(touch)
        }
        else if inputMode == .colorpicker, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            let location = touch.location(in: self)
            colorPicker = ColoerPickerObject(x: location.x, y: location.y, scale: self.window!.screen.scale, size: objectContainer.windowRect.size)
            colorPicker?.onColorChanged = { color in
                self.penColor = color
                self.fillColor = color
                self.onColorChanged?(color)
            }
            colorPicker?.update(frozenImage: objectContainer.frozenImage)
            colorPicker?.update(location: location, showPos: windowAreaCheck(touch))
            setNeedsDisplay()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        reloadBlock = Date()
        guard !isLocked else {
            return
        }
        if inputMode == .pen || inputMode == .deletePen {
            drawTouches(touches, withEvent: event)
        }
        else if let deleter = objectDeleter, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            let p = touch.preciseLocation(in: self)
            let objs = objectContainer.hitTestObject(point: p)
            objs.forEach({ deleter.add(selection: $0) })
        }
        else if selecting, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if let updateRect = selectObject?.moveTouch(touch, in: self) {
                setNeedsDisplay(updateRect)
            }
        }
        else if let objectSelector = objectSelector, let touch = touches.first, objectSelector.mode == .rotate {
            if !useFinger && touch.type != .pencil {
                return
            }
            setNeedsDisplay(objectSelector.moveTouch(touch, in: self))
        }
        else if let anchor = dragAnchor, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            let location = touch.preciseLocation(in: self)
            let vector = CGVector(dx: location.x - anchor.x, dy: location.y - anchor.y)
            if dragSelection {
                if let updateRect = selectedImageObject?.dragObject(delta: vector) {
                    setNeedsDisplay(updateRect)
                }
                else if let updateRect = selectedTextObject?.dragObject(delta: vector) {
                    setNeedsDisplay(updateRect)
                }
                else if let updateRect = objectSelector?.translateObject(delta: vector) {
                    setNeedsDisplay(updateRect)
                }
                else if let updateRect = selectObject?.dragObject(delta: vector) {
                    setNeedsDisplay(updateRect)
                }
                dragAnchor = location
                return
            }
            if max(abs(vector.dx), abs(vector.dy)) > 10 {
                dragSelection = true
                tapSelection = false
            }
        }
        else if let imageObject = selectedImageObject, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            setNeedsDisplay(imageObject.moveTouch(touch, in: self))
        }
        else if let textObject = selectedTextObject, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            setNeedsDisplay(textObject.moveTouch(touch, in: self))
        }
        else if inputMode == .colorpicker, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if let colorPicker = colorPicker {
                let location = touch.location(in: self)
                colorPicker.update(location: location, showPos: windowAreaCheck(touch))
                setNeedsDisplay()
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        defer {
            tapStartTime = nil
            dragAnchor = nil
            dragSelection = false
            tapSelection = false
        }
        reloadBlock = Date()
        guard !isLocked else {
            return
        }
        if inputMode == .pen || inputMode == .deletePen {
            drawTouches(touches, withEvent: event)
            endTouches(touches, cancel: false)
        }
        else if let deleter = objectDeleter {
            if deleter.objects.count > 0 {
                objectContainer.addActiveObject(newItem: deleter)
                objectContainer.registerObject(newItem: deleter)
                objectContainer.frozenContextDraw()
            }
            objectDeleter = nil
        }
        else if selecting, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            selecting = false
            if let updateRect = selectObject?.finishTouch(touch, in: self, cancel: false) {
                setNeedsDisplay(updateRect)
            }
        }
        else if let objectSelector = objectSelector, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if -(tapStartTime?.timeIntervalSinceNow ?? 0) > 0.25, objectSelector.mode != .rotate {
                objectShowMenu(touch)
            }
            else {
                setNeedsDisplay(objectSelector.finishTouch(touch, in: self, cancel: false))
                if objectSelector.mode == .done {
                    clearObjectSelecter()
                }
            }
        }
        else if let imageObject = selectedImageObject, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if tapSelection {
                if !imageObject.hitPath.contains(touch.preciseLocation(in: self)) {
                    registerImage()
                    return
                }
            }
            else if !dragSelection {
                setNeedsDisplay(imageObject.finishTouch(touch, in: self, cancel: false))
            }
        }
        else if let textObject = selectedTextObject, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if tapSelection, dragAnchor != nil {
                if !textObject.hitPath.contains(touch.preciseLocation(in: self)) {
                    registerText()
                    return
                }
            }
            else if !dragSelection {
                setNeedsDisplay(textObject.finishTouch(touch, in: self, cancel: false))
            }
            if tapSelection {
                textWindowShow(touch)
            }
        }
        else if tapSelection, let touch = touches.first {
            selectionShowMenu(touch)
        }
        else if inputMode == .colorpicker, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            if let colorPicker = colorPicker {
                let location = touch.location(in: self)
                colorPicker.update(location: location, showPos: windowAreaCheck(touch))
                setNeedsDisplay()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        reloadBlock = Date()
        dragAnchor = nil
        tapStartTime = nil
        guard !isLocked else {
            return
        }
        if inputMode == .pen || inputMode == .deletePen {
            endTouches(touches, cancel: true)
        }
        else if selecting, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            selecting = false
            if let updateRect = selectObject?.finishTouch(touch, in: self, cancel: true) {
                setNeedsDisplay(updateRect)
            }
        }
        else if let objectSelector = objectSelector, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            setNeedsDisplay(objectSelector.finishTouch(touch, in: self, cancel: true))
        }
        else if let textObject = selectedTextObject, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            setNeedsDisplay(textObject.finishTouch(touch, in: self, cancel: true))
        }
        else if inputMode == .colorpicker, let touch = touches.first {
            if !useFinger && touch.type != .pencil {
                return
            }
            colorPicker = nil
            setNeedsDisplay()
        }
    }
    
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        super.touchesEstimatedPropertiesUpdated(touches)
        
        updateEstimatedPropertiesForTouches(touches)
    }

    

    
    private func testSuccess(success: Bool?) {
        guard let success = success else {
            self.connectionFailed()
            return
        }
        if !success {
            self.deletedBoard()
            return
        }
    }
    
    private func connectionFailed() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Failed to connect".localized, message: "Failed to connect database. Storkes may be lost.".localized, preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default) { action in
                self.parentViewController?.dismiss(animated: true) {
                    self.remoteBoard.unsubscribe()
                }
            }
            alert.addAction(defaultAction)
            self.parentViewController?.present(alert, animated: true, completion: nil)
        }
    }

    private func undefinedCommand() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Please update".localized, message: "Undefined command detected. Please update app.".localized, preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default) { action in
                self.parentViewController?.dismiss(animated: true) {
                    self.remoteBoard.unsubscribe()
                }
            }
            alert.addAction(defaultAction)
            self.parentViewController?.present(alert, animated: true, completion: nil)
        }
    }

    private func deletedBoard() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Board deleted".localized, message: "This board has beed deleted by other user.".localized, preferredStyle: .alert)
            let defaultAction = UIAlertAction(title: "OK", style: .default) { action in
                self.parentViewController?.dismiss(animated: true) {
                    self.remoteBoard.unsubscribe()
                }
            }
            alert.addAction(defaultAction)
            self.parentViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func undo() {
        colorPicker = nil
        clearObjectSelecter()
        RemoteClone.lastUndoableRecord(boardId: remoteBoard.boardId) { id in
            guard let id = id else {
                return
            }
            print("undo")
            self.lockBoard(lock: true)
            RemoteClone.undoRecord(remoteId: id) {
                self.clear()
                self.reloadLocal(useCls: false)
            }
            self.remoteBoard.deleteCommand(recordId: id)
        }
    }

    func redo() {
        colorPicker = nil
        clearObjectSelecter()
        RemoteClone.lastRedoableRecord(boardId: remoteBoard.boardId) { id in
            guard let id = id else {
                return
            }
            print("redo")
            self.lockBoard(lock: true)
            RemoteClone.redoRecord(remoteId: id) {
                self.clear()
                self.reloadLocal(useCls: false)
            }
            self.remoteBoard.undeleteCommand(recordId: id)
        }
    }

    func reloadLocal(from: Date = Date(timeIntervalSince1970: 0), useCls: Bool = true, finish: (()->Void)? = nil) {
        var err = false
        RemoteClone.decodeBoard(remote: remoteBoard, time: from, finish: { [weak self] in
            if err {
                self?.undefinedCommand()
            }
            DrawObject.group.notify(queue: .global()) {
                self?.objectContainer.frozenContextDraw()
                self?.lockBoard(lock: false)
                finish?()
            }
        }) { [weak self] recordId, cmd, data, time in
            guard let cmd = cmd, let data = data else {
                if let recordId = recordId {
                    print("remove")
                    self?.objectContainer.removeFinishedObject(recordId: recordId)
                }
                return
            }
            guard let self = self else {
                return
            }
            while self.objectContainer == nil {
                RunLoop.current.run(until: Date.init(timeIntervalSinceNow: 0.1))
            }
            if let newObject = DrawObject.create(recordId: recordId, data: data, cmd: cmd, container: self.objectContainer) {
                self.objectContainer.addFinishedObject(newItem: newObject)
            }
            else if cmd.starts(with: "cls") {
                self.clear(keepActive: true)
                self.objectContainer.cls(time: time)
                if useCls {
                    RemoteClone.deleteAllstroke(boardId: self.remoteBoard.boardId, before: time)
                }
            }
            else {
                err = true
            }
        }
    }
    
    func readStroke(finish: (()->Void)? = nil) {
        OSAtomicIncrement64Barrier(&readCallCount)
        print("readStroke\(readCallCount)")
        guard reloadSemaphore.wait(timeout: .now() + 1) == .success else {
            print("readStroke postpone")
            OSAtomicDecrement64Barrier(&readCallCount)
            DispatchQueue.global().asyncAfter(deadline: .now()+10) {
                if self.readCallCount == 0 {
                    self.readStroke(finish: finish)
                }
            }
            return
        }
        if reloadBlock.addingTimeInterval(2) > Date() {
            print("readStroke postpone(user)")
            reloadSemaphore.signal()
            OSAtomicDecrement64Barrier(&readCallCount)
            DispatchQueue.global().asyncAfter(deadline: .now()+10) {
                if self.readCallCount == 0 {
                    self.readStroke(finish: finish)
                }
            }
            return
        }
        guard OSAtomicDecrement64Barrier(&readCallCount) == 0 else {
            self.reloadSemaphore.signal()
            return
        }

        let finish = {
            self.reloadSemaphore.signal()
            finish?()
        }
        print("readStroke")
        lockBoard(lock: true)
        remoteBoard.isValid() { success in
            guard let success = success else {
                self.connectionFailed()
                return
            }
            guard success else {
                self.deletedBoard()
                return
            }
            
            if let t = self.lastReloadTime {
                self.lastReloadTime = Date() - 10
                self.remoteBoard.readStroke(from: t) {
                    self.clear(keepActive: true)
                    self.reloadLocal() {
                        finish()
                    }
                }
            }
            else {
                self.lastReloadTime = Date() - 10
                RemoteClone.lasttimeBoard(remote: self.remoteBoard) { d in
                    self.remoteBoard.readStroke(from: d) {
                        self.clear(keepActive: true)
                        self.reloadLocal() {
                            finish()
                        }
                    }
                }
            }
        }
    }
        
    func destoryAllStroke() {
        clear()
        objectContainer.clearAll()
        clipboardContentIdMap.removeAll()
        
        remoteBoard.destoryAllStroke()
        RemoteClone.deleteAllstroke(boardId: self.remoteBoard.boardId)
    }
    
    func pasteAt(at point: CGPoint) {
        inputMode = .paste
        if UIPasteboard.general.hasStrings, let str = UIPasteboard.general.string {
            selectedTextObject = TextObject(color: penColor, font: textFont)
            activeObjects.append(selectedTextObject!)
            selectedTextObject?.str = str
            selectedTextObject?.setFitSize(center: point)
            setNeedsDisplay(selectedTextObject!.rect)
        }
        else if UIPasteboard.general.hasImages, let image = UIPasteboard.general.image {
            if let contentId = clipboardContentId, let recordId = clipboardContentIdMap[contentId] {
                lockBoard(lock: true)
                let newObject = ImageObject(imageId: recordId)
                selectedImageObject = newObject
                newObject.loadImage(container: objectContainer) { success in
                    if success {
                        self.activeObjects.append(newObject)
                        newObject.setFitSize(center: point)
                        if Thread.isMainThread {
                            self.setNeedsDisplay(newObject.rect)
                        }
                        else {
                            DispatchQueue.main.async {
                                self.setNeedsDisplay(newObject.rect)
                            }
                        }
                    }
                    self.lockBoard(lock: false)
                }
            }
            else if let contentId = clipboardContentId {
                var recordId: String?
                lockBoard(lock: true)
                recordId = remoteBoard.addImage(image: image) { [weak self] success in
                    self?.testSuccess(success: success)
                    if let success = success, success, let recordId = recordId, let self = self {
                        PasteImageCache.saveImage(recordId: recordId, image: image)
                        let newObject = ImageObject(imageId: recordId)
                        self.selectedImageObject = newObject
                        newObject.loadImage(container: self.objectContainer) { success in
                            if success {
                                self.activeObjects.append(newObject)
                                newObject.setFitSize(center: point)
                                if Thread.isMainThread {
                                    self.setNeedsDisplay(newObject.rect)
                                }
                                else {
                                    DispatchQueue.main.async {
                                        self.setNeedsDisplay(newObject.rect)
                                    }
                                }
                            }
                            self.lockBoard(lock: false)
                        }
                    }
                    else {
                        self?.clipboardContentIdMap[contentId] = nil
                    }
                    self?.lockBoard(lock: false)
                }
                if recordId == nil {
                    lockBoard(lock: false)
                }
                self.clipboardContentIdMap[contentId] = recordId
            }
        }
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        get {
            var parentResponder: UIResponder? = self
            while true {
                guard let nextResponder = parentResponder?.next else { return nil }
                if let viewController = nextResponder as? UIViewController {
                    return viewController
                }
                parentResponder = nextResponder
            }
        }
    }
}
