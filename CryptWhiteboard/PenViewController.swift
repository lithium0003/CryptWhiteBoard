//
//  PenViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/25.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

class PenViewController: UIViewController {

    @IBOutlet weak var penOrFillSegment: UISegmentedControl!
    @IBOutlet weak var penOptionStack: UIStackView!
    @IBOutlet weak var fillOptionStack: UIStackView!
    @IBOutlet weak var pensizeLabel: UILabel!
    @IBOutlet weak var pensizeSlider: UISlider!
    @IBOutlet weak var filldemoView: FillDemoView!
    @IBOutlet weak var pendemoView: PenSizeDemoView!
    @IBOutlet weak var colorPickerView: ColorPickerView!
    @IBOutlet weak var alphaSlider: UISlider!
    @IBOutlet weak var alphaLabel: UILabel!
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var penForceSwitch: UISwitch!
    @IBOutlet weak var penShadingSwitch: UISwitch!
    @IBOutlet weak var clearColorButton: UIButton!
    @IBOutlet weak var blackColorButton: UIButton!
    @IBOutlet weak var whiteColorButton: UIButton!
    let paletteView = ColorPaletteView()
    
    let maxPenSize: CGFloat = 100.0
    let minPenSize: CGFloat = 0.1

    var penSize: CGFloat = 0.0 {
        didSet {
            if oldValue != penSize, isViewLoaded {
                pensizeSlider.value = Float((penSize - minPenSize) / (maxPenSize - minPenSize))
                pensizeLabel.text = String(format: "%.1f", penSize)
                pendemoView.penSize = penSize
                pendemoView.setNeedsDisplay()
                onPenSizeValueChanged?(penSize)
            }
        }
    }
    var penColor: UIColor = .black {
        didSet {
            if oldValue != penColor, isViewLoaded {
                colorPickerView.selectedColor = penColor
                colorPickerView.setNeedsDisplay()
                pendemoView.penColor = penColor.withAlphaComponent(penAlpha)
                pendemoView.setNeedsDisplay()
                onPenColorChanged?(penColor.withAlphaComponent(penAlpha))
            }
        }
    }
    var fillColor: UIColor = .clear {
        didSet {
            if oldValue != fillColor, isViewLoaded {
                colorPickerView.selectedColor = fillColor
                colorPickerView.setNeedsDisplay()
                filldemoView.fillColor = fillColor.withAlphaComponent(fillAlpha)
                filldemoView.setNeedsDisplay()
                onFillColorChanged?(fillColor.withAlphaComponent(fillAlpha))
            }
        }
    }
    var alpha: CGFloat = -1 {
        didSet {
            if oldValue != alpha, isViewLoaded {
                alphaSlider.value = Float(alpha)
                alphaLabel.text = String(format: "%.2f", alpha)
                if penOrFillSegment.selectedSegmentIndex == 0 {
                    penAlpha = alpha
                }
                else {
                    fillAlpha = alpha
                }
            }
        }
    }
    var penAlpha: CGFloat = -1 {
        didSet {
            if oldValue != penAlpha, isViewLoaded {
                pendemoView.penColor = penColor.withAlphaComponent(penAlpha)
                pendemoView.setNeedsDisplay()
                onPenColorChanged?(penColor.withAlphaComponent(penAlpha))
            }
        }
    }
    var fillAlpha: CGFloat = -1 {
        didSet {
            if oldValue != fillAlpha, isViewLoaded {
                filldemoView.fillColor = fillColor.withAlphaComponent(fillAlpha)
                filldemoView.setNeedsDisplay()
                onFillColorChanged?(fillColor.withAlphaComponent(fillAlpha))
            }
        }
    }
    var penForce: Bool = true
    var penShading: Bool = true
    var fillClear: Bool = true
    var onPenSizeValueChanged: ((CGFloat)->Void)?
    var onPenColorChanged: ((UIColor)->Void)?
    var onPenForceChanged: ((Bool)->Void)?
    var onPenShadingChanged: ((Bool)->Void)?
    var onFillColorChanged: ((UIColor)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        pendemoView.layer.cornerRadius = 10
        pendemoView.layer.masksToBounds = true
        penColor.getRed(nil, green: nil, blue: nil, alpha: &penAlpha)
        fillColor.getRed(nil, green: nil, blue: nil, alpha: &fillAlpha)
        colorPickerView.onPenColorChanged = { [weak self] c in
            guard let self = self else {
                return
            }
            if self.penOrFillSegment.selectedSegmentIndex == 0 {
                self.penColor = c
            }
            else {
                self.fillColor = c
            }
        }
        mainStackView.addArrangedSubview(paletteView)
        paletteView.translatesAutoresizingMaskIntoConstraints = false
        paletteView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        paletteView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        paletteView.onPenColorChanged = { [weak self] c in
            guard let self = self else {
                return
            }
            if self.penOrFillSegment.selectedSegmentIndex == 0 {
                self.penColor = c
            }
            else {
                self.fillColor = c
            }
        }
        paletteView.onGetCurrentColor = { [weak self] in
            guard let self = self else {
                return .black
            }
            if self.penOrFillSegment.selectedSegmentIndex == 0 {
                return self.penColor.withAlphaComponent(1.0)
            }
            return self.fillColor.withAlphaComponent(1.0)
        }
        penForceSwitch.isOn = penForce
        penShadingSwitch.isOn = penShading
        if penOrFillSegment.selectedSegmentIndex == 0 {
            penOptionStack.isHidden = false
            fillOptionStack.isHidden = true
            alpha = penAlpha
            colorPickerView.selectedColor = penColor
            colorPickerView.setNeedsDisplay()
        }
        else {
            penOptionStack.isHidden = true
            fillOptionStack.isHidden = false
            alpha = fillAlpha
            colorPickerView.selectedColor = fillColor
            colorPickerView.setNeedsDisplay()
        }
        pensizeSlider.value = Float((penSize - minPenSize) / (maxPenSize - minPenSize))
        pensizeLabel.text = String(format: "%.1f", penSize)
        pendemoView.penSize = penSize
        pendemoView.setNeedsDisplay()
    }
    
