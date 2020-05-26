//
//  Line.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/02.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit

class LinePoint {
    // MARK: Types

    struct PointType: OptionSet {
        // MARK: Properties

        let rawValue: Int

        // MARK: Options

        static let standard = PointType([])
        static let coalesced = PointType(rawValue: 1 << 0)
        static let predicted = PointType(rawValue: 1 << 1)
        static let needsUpdate = PointType(rawValue: 1 << 2)
        static let updated = PointType(rawValue: 1 << 3)
        static let cancelled = PointType(rawValue: 1 << 4)
        static let finger = PointType(rawValue: 1 << 5)
    }

    // MARK: Properties

    var sequenceNumber: Int
    let timestamp: TimeInterval
    var force: CGFloat
    var location: CGPoint
    var preciseLocation: CGPoint
    var estimatedPropertiesExpectingUpdates: UITouch.Properties
    var estimatedProperties: UITouch.Properties
    let type: UITouch.TouchType
    var altitudeAngle: CGFloat
    var azimuthAngle: CGFloat
    let estimationUpdateIndex: NSNumber?
    let isFixedForce: Bool

    var pointType: PointType

    // Clamp the force of a touch to a usable range.
    // - Tag: Magnitude
    var magnitude: CGFloat {
        return force
//        let gamma: CGFloat = 1.0
//        return min(pow(force, 1 / gamma), 1.0)
    }

    // MARK: Initialization

    init(touch: UITouch, sequenceNumber: Int, pointType: PointType, locatedIn view: UIView) {
        self.sequenceNumber = sequenceNumber
        self.type = touch.type
        self.pointType = pointType

        timestamp = touch.timestamp
        location = touch.location(in: view)
        preciseLocation = touch.preciseLocation(in: view)
        azimuthAngle = touch.azimuthAngle(in: view)
        estimatedProperties = touch.estimatedProperties
        estimatedPropertiesExpectingUpdates = touch.estimatedPropertiesExpectingUpdates
        altitudeAngle = touch.altitudeAngle
        isFixedForce = (type != .pencil && touch.force == 0)
        force = (type == .pencil || touch.force > 0) ? touch.force : 1.0

        if !estimatedPropertiesExpectingUpdates.isEmpty {
            self.pointType.formUnion(.needsUpdate)
        }

        estimationUpdateIndex = touch.estimationUpdateIndex
    }

    init(location: CGPoint, sequenceNumber: Int) {
        self.sequenceNumber = sequenceNumber
        self.type = .direct
        self.pointType = .standard
        
        timestamp = TimeInterval()
        self.location = location
        preciseLocation = location
        azimuthAngle = 0
        estimatedProperties = []
        estimatedPropertiesExpectingUpdates = []
        altitudeAngle = 0
        isFixedForce = true
        force = 1.0
        estimationUpdateIndex = nil
    }

    init(location: CGPoint, force: CGFloat, sequenceNumber: Int) {
        self.sequenceNumber = sequenceNumber
        self.type = .pencil
        self.pointType = .standard
        
        timestamp = TimeInterval()
        self.location = location
        preciseLocation = location
        azimuthAngle = 0
        estimatedProperties = []
        estimatedPropertiesExpectingUpdates = []
        altitudeAngle = 0
        isFixedForce = false
        self.force = force
        estimationUpdateIndex = nil
    }

    init(location: CGPoint, force: CGFloat, azimuth: CGFloat, altitude: CGFloat, isPencil: Bool, sequenceNumber: Int) {
        self.sequenceNumber = sequenceNumber
        self.type = isPencil ? .pencil : .direct
        self.pointType = .standard
        
        timestamp = TimeInterval()
        self.location = location
        preciseLocation = location
        azimuthAngle = azimuth
        estimatedProperties = []
        estimatedPropertiesExpectingUpdates = []
        altitudeAngle = altitude
        isFixedForce = false
        self.force = force
        estimationUpdateIndex = nil
    }

    func dragPoint(delta: CGVector) {
        location = CGPoint(x: location.x + delta.dx, y: location.y + delta.dy)
        preciseLocation = CGPoint(x: preciseLocation.x + delta.dx, y: preciseLocation.y + delta.dy)
    }
    
