//
//  InputSelectViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/04.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

class InputSelectViewController: UIViewController {

    @IBOutlet weak var stringLabel: UILabel!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var penButton: UIButton!
    @IBOutlet weak var colorPickerButton: UIButton!
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var objectButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    var vc: ViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let vc = presentingViewController as? ViewController else {
            return
        }
        self.vc = vc
        switch vc.board.inputMode {
        case .pen:
            stringLabel.text = "Draw mode".localized
            penButton.tintColor = .systemGreen
        case .move:
            stringLabel.text = "Move mode".localized
            moveButton.tintColor = .systemGreen
        case .colorpicker:
            stringLabel.text = "Color picker mode".localized
            colorPickerButton.tintColor = .systemGreen
        case .objectSelect:
            stringLabel.text = "Object select mode".localized
            objectButton.tintColor = .systemGreen
        case .text:
            stringLabel.text = "Text mode".localized
            textButton.tintColor = .systemGreen
        case .paste:
            stringLabel.text = "Paste mode".localized
        case .deletePen, .objectDeleter:
            stringLabel.text = "Delete mode".localized
            clearButton.tintColor = .systemYellow
        default:
            if vc.board.isSelectionMode {
                stringLabel.text = "Selection mode".localized
                cropButton.tintColor = .systemYellow
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "toCropSelect" {
            let next = segue.destination
            next.popoverPresentationController?.delegate = self
        }
        if segue.identifier == "toDeleter" {
            let next = segue.destination
            next.popoverPresentationController?.delegate = self
        }
    }
    
    // MARK: - Action
        
    @IBAction func buttonTap(_ sender: UIButton) {
        for b in [moveButton, penButton, colorPickerButton, cropButton, objectButton, textButton, clearButton] {
            b?.tintColor = nil
        }
        sender.tintColor = .systemGreen
        vc?.scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        switch sender {
        case moveButton:
            stringLabel.text = "Move mode".localized
            vc?.board.inputMode = .move
            vc?.scrollView.panGestureRecognizer.minimumNumberOfTouches = 1
        case penButton:
            stringLabel.text = "Draw mode".localized
            vc?.board.inputMode = .pen
        case colorPickerButton:
            stringLabel.text = "Color picker mode".localized
            vc?.board.inputMode = .colorpicker
        case cropButton:
            stringLabel.text = "Selection mode".localized
        case objectButton:
            stringLabel.text = "Object select mode".localized
            vc?.board.inputMode = .objectSelect
        case textButton:
            stringLabel.text = "Text mode".localized
            vc?.board.inputMode = .text
        case clearButton:
            stringLabel.text = "Delete mode".localized
        default:
            break
        }
    }
    
}

extension InputSelectViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class CropSelectViewController: UIViewController {

    var vc: ViewController?
    
    @IBOutlet weak var stringLabel: UILabel!
    @IBOutlet weak var rectSelectButton: UIButton!
    @IBOutlet weak var penSelectButton: UIButton!
    @IBOutlet weak var lineSelectButton: UIButton!
    @IBOutlet weak var splineSelectButton: UIButton!
    @IBOutlet weak var circleSelectButton: UIButton!
    @IBOutlet weak var ellipseSelectButton: UIButton!
    @IBOutlet weak var magicSelectButton: UIButton!
    @IBOutlet weak var selectionOptionStack: UIStackView!
    @IBOutlet weak var thresholdSlider: UISlider!
    @IBOutlet weak var thresholdLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let vc = presentingViewController as? InputSelectViewController else {
            return
        }
        self.vc = vc.vc
        
        thresholdSlider.value = self.vc?.board.magicThreshold ?? 0.5
        thresholdLabel.text = String(format: "%.2f", thresholdSlider.value)
        
        selectionOptionStack.isHidden = true
        stringLabel.isHidden = false
        stringLabel.text = "(Tap select type)".localized
        switch self.vc?.board.inputMode {
        case .penSelect:
            stringLabel.text = "Free draw select".localized
            penSelectButton.tintColor = .systemGreen
        case .rectSelect:
            stringLabel.text = "Rect select".localized
            rectSelectButton.tintColor = .systemGreen
        case .lineSelect:
            stringLabel.text = "Polyline select".localized
            lineSelectButton.tintColor = .systemGreen
        case .splineSelect:
            stringLabel.text = "Spline curve select".localized
            splineSelectButton.tintColor = .systemGreen
        case .circleSelect:
            stringLabel.text = "Circle select".localized
            circleSelectButton.tintColor = .systemGreen
        case .ellipseSelect:
            stringLabel.text = "Ellipse select".localized
            ellipseSelectButton.tintColor = .systemGreen
        case .magicSelect:
            magicSelectButton.tintColor = .systemGreen
            selectionOptionStack.isHidden = false
            stringLabel.isHidden = true
        default:
            break
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    
    // MARK: - Action
    @IBAction func thresholdSliderChanged(_ sender: UISlider) {
        thresholdLabel.text = String(format: "%.2f", sender.value)
        vc?.board.magicThreshold = sender.value
    }
    
    @IBAction func buttonTap(_ sender: UIButton) {
        for b in [rectSelectButton, penSelectButton, lineSelectButton, splineSelectButton, circleSelectButton, ellipseSelectButton, magicSelectButton] {
            b?.tintColor = nil
        }
        sender.tintColor = .systemGreen
        selectionOptionStack.isHidden = true
        stringLabel.isHidden = false
        switch sender {
        case rectSelectButton:
            stringLabel.text = "Rect select".localized
            vc?.board.inputMode = .rectSelect
        case penSelectButton:
            stringLabel.text = "Free draw select".localized
            vc?.board.inputMode = .penSelect
        case lineSelectButton:
            stringLabel.text = "Polyline select".localized
            vc?.board.inputMode = .lineSelect
        case splineSelectButton:
            stringLabel.text = "Spline curve select".localized
            vc?.board.inputMode = .splineSelect
        case circleSelectButton:
            stringLabel.text = "Circle select".localized
            vc?.board.inputMode = .circleSelect
        case ellipseSelectButton:
            stringLabel.text = "Ellipse select".localized
            vc?.board.inputMode = .ellipseSelect
        case magicSelectButton:
            vc?.board.inputMode = .magicSelect
            selectionOptionStack.isHidden = false
            stringLabel.isHidden = true
        default:
            break
        }
    }
}

extension CropSelectViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class DeleteSelectViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var deletePenButton: UIButton!
    @IBOutlet weak var objectDeleterButton: UIButton!
    var vc: ViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        guard let vc = presentingViewController as? InputSelectViewController else {
            return
        }
        self.vc = vc.vc
        
        label.text = "(Tap deleter)".localized
        switch self.vc?.board.inputMode {
        case .deletePen:
            label.text = "Delete pen".localized
            deletePenButton.tintColor = .systemGreen
        case .objectDeleter:
            label.text = "Object deleter".localized
            objectDeleterButton.tintColor = .systemGreen
        default:
            break
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    
    // MARK: - Action
    
    @IBAction func buttonTap(_ sender: UIButton) {
        for b in [deletePenButton, objectDeleterButton] {
            b?.tintColor = nil
        }
        sender.tintColor = .systemGreen
        switch sender {
        case deletePenButton:
            label.text = "Delete pen".localized
            vc?.board.inputMode = .deletePen
        case objectDeleterButton:
            label.text = "Object deleter".localized
            vc?.board.inputMode = .objectDeleter
        default:
            break
        }
    }
}

extension DeleteSelectViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}