    @IBAction func penOrFillSegmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
                penOptionStack.isHidden = false
                fillOptionStack.isHidden = true
                alpha = penAlpha
                pendemoView.penColor = penColor.withAlphaComponent(penAlpha)
                pendemoView.setNeedsDisplay()
                colorPickerView.selectedColor = penColor
                colorPickerView.setNeedsDisplay()
            }
            else {
                penOptionStack.isHidden = true
                fillOptionStack.isHidden = false
                alpha = fillAlpha
                filldemoView.fillColor = fillColor.withAlphaComponent(fillAlpha)
                filldemoView.setNeedsDisplay()
                colorPickerView.selectedColor = fillColor
                colorPickerView.setNeedsDisplay()
            }
    }
    @IBAction func pensizeChanged(_ sender: UISlider) {
        penSize = CGFloat(sender.value) * (maxPenSize - minPenSize) + minPenSize
    }
    
    @IBAction func alphaChanged(_ sender: UISlider) {
        alpha = CGFloat(sender.value)
    }
    
    @IBAction func penForceChanged(_ sender: UISwitch) {
        penForce = sender.isOn
        onPenForceChanged?(penForce)
    }
    
    @IBAction func penShadingChanged(_ sender: UISwitch) {
        penShading = sender.isOn
        onPenShadingChanged?(penShading)
    }
    
    @IBAction func fillFixedColorTap(_ sender: UIButton) {
        switch sender {
        case clearColorButton:
            fillColor = .clear
            alpha = 0
        case blackColorButton:
            fillColor = .black
            alpha = 1
        case whiteColorButton:
            fillColor = .white
            alpha = 1
        default:
            return
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

class PenSizeDemoView: UIView {
    var penSize: CGFloat = 6.0
    var penColor = UIColor.black
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        path.lineWidth = penSize
        path.lineCapStyle = CGLineCap.round
        path.lineJoinStyle = CGLineJoin.round
        path.move(to: CGPoint(x: frame.width / 10, y: frame.height / 2))
        path.addLine(to: CGPoint(x: frame.width * 9 / 10, y: frame.height / 2))
        penColor.setStroke()
        path.stroke()
    }
}

class FillDemoView: UIView {
    var fillColor = UIColor.clear
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        fillColor.setFill()
        context?.fill(bounds)
    }
}

