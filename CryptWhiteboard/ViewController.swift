//
//  ViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/22.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit
import CloudKit

class ViewController: UIViewController, UIPencilInteractionDelegate {
    let localData = LocalData()
    var remote: RemoteData!
    var boardId: String!
    var password: String!
    @IBOutlet weak var board: DrawView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var penButton: UIBarButtonItem!
    @IBOutlet weak var fingerButton: UIBarButtonItem!
    @IBOutlet weak var colorButton: UIBarButtonItem!
    @IBOutlet weak var clipboardButton: UIBarButtonItem!
    
    var zooming = false
    var scrolling = false
    
    var activityIndicator: UIActivityIndicatorView!

    var tapCountFinger = 0
    var useFinger: Bool = true {
        didSet {
            board.useFinger = useFinger
            if useFinger {
                fingerButton.image = UIImage(systemName: "hand.draw.fill")
                fingerButton.tintColor = .systemGreen
            }
            else {
                fingerButton.image = UIImage(systemName: "hand.draw")
                fingerButton.tintColor = nil
            }
        }
    }
    var notScroll: Bool = false {
        didSet {
            if notScroll {
                fingerButton.image = UIImage(systemName: "hand.raised.slash")
                fingerButton.tintColor = .systemRed
                scrollView.isScrollEnabled = false
                scrollView.pinchGestureRecognizer?.isEnabled = false
            }
            else {
                scrollView.isScrollEnabled = true
                scrollView.pinchGestureRecognizer?.isEnabled = true
                if useFinger {
                    fingerButton.image = UIImage(systemName: "hand.draw.fill")
                    fingerButton.tintColor = .systemGreen
                }
                else {
                    fingerButton.image = UIImage(systemName: "hand.draw")
                    fingerButton.tintColor = nil
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        view.addInteraction(pencilInteraction)

        NotificationCenter.default.addObserver(self, selector: #selector(clipboardChanged),
        name: UIPasteboard.changedNotification, object: nil)
        clipboardChanged()
        
        board.onInputModeChanged = { [unowned self] mode in
            self.penButton.tintColor = .systemGreen
            switch mode {
            case .pen:
                self.penButton.image = UIImage(systemName: "pencil.tip")
            case .move:
                self.penButton.image = UIImage(systemName: "hand.raised")
            case .rectSelect:
                self.penButton.image = UIImage(systemName: "crop")
            case .penSelect:
                self.penButton.image = UIImage(systemName: "scribble")
            case .lineSelect:
                self.penButton.image = UIImage(systemName: "skew")
            case .colorpicker:
                self.penButton.image = UIImage(systemName: "eyedropper.halffull")
            case .splineSelect:
                self.penButton.image = UIImage(systemName: "lasso")
            case .circleSelect:
                self.penButton.image = UIImage(systemName: "circle")
            case .ellipseSelect:
                self.penButton.image = UIImage(systemName: "capsule")
            case .magicSelect:
                self.penButton.image = UIImage(systemName: "wand.and.rays")
            case .objectSelect:
                self.penButton.image = UIImage(systemName: "square.on.circle")
            case .text:
                self.penButton.image = UIImage(systemName: "textformat")
            case .paste:
                self.penButton.image = UIImage(systemName: "doc")
            case .deletePen:
                self.penButton.tintColor = .systemRed
                self.penButton.image = UIImage(systemName: "pencil.and.outline")
            case .objectDeleter:
                self.penButton.tintColor = .systemRed
                self.penButton.image = UIImage(systemName: "rectangle.badge.xmark")
            }
        }
        board.onColorChanged = { [unowned self] color in
            self.colorButton.tintColor = color
        }
        
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        activityIndicator.color = .white
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .large
        activityIndicator.backgroundColor = .darkGray
        activityIndicator.layer.masksToBounds = true
        activityIndicator.layer.cornerRadius = 5.0
        activityIndicator.layer.opacity = 0.8
        view.addSubview(activityIndicator)
        
        let text1 = UILabel()
        activityIndicator.addSubview(text1)
        text1.text = ""
        text1.textColor = .white
        text1.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        text1.translatesAutoresizingMaskIntoConstraints = false
        text1.bottomAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: -10).isActive = true
        text1.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor).isActive = true
        
        let progress = UIProgressView()
        activityIndicator.addSubview(progress)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.bottomAnchor.constraint(equalTo: text1.topAnchor, constant: -10).isActive = true
        progress.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor).isActive = true
        progress.widthAnchor.constraint(equalTo: activityIndicator.widthAnchor).isActive = true

        activityIndicator.startAnimating()
        
        setNeedsStatusBarAppearanceUpdate()
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        remote = RemoteData(board: boardId, key: password)
        remote.unsubscribe() { [weak self] in
            self?.remote.subscribe()
            self?.remote.resetBadge()
        }
        board.remoteBoard = remote
        let (offset, scale) = localData.getScroll(board: boardId)
        scrollView.zoomScale = scale
        scrollView.contentOffset = offset
        DispatchQueue.main.async {
            self.board.readStroke()
        }
        board.reloadAnimate = { [weak self] b in
            DispatchQueue.main.async {
                if b {
                    self?.activityIndicator.startAnimating()
                }
                else {
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
        board.progressAnimate = { ratio, str in
            DispatchQueue.main.async {
                guard let ratio = ratio else {
                    text1.isHidden = true
                    progress.isHidden = true
                    return
                }
                text1.text = str
                progress.progress = ratio
                text1.isHidden = false
                progress.isHidden = false
            }
        }
        useFinger = true
        board.selectionMenuCalled = { [weak self] rect, callback in
            guard let self = self else {
                return
            }
            let popup = SelectMenuViewController()
            popup.popupResult = callback
            popup.modalPresentationStyle = .popover
            popup.popoverPresentationController?.delegate = self
            popup.popoverPresentationController?.sourceView = self.board
            popup.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 0, height: 0)
            if let w = self.view.window {
                if rect.width * self.scrollView.zoomScale < w.screen.bounds.width / 2 && rect.height * self.scrollView.zoomScale < w.screen.bounds.height / 2 {
                    popup.popoverPresentationController?.sourceRect = rect
                }
                let p = CGPoint(x: popup.popoverPresentationController!.sourceRect.midX * self.scrollView.zoomScale + self.scrollView.contentInset.left, y: popup.popoverPresentationController!.sourceRect.midY * self.scrollView.zoomScale + self.scrollView.contentInset.top)
                let gp = self.scrollView.convert(p, to: w.screen.coordinateSpace)
                if !w.screen.bounds.contains(gp) {
                    let c = CGRect(x: w.screen.bounds.midX, y: w.screen.bounds.midY, width: 0, height: 0)
                    popup.popoverPresentationController?.sourceRect = w.convert(c, to: self.board)
                }
            }
            self.present(popup, animated: true, completion: nil)
        }
        board.selectionModifyMenuCalled = { [weak self] rect, callback in
            guard let self = self else {
                return
            }
            let popup = SelectModifyMenuViewController()
            popup.popupResult = callback
            popup.modalPresentationStyle = .popover
            popup.popoverPresentationController?.delegate = self
            popup.popoverPresentationController?.sourceView = self.board
            popup.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 0, height: 0)
            if let w = self.view.window {
                if rect.width * self.scrollView.zoomScale < w.screen.bounds.width / 2 && rect.height * self.scrollView.zoomScale < w.screen.bounds.height / 2 {
                    popup.popoverPresentationController?.sourceRect = rect
                }
                let p = CGPoint(x: popup.popoverPresentationController!.sourceRect.midX * self.scrollView.zoomScale + self.scrollView.contentInset.left, y: popup.popoverPresentationController!.sourceRect.midY * self.scrollView.zoomScale + self.scrollView.contentInset.top)
                let gp = self.scrollView.convert(p, to: w.screen.coordinateSpace)
                if !w.screen.bounds.contains(gp) {
                    let c = CGRect(x: w.screen.bounds.midX, y: w.screen.bounds.midY, width: 0, height: 0)
                    popup.popoverPresentationController?.sourceRect = w.convert(c, to: self.board)
                }
            }
            self.present(popup, animated: true, completion: nil)
        }
        board.objectMenuCalled = { [weak self] rect, callback in
            guard let self = self else {
                return
            }
            let popup = ObjectMenuViewController()
            popup.popupResult = callback
            popup.modalPresentationStyle = .popover
            popup.popoverPresentationController?.delegate = self
            popup.popoverPresentationController?.sourceView = self.board
            popup.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 0, height: 0)
            if let w = self.view.window {
                if rect.width * self.scrollView.zoomScale < w.screen.bounds.width / 2 && rect.height * self.scrollView.zoomScale < w.screen.bounds.height / 2 {
                    popup.popoverPresentationController?.sourceRect = rect
                }
                let p = CGPoint(x: popup.popoverPresentationController!.sourceRect.midX * self.scrollView.zoomScale + self.scrollView.contentInset.left, y: popup.popoverPresentationController!.sourceRect.midY * self.scrollView.zoomScale + self.scrollView.contentInset.top)
                let gp = self.scrollView.convert(p, to: w.screen.coordinateSpace)
                if !w.screen.bounds.contains(gp) {
                    let c = CGRect(x: w.screen.bounds.midX, y: w.screen.bounds.midY, width: 0, height: 0)
                    popup.popoverPresentationController?.sourceRect = w.convert(c, to: self.board)
                }
            }
            self.present(popup, animated: true, completion: nil)
        }
        board.textWindowCalled = { [weak self] rect, initialStr, fontCallback, callback in
            guard let self = self else {
                return
            }
            let popup = TextInputViewController()
            popup.popupResponse = callback
            popup.initialString = initialStr
            popup.fontSize = self.board.textFont.pointSize
            if self.board.textFont.fontDescriptor.fontAttributes[UIFontDescriptor.AttributeName(rawValue: "NSCTFontUIUsageAttribute")] as? String == "CTFontRegularUsage" {
                if let settings = self.board.textFont.fontDescriptor.fontAttributes[.featureSettings] as? [[UIFontDescriptor.FeatureKey:NSNumber]] {
                    if settings.first?[UIFontDescriptor.FeatureKey.featureIdentifier] == 6, settings.first?[UIFontDescriptor.FeatureKey.typeIdentifier] == 0 {
                        popup.systemFonts = .monospacedDigit
                    }
                }
                else {
                    popup.systemFonts = .systemFont
                }
            }
            else if self.board.textFont.fontDescriptor.postscriptName == ".SFUIMono-Regular" {
                popup.systemFonts = .monospaced
            }
            else {
                popup.fontDescriptor = self.board.textFont.fontDescriptor
            }
            popup.setFontResponse = fontCallback
            popup.modalPresentationStyle = .popover
            popup.popoverPresentationController?.permittedArrowDirections = [.down, .left, .right]
            popup.popoverPresentationController?.delegate = self
            popup.popoverPresentationController?.sourceView = self.board
            popup.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 0, height: 0)
            if let w = self.view.window {
                if rect.width * self.scrollView.zoomScale < w.screen.bounds.width / 2 && rect.height * self.scrollView.zoomScale < w.screen.bounds.height / 2 {
                    popup.popoverPresentationController?.sourceRect = rect
                }
                let p = CGPoint(x: popup.popoverPresentationController!.sourceRect.midX * self.scrollView.zoomScale + self.scrollView.contentInset.left, y: popup.popoverPresentationController!.sourceRect.midY * self.scrollView.zoomScale + self.scrollView.contentInset.top)
                let gp = self.scrollView.convert(p, to: w.screen.coordinateSpace)
                if !w.screen.bounds.contains(gp) {
                    let c = CGRect(x: w.screen.bounds.midX, y: w.screen.bounds.midY, width: 0, height: 0)
                    popup.popoverPresentationController?.sourceRect = w.convert(c, to: self.board)
                }
            }
            self.present(popup, animated: true, completion: nil)
        }
        colorButton.tintColor = board.penColor
        let size = CGSize(width: 35, height: 35)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image(actions: { rendererContext in
            rendererContext.cgContext.setFillColor(UIColor.white.cgColor)
            rendererContext.fill(CGRect(origin: CGPoint.zero, size: size))
        })
        colorButton.setBackgroundImage(image, for: .normal, barMetrics: .default)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        activityIndicator.center = view.center
        scrollView.contentInset = UIEdgeInsets(top: max(0, (scrollView.frame.height - board.frame.height)/2), left: max(0, (scrollView.frame.width - board.frame.width)/2), bottom: 0, right: 0)
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch UserDefaults.standard.integer(forKey: "APDoubleTap") {
        case 0:
            return
        case 1:
            guard !activityIndicator.isAnimating else {
                return
            }
            board.undo()
        case 2:
            if board.inputMode == .deletePen || board.inputMode == .objectDeleter {
                board.inputMode = board.prevNormalMode
            }
            else {
                board.inputMode = board.prevEreserMode
            }
        case 3:
            fingerButtonTap(fingerButton)
        default:
            return
        }
    }
    
    @IBAction func doneButtonTap(_ sender: UIBarButtonItem) {
        board.finalizeSelection()
        localData.setImage(board: boardId, image: board.snapshotImage)
        localData.setScroll(board: boardId, offset: scrollView.contentOffset, scale: scrollView.zoomScale)
        dismiss(animated: true) {
            self.remote.unsubscribe()
        }
    }
    
    @IBAction func fingerButtonTap(_ sender: UIBarButtonItem) {
        tapCountFinger += 1
        switch tapCountFinger {
        case 0:
            useFinger = true
            notScroll = false
        case 1:
            useFinger = false
            notScroll = false
        case 2:
            useFinger = false
            notScroll = true
        default:
            tapCountFinger = 0
            useFinger = true
            notScroll = false
        }
    }
    
    @IBAction func penButtonTap(_ sender: UIBarButtonItem) {
    }
    
    @objc func clipboardChanged() {
        if UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings {
            clipboardButton.image = UIImage(systemName: "doc.on.clipboard.fill")
            clipboardButton.tintColor = .systemGreen
            board.clipboardContentId = UUID()
        }
        else {
            clipboardButton.image = UIImage(systemName: "doc.on.clipboard")
            clipboardButton.tintColor = nil
            board.clipboardContentId = nil
        }
    }
    
    @IBAction func pasteButtonTap(_ sender: UIBarButtonItem) {
        guard UIPasteboard.general.hasImages || UIPasteboard.general.hasStrings else {
            return
        }
        let x = (scrollView.frame.width / 2 + scrollView.contentOffset.x) / scrollView.zoomScale
        let y = (scrollView.frame.height / 2 + scrollView.contentOffset.y) / scrollView.zoomScale
        board.pasteAt(at: CGPoint(x: x, y: y))
    }
    
    @IBAction func undoButtonTap(_ sender: UIBarButtonItem) {
        guard !activityIndicator.isAnimating else {
            return
        }
        board.undo()
    }
    
    @IBAction func redoButtonTap(_ sender: UIBarButtonItem) {
        guard !activityIndicator.isAnimating else {
            return
        }
        board.redo()
    }
    
    @IBAction func deleteButtonTap(_ sender: UIBarButtonItem) {
        guard !activityIndicator.isAnimating else {
            return
        }
        let alert: UIAlertController = UIAlertController(title: "Clear all".localized, message: "Clear all stroke data?".localized, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "Delete".localized, style: .destructive) { action in
            self.board.destoryAllStroke()
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
        alert.addAction(defaultAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toBoardShare" {
            let next = segue.destination as? ShareBoardViewController
            next?.boardId = boardId
            next?.image = board.snapshotImage
        }
        if segue.identifier == "toInputType" {
            let next = segue.destination
            next.popoverPresentationController?.delegate = self
        }
        if segue.identifier == "toColorPickup" {
            let next = segue.destination as? PenViewController
            next?.penSize = board.penSize
            next?.penColor = board.penColor
            next?.penForce = board.usePenForce
            next?.penShading = board.usePenShading
            next?.fillColor = board.fillColor
            next?.popoverPresentationController?.delegate = self
            next?.onPenSizeValueChanged = { [unowned self] newSize in
                self.board.penSize = newSize
            }
            next?.onPenColorChanged = { [unowned self] newColor in
                self.board.penColor = newColor
                self.colorButton.tintColor = newColor
            }
            next?.onPenForceChanged = { [unowned self] newForce in
                self.board.usePenForce = newForce
            }
            next?.onPenShadingChanged = { [unowned self] newShading in
                self.board.usePenShading = newShading
            }
            next?.onFillColorChanged = { [unowned self] newColor in
                self.board.fillColor = newColor
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
}

extension ViewController: UIScrollViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrolling = true
        board.drawGrid = true
        board.setNeedsDisplay()
    }

    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrolling = false
        if !scrolling && !zooming {
            board.drawGrid = false
            board.setNeedsDisplay()
        }
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        scrolling = true
        board.drawGrid = true
        board.setNeedsDisplay()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrolling = false
        if !scrolling && !zooming {
            board.drawGrid = false
            board.setNeedsDisplay()
        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        zooming = true
        board.drawGrid = true
        board.setNeedsDisplay()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zooming = false
        if !scrolling && !zooming {
            board.drawGrid = false
            board.setNeedsDisplay()
        }
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        scrolling = true
        board.drawGrid = true
        board.setNeedsDisplay()
        return true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        scrolling = false
        if !scrolling && !zooming {
            board.drawGrid = false
            board.setNeedsDisplay()
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return board
    }
        
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateScrollInset()
    }
    
    private func updateScrollInset() {
        scrollView.contentInset = UIEdgeInsets(top: max(0, (scrollView.frame.height - board.frame.height)/2), left: max(0, (scrollView.frame.width - board.frame.width)/2), bottom: 0, right: 0)
    }
}

extension ViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}