    // Gather the properties on a `UITouch` for force, altitude, azimuth, and location.
    // - Tag: TouchProperties
    func updateWithTouch(_ touch: UITouch) -> Bool {
        guard let estimationUpdateIndex = touch.estimationUpdateIndex, estimationUpdateIndex == estimationUpdateIndex else { return false }

        // An array of the touch properties that may be of interest.
        let touchProperties: [UITouch.Properties] = [.altitude, .azimuth, .force, .location]

        // Iterate through possible properties.
        touchProperties.forEach { (touchProperty) in
            // If an update to this property is not expected, exit scope for this property and continue to the next property.
            guard estimatedPropertiesExpectingUpdates.contains(touchProperty) else { return }
            
            // Update the value of the point with the value from the touch's property.
            switch touchProperty {
                case .force:
                    force = touch.force
                case .azimuth:
                    azimuthAngle = touch.azimuthAngle(in: touch.view)
                case .altitude:
                    altitudeAngle = touch.altitudeAngle
                case .location:
                    location = touch.location(in: touch.view)
                    preciseLocation = touch.preciseLocation(in: touch.view)
                default:
                    ()
            }
            
            if !touch.estimatedProperties.contains(touchProperty) {
                // Flag that this point now has a 'final' value for this property.
                estimatedProperties.subtract(touchProperty)
            }

            if !touch.estimatedPropertiesExpectingUpdates.contains(touchProperty) {
                // Flag that this point is no longer expecting updates for this property.
                estimatedPropertiesExpectingUpdates.subtract(touchProperty)
                
                if estimatedPropertiesExpectingUpdates.isEmpty {
                    // Flag that this point has been updated and no longer needs updates.
                    pointType.subtract(.needsUpdate)
                    pointType.formUnion(.updated)
                }
            }
        }

        return true
    }
}

class Line: DrawObject {

    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {
        return Line(recordId: recordId, data: data, cmd: cmd)
    }

    // MARK: Properties
    
    var penColor = UIColor.black
    var penSize: CGFloat = 6.0
    var useForce: Bool = true
    var useShading: Bool = true
    
    override init() {
        isActive = false
        super.init()
    }
    
    init(color: UIColor, width: CGFloat, force: Bool, shading: Bool) {
        penColor = color
        penSize = width
        useForce = force
        useShading = shading
        isActive = true
        super.init()
    }
    
