//
//  AttachBoardViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/27.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

class AttachBoardViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var displayName: UITextField!
    @IBOutlet weak var boardId: UITextField!
    @IBOutlet weak var password: UITextField!
    var activityIndicator: UIActivityIndicatorView!

    let localData = LocalData()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        title = "Attach".localized

        boardId.delegate = self
        displayName.delegate = self
        password.delegate = self

        activityIndicator = UIActivityIndicatorView()
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        activityIndicator.color = .white
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .large
        activityIndicator.backgroundColor = .systemGray
        activityIndicator.layer.masksToBounds = true
        activityIndicator.layer.cornerRadius = 5.0
        activityIndicator.layer.opacity = 0.8
        view.addSubview(activityIndicator)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        activityIndicator.center = view.center
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField == displayName) {
            boardId.becomeFirstResponder()
        }
        else if (textField == boardId) {
            password.becomeFirstResponder()
        }
        else {
            textField.resignFirstResponder()
            doneAction()
        }
        return true
    }

    @IBAction func doneTap(_ sender: Any) {
        doneAction()
    }
    
    func doneAction() {
        guard let board = boardId.text else {
            return
        }
        guard let name = displayName.text else {
            return
        }
        guard let key = password.text else {
            return
        }
        if board.isEmpty {
            let alert: UIAlertController = UIAlertController(title: "Enter boardID".localized, message: "Board ID is empty.".localized, preferredStyle: .alert)
            let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(defaultAction)
            present(alert, animated: true, completion: nil)
            return
        }
        if name.isEmpty {
            let alert: UIAlertController = UIAlertController(title: "Enter name".localized, message: "Display name is empty.".localized, preferredStyle: .alert)
            let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(defaultAction)
            present(alert, animated: true) {
                self.displayName.text = "Board"
            }
            return
        }
        activityIndicator.startAnimating()
        localData.addNewBoard(board: board, name: name, key: key, attach: true) { success in
            DispatchQueue.main.async {
                defer {
                    self.activityIndicator.stopAnimating()
                }
                guard let success = success else {
                    let alert: UIAlertController = UIAlertController(title: "Error".localized, message: "Internal error occured. Failed to access database. Check connection and iCloud login.".localized, preferredStyle: .alert)
                    let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(defaultAction)
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                if success {
                    self.navigationController?.popToRootViewController(animated: true)
                }
                else {
                    let alert: UIAlertController = UIAlertController(title: "Failed to add".localized, message: "Check board ID and password.".localized, preferredStyle: .alert)
                    let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(defaultAction)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}