class SelectMenuViewController: UIViewController {
    
    let stackView = UIStackView()
    let modifyButton = UIButton()
    let cutButton = UIButton()
    let drawButton = UIButton()
    let fillButton = UIButton()
    let clearfillButton = UIButton()
    let copyButton = UIButton()
    let exportButton = UIButton()
    let objectButton = UIButton()

    var ret = DrawView.SelectionMenuResult.cancel
    var popupResult: ((DrawView.SelectionMenuResult)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredContentSize = CGSize(width: 200, height: 350)
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        stackView.spacing = 15.0
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true

        stackView.addArrangedSubview(modifyButton)
        modifyButton.setTitle("Modify selection".localized, for: .normal)
        modifyButton.setTitleColor(UIColor.label, for: .normal)
        modifyButton.setImage(UIImage(systemName: "plus.rectangle.on.rectangle"), for: .normal)
        modifyButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(cutButton)
        cutButton.setTitle("Clear inside".localized, for: .normal)
        cutButton.setTitleColor(UIColor.label, for: .normal)
        cutButton.setImage(UIImage(systemName: "scissors"), for: .normal)
        cutButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(drawButton)
        drawButton.setTitle("Draw border".localized, for: .normal)
        drawButton.setTitleColor(UIColor.label, for: .normal)
        drawButton.setImage(UIImage(systemName: "pencil"), for: .normal)
        drawButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(fillButton)
        fillButton.setTitle("Fill".localized, for: .normal)
        fillButton.setTitleColor(UIColor.label, for: .normal)
        fillButton.setImage(UIImage(systemName: "paintbrush"), for: .normal)
        fillButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(clearfillButton)
        clearfillButton.setTitle("Clear and fill".localized, for: .normal)
        clearfillButton.setTitleColor(UIColor.label, for: .normal)
        clearfillButton.setImage(UIImage(systemName: "paintbrush.fill"), for: .normal)
        clearfillButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(copyButton)
        copyButton.setTitle("Copy".localized, for: .normal)
        copyButton.setTitleColor(UIColor.label, for: .normal)
        copyButton.setImage(UIImage(systemName: "square.on.square"), for: .normal)
        copyButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(exportButton)
        exportButton.setTitle("Export".localized, for: .normal)
        exportButton.setTitleColor(UIColor.label, for: .normal)
        exportButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        exportButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(objectButton)
        objectButton.setTitle("Object selection".localized, for: .normal)
        objectButton.setTitleColor(UIColor.label, for: .normal)
        objectButton.setImage(UIImage(systemName: "square.on.circle"), for: .normal)
        objectButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        popupResult?(ret)
    }
 