    override init?(recordId: String?, data: Data, cmd: String) {
        isActive = false
        super.init()
        self.recordId = recordId
        useForce = false
        useShading = false
        if cmd.starts(with: "pen") {
        }
        else if cmd.starts(with: "apen") {
            useForce = true
        }
        else if cmd.starts(with: "spen") {
            useShading = true
        }
        else if cmd.starts(with: "sfpen") {
            useForce = true
            useShading = true
        }
        else {
            return nil
        }
        
        penSize = 6.0
        var Red: CGFloat = 0
        var Green: CGFloat = 0
        var Blue: CGFloat = 0
        var Alpha: CGFloat = 1
        let commands = cmd.split(separator: ";")
        for c in commands {
            if c.starts(with: "size=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("size=") != nil {
                    penSize = CGFloat(scanner.scanDouble() ?? 6.0)
                }
            }
            if c.starts(with: "R=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("R=") != nil {
                    Red = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "G=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("G=") != nil {
                    Green = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "B=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("B=") != nil {
                    Blue = CGFloat(scanner.scanDouble() ?? 0.0)
                }
            }
            if c.starts(with: "A=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("A=") != nil {
                    Alpha = CGFloat(scanner.scanDouble() ?? 1.0)
                }
            }
        }
        penColor = UIColor(red: Red, green: Green, blue: Blue, alpha: Alpha)

        var strokePoints: [CGPoint] = []
        var strokeForce: [CGFloat] = []
        if useShading {
            var azimuth: [CGFloat] = []
            var altitude: [CGFloat] = []
            var isPencil: [Bool] = []
            data.withUnsafeBytes { pointer -> Void in
                let points = Array(pointer.bindMemory(to: Double.self))
                var count = 0
                var x: CGFloat = 0
                var y: CGFloat = 0
                var f: CGFloat = 0
                var az: CGFloat = 0
                var al: CGFloat = 0
                for p in points {
                    switch count % 6 {
                    case 0:
                        x = CGFloat(p)
                    case 1:
                        y = CGFloat(p)
                    case 2:
                        f = CGFloat(p)
                    case 3:
                        az = CGFloat(p)
                    case 4:
                        al = CGFloat(p)
                    default:
                        isPencil += [p > 0]
                        strokePoints += [CGPoint(x: x, y: y)]
                        strokeForce += [f]
                        azimuth += [az]
                        altitude += [al]
                    }
                    count += 1
                }
            }
            for idx in 0..<strokePoints.count {
                let point = LinePoint(location: strokePoints[idx], force: strokeForce[idx], azimuth: azimuth[idx], altitude: altitude[idx], isPencil: isPencil[idx], sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
        else if useForce {
            data.withUnsafeBytes { pointer -> Void in
                let points = Array(pointer.bindMemory(to: Double.self))
                var count = 0
                var x: CGFloat = 0
                var y: CGFloat = 0
                for p in points {
                    if count % 3 == 0 {
                        x = CGFloat(p)
                    }
                    else if count % 3 == 1 {
                        y = CGFloat(p)
                    }
                    else {
                        strokePoints += [CGPoint(x: x, y: y)]
                        strokeForce += [CGFloat(p)]
                    }
                    count += 1
                }
            }

            for (idx, (location, force)) in zip(strokePoints, strokeForce).enumerated() {
                let point = LinePoint(location: location, force: force, sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
        else {
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

            for (idx, location) in strokePoints.enumerated() {
                let point = LinePoint(location: location, sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
    }
    
    // The live line.
    fileprivate var points = [LinePoint]()

    // Use the estimation index of the touch to track points awaiting updates.
    private var pointsWaitingForUpdatesByEstimationIndex = [NSNumber: LinePoint]()

    // Points already drawn into 'frozen' representation of this line.
    fileprivate var committedPoints = [LinePoint]()

    var isActive: Bool
    
    var isComplete: Bool {
        return pointsWaitingForUpdatesByEstimationIndex.isEmpty
    }

    var isFixedForce: Bool {
        return committedPoints.allSatisfy({ $0.isFixedForce })
    }
    
    var isPencil: Bool {
        return committedPoints.allSatisfy({ $0.type == .pencil })
    }
    
    func updateWithTouch(_ touch: UITouch) -> (Bool, CGRect) {
        if let estimationUpdateIndex = touch.estimationUpdateIndex,
            let point = pointsWaitingForUpdatesByEstimationIndex[estimationUpdateIndex] {
            var rect = updateRectForExistingPoint(point)
            let didUpdate = point.updateWithTouch(touch)
            if didUpdate {
                rect = rect.union(updateRectForExistingPoint(point))
            }
            if point.estimatedPropertiesExpectingUpdates == [] {
                pointsWaitingForUpdatesByEstimationIndex.removeValue(forKey: estimationUpdateIndex)
            }
            return (didUpdate, rect)
        }
        return (false, CGRect.null)
    }

    // MARK: Interface

    private func getWidthPath(width: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard let p0 = committedPoints.first else {
            return path
        }
        path.move(to: p0.preciseLocation)
        for i in 1..<committedPoints.count {
            let p0 = committedPoints[i-1].preciseLocation
            let p1 = committedPoints[i].preciseLocation

            let m1 = CGPoint(x: (p1.x + p0.x)/2, y: (p1.y + p0.y)/2)
            let c1 = CGPoint(x: (m1.x + p0.x)/2, y: (m1.y + p0.y)/2)
            let c2 = CGPoint(x: (m1.x + p1.x)/2, y: (m1.y + p1.y)/2)
            path.addCurve(to: p1, controlPoint1: c1, controlPoint2: c2)
        }
        let cgpath = path.cgPath.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10.0)
        return UIBezierPath(cgPath: cgpath)
    }
    
    override var rawHitPath: UIBezierPath {
        return getWidthPath(width: penSize)
    }
    
    override func objectSelectionInside(point: CGPoint) -> Bool {
        let path = getWidthPath(width: penSize + 10)
        return path.contains(point)
    }
    
    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {
        
        var Red: CGFloat = 0
        var Green: CGFloat = 0
        var Blue: CGFloat = 0
        var Alpha: CGFloat = 0
        penColor.getRed(&Red, green: &Green, blue: &Blue, alpha: &Alpha)
        let cmd: String
        if useShading {
            if useForce {
                cmd = String(format: "sfpen;size=%.1f;R=%f;G=%f;B=%f;A=%f", penSize, Red, Green, Blue, Alpha)
            }
            else {
                cmd = String(format: "spen;size=%.1f;R=%f;G=%f;B=%f;A=%f", penSize, Red, Green, Blue, Alpha)
            }
        }
        else if useForce {
            cmd = String(format: "apen;size=%.1f;R=%f;G=%f;B=%f;A=%f", penSize, Red, Green, Blue, Alpha)
        }
        else {
            cmd = String(format: "pen;size=%.1f;R=%f;G=%f;B=%f;A=%f", penSize, Red, Green, Blue, Alpha)
        }
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }
    
    override func getLocationData() -> Data {
        var stroke: [CGPoint] = []
        var force: [CGFloat] = []
        var azimuth: [CGFloat] = []
        var altitude: [CGFloat] = []
        var pencil: [Bool] = []
        
        for point in committedPoints {
            let location = point.preciseLocation
            stroke += [location]
            force += [point.force]
            azimuth += [point.azimuthAngle]
            altitude += [point.altitudeAngle]
            pencil += [point.type == .pencil]
        }
        
        var data = Data()
        if useShading {
            for i in 0..<stroke.count {
                var x1 = Double(stroke[i].x)
                var y1 = Double(stroke[i].y)
                var f1 = Double(force[i])
                var az = Double(azimuth[i])
                var al = Double(altitude[i])
                var pt = Double(pencil[i] ? 1 : 0)

                data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &f1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &az, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &al, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &pt, count: MemoryLayout<Double>.size))
            }
        }
        else if useForce {
            for (p, f) in zip(stroke, force) {
                var x1 = Double(p.x)
                var y1 = Double(p.y)
                var f1 = Double(f)
                data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &f1, count: MemoryLayout<Double>.size))
            }
        }
        else {
            for p in stroke {
                var x1 = Double(p.x)
                var y1 = Double(p.y)
                data.append(Data(bytes: &x1, count: MemoryLayout<Double>.size))
                data.append(Data(bytes: &y1, count: MemoryLayout<Double>.size))
            }
        }
        return data
    }
    
    func addPointOfType(_ pointType: LinePoint.PointType, for touch: UITouch, in view: UIView) -> CGRect {
        let previousPoint = points.last
        let previousSequenceNumber = previousPoint?.sequenceNumber ?? -1
        let point = LinePoint(touch: touch, sequenceNumber: previousSequenceNumber + 1, pointType: pointType, locatedIn: view)

        if let estimationIndex = point.estimationUpdateIndex {
            if !point.estimatedPropertiesExpectingUpdates.isEmpty {
                pointsWaitingForUpdatesByEstimationIndex[estimationIndex] = point
            }
        }

        points.append(point)

        let updateRect = updateRectForLinePoint(point, previousPoint: previousPoint)

        return updateRect
    }

    func removePointsWithType(_ type: LinePoint.PointType) -> CGRect {
        var updateRect = CGRect.null
        var priorPoint: LinePoint?

        points = points.filter { point in
            let keepPoint = !point.pointType.contains(type)

            if !keepPoint {
                var rect = self.updateRectForLinePoint(point)

                if let priorPoint = priorPoint {
                    rect = rect.union(updateRectForLinePoint(priorPoint))
                }

                updateRect = updateRect.union(rect)
            }

            priorPoint = point

            return keepPoint
        }

        return updateRect
    }

    func cancel() -> CGRect {
        // Process each point in the line and accumulate the `CGRect` containing all the points.
        let updateRect = points.reduce(CGRect.null) { accumulated, point in
            // Update the type set to include `.Cancelled`.
            point.pointType.formUnion(.cancelled)

            /*
                Union the `CGRect` for this point with accumulated `CGRect` and return it. The result is
                supplied to the next invocation of the closure.
            */
            return accumulated.union(updateRectForLinePoint(point))
        }

        return updateRect
    }

    fileprivate func calcCurve(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, angle: CGFloat) -> (CGPoint, CGPoint) {
        let xt = { (t: CGFloat) -> CGFloat in
            return (1 - t) * (1 - t) * (1 - t) * p0.x +
                3 * (1 - t) * (1 - t) * t * p1.x +
                3 * (1 - t) * t * t * p2.x +
                t * t * t * p3.x
        }
        let yt = { (t: CGFloat) -> CGFloat in
            return (1 - t) * (1 - t) * (1 - t) * p0.y +
                3 * (1 - t) * (1 - t) * t * p1.y +
                3 * (1 - t) * t * t * p2.y +
                t * t * t * p3.y
        }

        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var a = CGPoint.zero
        var b = CGPoint.zero

        for t: CGFloat in stride(from: 0, to: 1, by: 0.01) {
            let x = xt(t)
            let y = yt(t)
            let rx = x * cos(angle) - y * sin(angle)
            //let ry = x * sin(angle) + y * cos(angle)

            if rx < minX {
                minX = rx
                a = .init(x: x, y: y)
            }
            if rx > maxX {
                maxX = rx
                b = .init(x: x, y: y)
            }
        }
        return (a, b)
    }
    
    // MARK: Drawing

    // Draw line points to the canvas, altering the drawing based on the data originally collected from `UITouch`.
    // - Tag: DrawLine
    override func drawInContext(_ context: CGContext) {
        var maybePriorPoint: LinePoint?
        var maybePriorMagnitude: CGFloat?
        
        var color = UIColor.clear
        var lineWidth: CGFloat = 0

        var alpha: CGFloat = 0
        penColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        context.saveGState()
        context.setAlpha(alpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        if useShading && points.first?.type == .pencil {
            context.setStrokeColor(color.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            var pointsA: [CGPoint] = []
            var pointsB: [CGPoint] = []

            for point in points {
                guard let priorPoint = maybePriorPoint, let priorMagmitude = maybePriorMagnitude else {
                    maybePriorPoint = point
                    maybePriorMagnitude = point.magnitude
                    pointsA += [point.preciseLocation]
                    pointsB += [point.preciseLocation]
                    continue
                }

                let currentMagnitude = (priorMagmitude * 4 + point.magnitude) / 5
                maybePriorMagnitude = currentMagnitude
                
                color = penColor.withAlphaComponent(1.0)
                lineWidth = useForce ? currentMagnitude * penSize * 2.0 : penSize
                
                let location = point.preciseLocation
                let priorLocation = priorPoint.preciseLocation

                context.setFillColor(color.cgColor)
                //context.setStrokeColor(color.cgColor)
                
                let vector = CGVector(dx: location.x - priorLocation.x, dy: location.y - priorLocation.y)
                let angle2 = atan2(vector.dy, vector.dx)
                let angle1 = point.azimuthAngle
                
                let dangle = angle1 - angle2

                let t = (CGFloat.pi / 2 - point.altitudeAngle) / (CGFloat.pi / 2)
                let w = lineWidth * t
                
                let path = UIBezierPath()
                let b0 = CGPoint(x: 0, y: w)
                let b1 = CGPoint(x: -2 * w, y: -2.5 * w)
                let b2 = CGPoint(x: 2 * w, y: -2.5 * w)
                let b3 = b0
                path.move(to: b0)
                path.addCurve(to: b3, controlPoint1: b1, controlPoint2: b2)

                path.apply(CGAffineTransform(rotationAngle: angle1 + .pi / 2))
                path.apply(CGAffineTransform(translationX: location.x, y: location.y))
                
                context.addPath(path.cgPath)
                context.fillPath()
                //context.strokePath()

                let (pb, pa) = calcCurve(p0: b0, p1: b1, p2: b2, p3: b3, angle: dangle)
                
                let rSin1 = sin(angle1 + .pi / 2)
                let rCos1 = cos(angle1 + .pi / 2)
                pointsA += [CGPoint(x: pa.x * rCos1 - pa.y * rSin1 + location.x, y: pa.x * rSin1 + pa.y * rCos1 + location.y)]
                pointsB += [CGPoint(x: pb.x * rCos1 - pb.y * rSin1 + location.x, y: pb.x * rSin1 + pb.y * rCos1 + location.y)]

                maybePriorPoint = point
            }
            
            let path = UIBezierPath()
            if var p0 = pointsA.first, var p9 = pointsB.last {
                path.move(to: p0)
                for p1 in pointsA.dropFirst() {
                    path.addLine(to: p1)
                    p0 = p1
                }
                path.addLine(to: p9)
                for p8 in pointsB.reversed() {
                    path.addLine(to: p8)
                    p9 = p8
                }
            }

            context.addPath(path.cgPath)
            context.fillPath()
            //context.strokePath()
        }
        else {
            for point in points {
                guard let priorPoint = maybePriorPoint, let priorMagmitude = maybePriorMagnitude else {
                    maybePriorPoint = point
                    maybePriorMagnitude = point.magnitude
                    continue
                }
                
                let currentMagnitude = (priorMagmitude + point.magnitude) / 2
                maybePriorMagnitude = currentMagnitude
                
                color = penColor.withAlphaComponent(1.0)
                lineWidth = useForce ? currentMagnitude * penSize * 2.0 : penSize
                
                let location = point.preciseLocation
                let priorLocation = priorPoint.preciseLocation

                let middleLocation = CGPoint(x: (location.x + priorLocation.x)/2, y: (location.y + priorLocation.y)/2)
                let control1Location = CGPoint(x: (middleLocation.x + priorLocation.x)/2, y: (middleLocation.y + priorLocation.y)/2)
                let control2Location = CGPoint(x: (middleLocation.x + location.x)/2, y: (middleLocation.y + location.y)/2)

                let path = UIBezierPath()
                path.move(to: priorLocation)
                path.addCurve(to: location, controlPoint1: control1Location, controlPoint2: control2Location)
                path.apply(transform)
                
                context.setStrokeColor(color.cgColor)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setLineWidth(lineWidth)

                context.addPath(path.cgPath)

                context.strokePath()

                maybePriorPoint = point
            }
        }
        
        context.endTransparencyLayer()
        context.restoreGState()
    }

    func finalizePoints() {
        committedPoints.append(contentsOf: points)
        points.removeAll()
    }
    
    override func drawFrozenContext(in context: CGContext) {
        let committedLine = Line(color: penColor, width: penSize, force: useForce, shading: useShading)
        committedLine.points = committedPoints
        committedLine.drawInContext(context)
    }

    // MARK: Convenience

    private func updateRectForLinePoint(_ point: LinePoint) -> CGRect {
        var rect = CGRect(origin: point.location, size: CGSize.zero)

        // The negative magnitude ensures an outset rectangle.
        let magnitude = -3 * penSize - 2
        rect = rect.insetBy(dx: magnitude, dy: magnitude)

        return rect
    }

    private func updateRectForLinePoint(_ point: LinePoint, previousPoint optionalPreviousPoint: LinePoint? = nil) -> CGRect {
        var rect = CGRect(origin: point.location, size: CGSize.zero)

        var pointMagnitude = penSize

        if let previousPoint = optionalPreviousPoint {
            pointMagnitude = max(pointMagnitude, previousPoint.magnitude)
            rect = rect.union( CGRect(origin: previousPoint.location, size: CGSize.zero))
        }

        // The negative magnitude ensures an outset rectangle.
        let magnitude = -3.0 * pointMagnitude - 2.0
        rect = rect.insetBy(dx: magnitude, dy: magnitude)

        return rect
    }

    private func updateRectForExistingPoint(_ point: LinePoint) -> CGRect {
        var rect = updateRectForLinePoint(point)

        let arrayIndex = point.sequenceNumber - points.first!.sequenceNumber

        if arrayIndex > 0 && arrayIndex < points.count {
            rect = rect.union(updateRectForLinePoint(point, previousPoint: points[arrayIndex - 1]))
        }
        if arrayIndex >= 0 && arrayIndex + 1 < points.count {
            rect = rect.union(updateRectForLinePoint(point, previousPoint: points[arrayIndex + 1]))
        }
        return rect
    }
    
    private func strokeColor(for point: LinePoint) -> UIColor {
        // This color will used by default for `.standard` touches.
        var color = penColor
        
        let pointType = point.pointType
        if pointType.contains(.cancelled) {
            color = UIColor.clear
        }

        return color
    }
}

class DeleteLine: Line {

    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {
        return DeleteLine(recordId: recordId, data: data, cmd: cmd)
    }
    
    init(width: CGFloat, force: Bool, shading: Bool) {
        super.init(color: .clear, width: width, force: force, shading: shading)
    }

    override init?(recordId: String?, data: Data, cmd: String) {
        super.init()
        self.recordId = recordId
        useForce = false
        useShading = false
        if cmd.starts(with: "deletepen") {
        }
        else if cmd.starts(with: "deleteapen") {
            useForce = true
        }
        else if cmd.starts(with: "deletespen") {
            useShading = true
        }
        else if cmd.starts(with: "deletesfpen") {
            useForce = true
            useShading = true
        }
        else {
            return nil
        }
        
        penSize = 6.0
        let commands = cmd.split(separator: ";")
        for c in commands {
            if c.starts(with: "size=") {
                let scanner = Scanner(string: String(c))
                if scanner.scanString("size=") != nil {
                    penSize = CGFloat(scanner.scanDouble() ?? 6.0)
                }
            }
        }
        penColor = .clear

        var strokePoints: [CGPoint] = []
        var strokeForce: [CGFloat] = []
        if useShading {
            var azimuth: [CGFloat] = []
            var altitude: [CGFloat] = []
            var isPencil: [Bool] = []
            data.withUnsafeBytes { pointer -> Void in
                let points = Array(pointer.bindMemory(to: Double.self))
                var count = 0
                var x: CGFloat = 0
                var y: CGFloat = 0
                var f: CGFloat = 0
                var az: CGFloat = 0
                var al: CGFloat = 0
                for p in points {
                    switch count % 6 {
                    case 0:
                        x = CGFloat(p)
                    case 1:
                        y = CGFloat(p)
                    case 2:
                        f = CGFloat(p)
                    case 3:
                        az = CGFloat(p)
                    case 4:
                        al = CGFloat(p)
                    default:
                        isPencil += [p > 0]
                        strokePoints += [CGPoint(x: x, y: y)]
                        strokeForce += [f]
                        azimuth += [az]
                        altitude += [al]
                    }
                    count += 1
                }
            }
            for idx in 0..<strokePoints.count {
                let point = LinePoint(location: strokePoints[idx], force: strokeForce[idx], azimuth: azimuth[idx], altitude: altitude[idx], isPencil: isPencil[idx], sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
        else if useForce {
            data.withUnsafeBytes { pointer -> Void in
                let points = Array(pointer.bindMemory(to: Double.self))
                var count = 0
                var x: CGFloat = 0
                var y: CGFloat = 0
                for p in points {
                    if count % 3 == 0 {
                        x = CGFloat(p)
                    }
                    else if count % 3 == 1 {
                        y = CGFloat(p)
                    }
                    else {
                        strokePoints += [CGPoint(x: x, y: y)]
                        strokeForce += [CGFloat(p)]
                    }
                    count += 1
                }
            }

            for (idx, (location, force)) in zip(strokePoints, strokeForce).enumerated() {
                let point = LinePoint(location: location, force: force, sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
        else {
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

            for (idx, location) in strokePoints.enumerated() {
                let point = LinePoint(location: location, sequenceNumber: idx)
                committedPoints.append(point)
            }
        }
    }

    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {
        
        let cmd: String
        if useShading {
            if useForce {
                cmd = String(format: "deletesfpen;size=%.1f", penSize)
            }
            else {
                cmd = String(format: "deletespen;size=%.1f", penSize)
            }
        }
        else if useForce {
            cmd = String(format: "deleteapen;size=%.1f", penSize)
        }
        else {
            cmd = String(format: "deletepen;size=%.1f", penSize)
        }
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }

    override func drawInContext(_ context: CGContext) {
        var maybePriorPoint: LinePoint?
        var maybePriorMagnitude: CGFloat?
        
        var color = UIColor.clear
        var lineWidth: CGFloat = 0

        context.saveGState()
        context.setBlendMode(.clear)
        
        if useShading && points.first?.type == .pencil {
            context.setStrokeColor(UIColor.clear.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            var pointsA: [CGPoint] = []
            var pointsB: [CGPoint] = []

            for point in points {
                guard let priorPoint = maybePriorPoint, let priorMagmitude = maybePriorMagnitude else {
                    maybePriorPoint = point
                    maybePriorMagnitude = point.magnitude
                    pointsA += [point.preciseLocation]
                    pointsB += [point.preciseLocation]
                    continue
                }

                let currentMagnitude = (priorMagmitude * 4 + point.magnitude) / 5
                maybePriorMagnitude = currentMagnitude
                
                color = penColor.withAlphaComponent(1.0)
                lineWidth = useForce ? currentMagnitude * penSize * 2.0 : penSize
                
                let location = point.preciseLocation
                let priorLocation = priorPoint.preciseLocation

                context.setFillColor(UIColor.clear.cgColor)
                //context.setStrokeColor(color.cgColor)
                
                let vector = CGVector(dx: location.x - priorLocation.x, dy: location.y - priorLocation.y)
                let angle2 = atan2(vector.dy, vector.dx)
                let angle1 = point.azimuthAngle
                
                let dangle = angle1 - angle2

                let t = (CGFloat.pi / 2 - point.altitudeAngle) / (CGFloat.pi / 2)
                let w = lineWidth * t
                
                let path = UIBezierPath()
                let b0 = CGPoint(x: 0, y: w)
                let b1 = CGPoint(x: -2 * w, y: -2.5 * w)
                let b2 = CGPoint(x: 2 * w, y: -2.5 * w)
                let b3 = b0
                path.move(to: b0)
                path.addCurve(to: b3, controlPoint1: b1, controlPoint2: b2)

                path.apply(CGAffineTransform(rotationAngle: angle1 + .pi / 2))
                path.apply(CGAffineTransform(translationX: location.x, y: location.y))
                
                context.addPath(path.cgPath)
                context.fillPath()
                //context.strokePath()

                let (pb, pa) = calcCurve(p0: b0, p1: b1, p2: b2, p3: b3, angle: dangle)
                
                let rSin1 = sin(angle1 + .pi / 2)
                let rCos1 = cos(angle1 + .pi / 2)
                pointsA += [CGPoint(x: pa.x * rCos1 - pa.y * rSin1 + location.x, y: pa.x * rSin1 + pa.y * rCos1 + location.y)]
                pointsB += [CGPoint(x: pb.x * rCos1 - pb.y * rSin1 + location.x, y: pb.x * rSin1 + pb.y * rCos1 + location.y)]

                maybePriorPoint = point
            }
            
            let path = UIBezierPath()
            if var p0 = pointsA.first, var p9 = pointsB.last {
                path.move(to: p0)
                for p1 in pointsA.dropFirst() {
                    path.addLine(to: p1)
                    p0 = p1
                }
                path.addLine(to: p9)
                for p8 in pointsB.reversed() {
                    path.addLine(to: p8)
                    p9 = p8
                }
            }

            context.addPath(path.cgPath)
            context.fillPath()
            //context.strokePath()
        }
        else {
            for point in points {
                guard let priorPoint = maybePriorPoint, let priorMagmitude = maybePriorMagnitude else {
                    maybePriorPoint = point
                    maybePriorMagnitude = point.magnitude
                    continue
                }
                
                let currentMagnitude = (priorMagmitude + point.magnitude) / 2
                maybePriorMagnitude = currentMagnitude
                
                color = penColor.withAlphaComponent(1.0)
                lineWidth = useForce ? currentMagnitude * penSize * 2.0 : penSize
                
                let location = point.preciseLocation
                let priorLocation = priorPoint.preciseLocation

                let middleLocation = CGPoint(x: (location.x + priorLocation.x)/2, y: (location.y + priorLocation.y)/2)
                let control1Location = CGPoint(x: (middleLocation.x + priorLocation.x)/2, y: (middleLocation.y + priorLocation.y)/2)
                let control2Location = CGPoint(x: (middleLocation.x + location.x)/2, y: (middleLocation.y + location.y)/2)

                let path = UIBezierPath()
                path.move(to: priorLocation)
                path.addCurve(to: location, controlPoint1: control1Location, controlPoint2: control2Location)
                path.apply(transform)
                
                context.setStrokeColor(UIColor.clear.cgColor)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.setLineWidth(lineWidth)

                context.addPath(path.cgPath)

                context.strokePath()

                maybePriorPoint = point
            }
        }
        
        context.restoreGState()
    }

    override func drawFrozenContext(in context: CGContext) {
        let committedLine = DeleteLine(width: penSize, force: useForce, shading: useShading)
        committedLine.points = committedPoints
        committedLine.drawInContext(context)
    }
}
