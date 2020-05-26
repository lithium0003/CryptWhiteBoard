//
//  ShareBoardViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/24.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

class ShareBoardViewController: UIViewController {

    var boardId: String!
    var image: UIImage?
    
    @IBOutlet weak var textBoadId: UITextField!
    @IBOutlet weak var qrImage: UIImageView!
    @IBOutlet weak var shareButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        textBoadId.text = boardId
        textBoadId.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        qrImage.image = makeQRcode()
    }
    
    @objc func textFieldDidChange(textField: UITextField) {
        textBoadId.text = boardId
    }
    
    func makeQRcode() -> UIImage {
        let url = URL(string: "https://lithium03.info/whiteboard/"+boardId)!
        let data = url.dataRepresentation
        let qr = CIFilter(name: "CIQRCodeGenerator", parameters: ["inputMessage": data, "inputCorrectionLevel": "L"])!
        let sizeTransform = CGAffineTransform(scaleX: 10, y: 10)
        let qrImage = qr.outputImage!.transformed(by: sizeTransform)
        let image = UIImage(ciImage: qrImage)
        return image
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }

    @IBAction func shareButtonTap(_ sender: Any) {
        let shareText = "CryptWhiteboard - share board"
        let shareWebsite = URL(string: "https://lithium03.info/whiteboard/"+boardId)!
        
        let activityItems = [shareText, shareWebsite] as [Any]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = shareButton
        
        present(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func saveImageButtonTap(_ sender: Any) {
        guard let image = image else {
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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