    @objc func buttonTap(_ sender: UIButton) {
        if sender == modifyButton {
            ret = .modify
        }
        if sender == cutButton {
            ret = .cut
        }
        else if sender == copyButton {
            ret = .copy
        }
        else if sender == exportButton {
            ret = .export
        }
        else if sender == drawButton {
            ret = .draw
        }
        else if sender == fillButton {
            ret = .fill
        }
        else if sender == clearfillButton {
            ret = .clearfill
        }
        else if sender == objectButton {
            ret = .object
        }
        dismiss(animated: true, completion: nil)
    }
}

class SelectModifyMenuViewController: UIViewController {
    
    let stackView = UIStackView()
    let appendButton = UIButton()
    let removeButton = UIButton()
    let clearButton = UIButton()
    let finishButton = UIButton()

    var ret = DrawView.SelectionModifyMenuResult.cancel
    var popupResult: ((DrawView.SelectionModifyMenuResult)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredContentSize = CGSize(width: 200, height: 300)
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        stackView.spacing = 15.0
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true

        stackView.addArrangedSubview(appendButton)
        appendButton.setTitle("Add selection".localized, for: .normal)
        appendButton.setTitleColor(UIColor.label, for: .normal)
        appendButton.setImage(UIImage(systemName: "plus.rectangle"), for: .normal)
        appendButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(removeButton)
        removeButton.setTitle("Exclude selection".localized, for: .normal)
        removeButton.setTitleColor(UIColor.label, for: .normal)
        removeButton.setImage(UIImage(systemName: "minus.rectangle"), for: .normal)
        removeButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(clearButton)
        clearButton.setTitle("Cancel selection".localized, for: .normal)
        clearButton.setTitleColor(UIColor.label, for: .normal)
        clearButton.setImage(UIImage(systemName: "xmark.rectangle"), for: .normal)
        clearButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(finishButton)
        finishButton.setTitle("Finish modify".localized, for: .normal)
        finishButton.setTitleColor(UIColor.label, for: .normal)
        finishButton.setImage(UIImage(systemName: "checkmark.rectangle"), for: .normal)
        finishButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        popupResult?(ret)
    }
 