class ColorPickerView: UIView {
    let saturationExponentTop:Float = 2.0
    let saturationExponentBottom:Float = 1.3
    let elementSize: CGFloat = 1.0
    
    var selectedColor: UIColor = .black
    var onPenColorChanged: ((UIColor)->Void)?

    var colorImage: UIImage?
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if let colorImage = colorImage {
            colorImage.draw(at: .zero)
        }
        else {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            colorImage = renderer.image(actions: { rendererContext in
                for y : CGFloat in stride(from: 0.0 ,to: rect.height, by: elementSize) {
                    var saturation = y < rect.height / 2.0 ? CGFloat(2 * y) / rect.height : 2.0 * CGFloat(rect.height - y) / rect.height
                    saturation = CGFloat(powf(Float(saturation), y < rect.height / 2.0 ? saturationExponentTop : saturationExponentBottom))
                    let brightness = y < rect.height / 2.0 ? CGFloat(1.0) : 2.0 * CGFloat(rect.height - y) / rect.height
                    for x : CGFloat in stride(from: 0.0 ,to: rect.width, by: elementSize) {
                        let hue = x / rect.width
                        let color = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
                        rendererContext.cgContext.setFillColor(color.cgColor)
                        rendererContext.cgContext.fill(CGRect(x:x, y:y, width:elementSize,height:elementSize))
                    }
                }
            })
            colorImage?.draw(at: .zero)
        }
        UIColor.systemGray.setStroke()
        context?.stroke(bounds)
        let circle = UIBezierPath(arcCenter: getPointForColor(color: selectedColor), radius: 5.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        UIColor.white.setFill()
        UIColor.black.setStroke()
        circle.lineWidth = 1.0
        circle.fill()
        circle.stroke()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let currentPoint = touches.first!.location(in: self)
        if self.bounds.contains(currentPoint) {
            selectedColor = getColorAtPoint(point: currentPoint)
            setNeedsDisplay()
            onPenColorChanged?(selectedColor)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let currentPoint = touches.first!.location(in: self)
        if self.bounds.contains(currentPoint) {
            selectedColor = getColorAtPoint(point: currentPoint)
            setNeedsDisplay()
            onPenColorChanged?(selectedColor)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let currentPoint = touches.first!.location(in: self)
        if self.bounds.contains(currentPoint) {
            selectedColor = getColorAtPoint(point: currentPoint)
            setNeedsDisplay()
            onPenColorChanged?(selectedColor)
        }
    }
    
    func getColorAtPoint(point:CGPoint) -> UIColor {
        let roundedPoint = CGPoint(x:elementSize * CGFloat(Int(point.x / elementSize)),
                               y:elementSize * CGFloat(Int(point.y / elementSize)))
        var saturation = roundedPoint.y < self.bounds.height / 2.0 ? CGFloat(2 * roundedPoint.y) / self.bounds.height
        : 2.0 * CGFloat(self.bounds.height - roundedPoint.y) / self.bounds.height
        saturation = CGFloat(powf(Float(saturation), roundedPoint.y < self.bounds.height / 2.0 ? saturationExponentTop : saturationExponentBottom))
        let brightness = roundedPoint.y < self.bounds.height / 2.0 ? CGFloat(1.0) : 2.0 * CGFloat(self.bounds.height - roundedPoint.y) / self.bounds.height
        let hue = roundedPoint.x / self.bounds.width
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    func getPointForColor(color:UIColor) -> CGPoint {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil);

        var yPos:CGFloat = 0
        let halfHeight = (self.bounds.height / 2)
        if (brightness >= 0.99) {
            let percentageY = powf(Float(saturation), 1.0 / saturationExponentTop)
            yPos = CGFloat(percentageY) * halfHeight
        } else {
            //use brightness to get Y
            yPos = halfHeight + halfHeight * (1.0 - brightness)
        }
        let xPos = hue * self.bounds.width
        return CGPoint(x: xPos, y: yPos)
    }
}

class GridLayoutView: UIView {
    var gridSizeX: Int = 4
    var gridSizeY: Int = 4
    var borderWidth: CGFloat = 5
    var insets: UIEdgeInsets = .zero

    override func layoutSubviews() {
        super.layoutSubviews()

        let margin = borderWidth

        let width = (bounds.width - CGFloat(gridSizeX - 1) * margin - insets.left - insets.right) / CGFloat(gridSizeX)
        let height = (bounds.height - CGFloat(gridSizeY - 1) * margin - insets.top - insets.bottom) / CGFloat(gridSizeY)

        let startX: CGFloat = insets.left
        let startY: CGFloat = insets.top

        var x = startX
        var y = startY

        subviews.enumerated().forEach { index, view in
            view.frame.origin = CGPoint(x: x, y: y)
            view.frame.size = CGSize(width: width, height: height)

            x += width + margin
            if index % gridSizeX == gridSizeX - 1 {
                x = startX
                y += height + margin
            }
        }
    }
}

class ColorPaletteView: GridLayoutView {
    let colorButtons: [UIButton]
    var customButtons: [UIButton]
    let addButton: UIButton
    var userColor: [UIColor] = []
    var colorList: [[CGFloat]] {
        get {
            return userColor.map({
                var r = CGFloat(0)
                var g = CGFloat(0)
                var b = CGFloat(0)
                $0.getRed(&r, green: &g, blue: &b, alpha: nil)
                return [r, g, b]
            })
        }
        set {
            userColor = newValue.map({ UIColor(red: $0[0], green: $0[1], blue: $0[2], alpha: 1.0)})
        }
    }
    
    var onPenColorChanged: ((UIColor)->Void)?
    var onGetCurrentColor: (()->UIColor)?
    
    override init(frame: CGRect) {
        var colorButtons: [UIButton] = []
        for r in 0...2 {
            for g in 0...2 {
                for b in 0...2 {
                    let button = UIButton()
                    button.backgroundColor = UIColor(red: CGFloat(r) / 2, green: CGFloat(g) / 2, blue: CGFloat(b) / 2, alpha: 1.0)
                    button.layer.borderColor = UIColor.systemGray.cgColor
                    button.layer.borderWidth = 1.0
                    colorButtons.append(button)
                }
            }
        }
        customButtons = []
        self.colorButtons = colorButtons
        addButton = UIButton()
        addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addButton.tintColor = .systemGreen
        super.init(frame: frame)
        colorList = UserDefaults.standard.array(forKey: "CustomColor") as? [[CGFloat]] ?? []
        addButton.addTarget(self, action: #selector(addButtonTap(_:)), for: .touchUpInside)
        for button in colorButtons {
            button.addTarget(self, action: #selector(colorButtonTap(_:)), for: .touchUpInside)
        }
        customButtons = userColor.map({ makeCustomButton(color: $0) })
        renderButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func renderButtons() {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        gridSizeX = 15
        gridSizeY = 10
        for button in colorButtons {
            addSubview(button)
        }
        for button in customButtons {
            addSubview(button)
        }
        if colorButtons.count + customButtons.count < 15 * 10 {
            addSubview(addButton)
        }
    }
    
    @objc func longTapGuesture(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        guard let button = sender.view as? UIButton else { return }
        
        let color = button.backgroundColor ?? UIColor.black
        onPenColorChanged?(color)
        
        guard let i = customButtons.firstIndex(of: button) else { return }
        customButtons.remove(at: i)
        renderButtons()
        
        guard let ic = userColor.firstIndex(of: color) else { return }
        userColor.remove(at: ic)
        UserDefaults.standard.set(colorList, forKey: "CustomColor")
    }
    
    @objc func colorButtonTap(_ sender: UIButton) {
        onPenColorChanged?(sender.backgroundColor ?? UIColor.black)
    }

    private func makeCustomButton(color: UIColor) -> UIButton {
        let button = UIButton()
        button.backgroundColor = color
        button.layer.borderColor = UIColor.systemGray.cgColor
        button.layer.borderWidth = 1.0
        button.addTarget(self, action: #selector(colorButtonTap(_:)), for: .touchUpInside)
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longTapGuesture(_:))))
        return button
    }
    
    @objc func addButtonTap(_ sender: UIButton) {
        guard let c = onGetCurrentColor?() else {
            return
        }
        userColor.append(c)
        UserDefaults.standard.set(colorList, forKey: "CustomColor")
        customButtons.append(makeCustomButton(color: c))
        renderButtons()
    }
}