    @objc func buttonTap(_ sender: UIButton) {
        if sender == appendButton {
            ret = .append
        }
        if sender == removeButton {
            ret = .remove
        }
        if sender == clearButton {
            ret = .clear
        }
        if sender == finishButton {
            ret = .finish
        }
        dismiss(animated: true, completion: nil)
    }
}


class ObjectMenuViewController: UIViewController {
    
    let stackView = UIStackView()
    let colorButton = UIButton()
    let rotateButton = UIButton()
    let clearButton = UIButton()

    var ret = DrawView.ObjectModifyMenuResult.cancel
    var popupResult: ((DrawView.ObjectModifyMenuResult)->Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredContentSize = CGSize(width: 200, height: 300)
        view.backgroundColor = .systemBackground
        view.addSubview(stackView)
        stackView.spacing = 15.0
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true

        stackView.addArrangedSubview(colorButton)
        colorButton.setTitle("Apply current".localized, for: .normal)
        colorButton.setTitleColor(UIColor.label, for: .normal)
        colorButton.setImage(UIImage(systemName: "paintbrush"), for: .normal)
        colorButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(rotateButton)
        rotateButton.setTitle("Rotate".localized, for: .normal)
        rotateButton.setTitleColor(UIColor.label, for: .normal)
        rotateButton.setImage(UIImage(systemName: "goforward"), for: .normal)
        rotateButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

        stackView.addArrangedSubview(clearButton)
        clearButton.setTitle("Clear objects".localized, for: .normal)
        clearButton.setTitleColor(UIColor.label, for: .normal)
        clearButton.setImage(UIImage(systemName: "xmark.square"), for: .normal)
        clearButton.addTarget(self, action: #selector(buttonTap(_:)), for: .touchUpInside)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        popupResult?(ret)
    }
 
    @objc func buttonTap(_ sender: UIButton) {
        if sender == colorButton {
            ret = .paint
        }
        else if sender == rotateButton {
            ret = .rotate
        }
        else if sender == clearButton {
            ret = .clear
        }
        dismiss(animated: true, completion: nil)
    }
}

class TextInputViewController: UIViewController, UITextViewDelegate, UIFontPickerViewControllerDelegate {
    
    var popupResponse: ((String)->Void)?
    var setFontResponse: ((UIFont)->Void)?
    var initialString: String = ""
    enum SystemFontType {
        case systemFont
        case monospaced
        case monospacedDigit
    }
    var systemFonts: SystemFontType = .systemFont
    var font: UIFont = .systemFont(ofSize: UIFont.systemFontSize) {
        didSet {
            print(font.fontDescriptor)
            setFontResponse?(font)
        }
    }
    var fontDescriptor: UIFontDescriptor? {
        didSet {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            if let fontDescriptor = fontDescriptor {
                font = UIFont(descriptor: fontDescriptor, size: fontSize)
                label2?.attributedText = NSAttributedString(string: fontDescriptor.postscriptName, attributes: [.font: UIFont(descriptor: fontDescriptor, size: UIFont.systemFontSize), .paragraphStyle: paragraph])
            }
            else {
                switch systemFonts {
                case .systemFont:
                    font = UIFont.systemFont(ofSize: fontSize)
                    label2?.attributedText = NSAttributedString(string: "System", attributes: [.font: UIFont.systemFont(ofSize: UIFont.systemFontSize), .paragraphStyle: paragraph])
                case .monospaced:
                    font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                    label2?.attributedText = NSAttributedString(string: "Monospaced", attributes: [.font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular), .paragraphStyle: paragraph])
                case .monospacedDigit:
                    font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
                    label2?.attributedText = NSAttributedString(string: "MonospacedDigit", attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: UIFont.systemFontSize, weight: .regular), .paragraphStyle: paragraph])
                }
            }
        }
    }
    var fontSize: CGFloat = 12.0 {
        didSet {
            text1?.text = String(format: "%.1f", fontSize)
            slider1?.value = fontSize >= 1 ? (fontSize <= 200 ? Float((fontSize - 1) / 199) : 1) : 0
            if let fontDescriptor = fontDescriptor {
                font = UIFont(descriptor: fontDescriptor, size: fontSize)
            }
            else {
                switch systemFonts {
                case .systemFont:
                    font = UIFont.systemFont(ofSize: fontSize)
                case .monospaced:
                    font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                case .monospacedDigit:
                    font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
                }
            }
        }
    }
    var slider1: UISlider!
    var text1: UITextField!
    var label2: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        view.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10).isActive = true
        
        let stackView1 = UIStackView()
        stackView1.axis = .horizontal
        stackView1.spacing = 10
        
        stackView.addArrangedSubview(stackView1)
        
        label2 = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        if let fontDescriptor = fontDescriptor {
            label2.attributedText = NSAttributedString(string: fontDescriptor.postscriptName, attributes: [.font: UIFont(descriptor: fontDescriptor, size: UIFont.systemFontSize), .paragraphStyle: paragraph])
        }
        else {
            switch systemFonts {
            case .systemFont:
                label2.attributedText = NSAttributedString(string: "System", attributes: [.font: UIFont.systemFont(ofSize: UIFont.systemFontSize), .paragraphStyle: paragraph])
            case .monospaced:
                label2.attributedText = NSAttributedString(string: "Monospaced", attributes: [.font: UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular), .paragraphStyle: paragraph])
            case .monospacedDigit:
                label2.attributedText = NSAttributedString(string: "MonospacedDigit", attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: UIFont.systemFontSize, weight: .regular), .paragraphStyle: paragraph])
            }
        }
        
        stackView1.addArrangedSubview(label2)

        let button1 = UIButton(type: .system)
        button1.setTitle("Select", for: .normal)
        button1.addTarget(self, action: #selector(selectFontTaped(_:)), for: .touchUpInside)
        
        stackView1.addArrangedSubview(button1)

        let stackView3 = UIStackView()
        stackView3.axis = .horizontal
        stackView3.spacing = 10
        stackView3.distribution = .equalSpacing
        
        stackView.addArrangedSubview(stackView3)

        let button2 = UIButton(type: .system)
        button2.setTitle("System", for: .normal)
        button2.addTarget(self, action: #selector(selectSystemFontTaped), for: .touchUpInside)
        
        stackView3.addArrangedSubview(button2)

        let button3 = UIButton(type: .system)
        button3.setTitle("Mono", for: .normal)
        button3.addTarget(self, action: #selector(selectSystemFontTaped), for: .touchUpInside)
        
        stackView3.addArrangedSubview(button3)

        let button4 = UIButton(type: .system)
        button4.setTitle("MonoDigit", for: .normal)
        button4.addTarget(self, action: #selector(selectSystemFontTaped), for: .touchUpInside)
        
        stackView3.addArrangedSubview(button4)

        let stackView2 = UIStackView()
        stackView2.axis = .horizontal
        stackView2.spacing = 10
        
        stackView.addArrangedSubview(stackView2)
        
        let label3 = UILabel()
        label3.text = "Font size"
        
        stackView2.addArrangedSubview(label3)

        slider1 = UISlider()
        slider1.value = fontSize >= 1 ? (fontSize <= 200 ? Float((fontSize - 1) / 199) : 1) : 0
        
        stackView2.addArrangedSubview(slider1)
        slider1.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

        text1 = UITextField()
        text1.text = String(format: "%.1f", fontSize)
        text1.keyboardType = .decimalPad
        
        stackView2.addArrangedSubview(text1)
        text1.widthAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true

        let input = UITextView()
        input.delegate = self
        input.text = initialString
        input.layer.borderColor = UIColor.systemBlue.cgColor
        input.layer.borderWidth = 2.0
        
        view.addSubview(input)

        input.translatesAutoresizingMaskIntoConstraints = false
        input.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        input.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -20).isActive = true
        input.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 10).isActive = true
        input.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true

        slider1.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        text1.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingDidEndOnExit)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        popupResponse?(textView.text)
    }

    @objc func selectSystemFontTaped(_ sender: UIButton) {
        if sender.titleLabel?.text == "System" {
            systemFonts = .systemFont
        }
        if sender.titleLabel?.text == "Mono" {
            systemFonts = .monospaced
        }
        if sender.titleLabel?.text == "MonoDigit" {
            systemFonts = .monospacedDigit
        }
        fontDescriptor = nil
    }
    
    @objc func selectFontTaped(_ sender: UIButton) {
        let config = UIFontPickerViewController.Configuration()
        config.includeFaces = true
        let fontPickerViewController = UIFontPickerViewController(configuration: config)
        fontPickerViewController.delegate = self
        present(fontPickerViewController, animated: true)
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        fontSize = CGFloat(sender.value * 199 + 1)
    }
    
    @objc func textFieldEditingChanged(_ sender: UITextField) {
        fontSize = CGFloat(Double(sender.text ?? "1") ?? 1)
    }
    
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        guard let fontDescriptor = viewController.selectedFontDescriptor else { return }
        self.fontDescriptor = fontDescriptor
    }

    func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
        print("User selected cancel.")
    }
}
