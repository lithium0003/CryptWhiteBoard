//
//  BoardCollectionViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/23.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

private let reuseIdentifier = "boardCell"

class CollectionCell: UICollectionViewCell {
    var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "pencil.and.outline")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    var label: UILabel = {
        let label = UILabel()
        label.text = "untitled"
        label.numberOfLines = 0
        label.layer.cornerRadius = 5.0
        label.layer.masksToBounds = true
        label.layer.opacity = 0.8
        label.backgroundColor = .systemBackground
        return label
    }()
    
    var checkmark: UIImageView = {
        let checkmark = UIImageView()
        checkmark.image = UIImage.checkmark
        checkmark.tintColor = .systemRed
        return checkmark
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CollectionCell {
    fileprivate func setup() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor).isActive = true
        let size = min(UIApplication.shared.windows.first?.screen.bounds.width ?? 100, UIApplication.shared.windows.first?.screen.bounds.height ?? 100)
        imageView.widthAnchor.constraint(equalToConstant: ceil(size / 500) * 100).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: ceil(size / 500) * 100).isActive = true
        imageView.layer.borderColor = UIColor.systemGray.cgColor
        imageView.layer.borderWidth = 1.0

        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.centerXAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor).isActive = true
        label.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor).isActive = true
        
        contentView.addSubview(checkmark)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
        checkmark.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor, constant: -10).isActive = true
    }
}

class BoardCollectionViewController: UICollectionViewController {

    var openBoardId: String?
    
    let localData = LocalData()
    var boardList: [(String, String)] = []
    var itemSelection: [Bool] = []
    
    var addBarButtonItem: UIBarButtonItem!
    var editBarButtonItem: UIBarButtonItem!
    var cancelBarButtonItem: UIBarButtonItem!
    var cutBarButtonItem: UIBarButtonItem!
    var deleteBarButtonItem: UIBarButtonItem!
    var spaceBarButtonItem: UIBarButtonItem!
    var settingBarButtonItem: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(CollectionCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        title = "Board select".localized
        
        addBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBarButtonTapped(_:)))
        editBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editBarButtonTapped(_:)))
        cancelBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarButtonTapped(_:)))
        cutBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "scissors"), style: .plain, target: self, action: #selector(cutBarButtonTapped(_:)))
        deleteBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteBarButtonTapped(_:)))
        spaceBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        settingBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settingBarButtonTapped(_:)))
        
        self.navigationItem.rightBarButtonItems = [editBarButtonItem, addBarButtonItem]
        self.navigationItem.leftBarButtonItems = [settingBarButtonItem]

        boardList = localData.getBoardList()
        itemSelection = [Bool](repeating: false, count: boardList.count)
        
        if let startBoardId = (UIApplication.shared.delegate as? AppDelegate)?.openBoardId {
            openBoardId = startBoardId
            (UIApplication.shared.delegate as? AppDelegate)?.openBoardId = nil
        }
    }

    @objc func settingBarButtonTapped(_ sender: UIBarButtonItem) {
        let storyboardInstance = UIStoryboard(name: "Main", bundle: nil)
        let view = storyboardInstance.instantiateViewController(identifier: "SettingView") as SettingTableViewController

        navigationController?.pushViewController(view, animated: true)
    }

    @objc func addBarButtonTapped(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "addboard", sender: nil)
    }

    @objc func editBarButtonTapped(_ sender: UIBarButtonItem) {
        self.isEditing = true
        self.navigationItem.rightBarButtonItems = [cancelBarButtonItem]
        self.navigationItem.leftBarButtonItems = [cutBarButtonItem, spaceBarButtonItem, deleteBarButtonItem]
        reloadData()
    }

    @objc func cancelBarButtonTapped(_ sender: UIBarButtonItem) {
        self.navigationItem.rightBarButtonItems = [editBarButtonItem, addBarButtonItem]
        self.navigationItem.leftBarButtonItems = [settingBarButtonItem]
        self.isEditing = false
        reloadData()
    }

    @objc func cutBarButtonTapped(_ sender: UIBarButtonItem) {
        self.navigationItem.rightBarButtonItems = [editBarButtonItem, addBarButtonItem]
        self.navigationItem.leftBarButtonItems = [settingBarButtonItem]
        self.isEditing = false
        
        let count = itemSelection.filter({ $0 }).count
        if count == 0 {
            reloadData()
            return
        }

        let alert: UIAlertController = UIAlertController(title: "Detach from board".localized, message: String(format: "Detach from %d board(s).".localized, count), preferredStyle: .alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "Detach".localized, style: .destructive) {
            action in
            for (i, c) in self.itemSelection.enumerated() {
                if c {
                    self.localData.deleteBoard(board: self.boardList[i].0, key: self.localData.getKey(board: self.boardList[i].0), destoryBoard: false) {
                        DispatchQueue.main.async {
                            self.reloadData()
                        }
                    }
                }
            }
            self.itemSelection = [Bool](repeating: false, count: self.boardList.count)
        }
        alert.addAction(defaultAction)
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel".localized, style: .cancel) {
            action in
            self.reloadData()
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    @objc func deleteBarButtonTapped(_ sender: UIBarButtonItem) {
        self.navigationItem.rightBarButtonItems = [editBarButtonItem, addBarButtonItem]
        self.navigationItem.leftBarButtonItems = [settingBarButtonItem]
        self.isEditing = false
        
        let count = itemSelection.filter({ $0 }).count
        if count == 0 {
            reloadData()
            return
        }
        
        let alert: UIAlertController = UIAlertController(title: "Destroy board".localized, message: String(format: "Destory %d board(s). This operation remove board(s) completely from all users.".localized, count), preferredStyle: .alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "Destory completely".localized, style: .destructive) {
            action in
            for (i, c) in self.itemSelection.enumerated() {
                if c {
                    self.localData.deleteBoard(board: self.boardList[i].0, key: self.localData.getKey(board: self.boardList[i].0), destoryBoard: true) {
                        DispatchQueue.main.async {
                            self.reloadData()
                        }
                    }
                }
            }
            self.itemSelection = [Bool](repeating: false, count: self.boardList.count)
        }
        alert.addAction(defaultAction)
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel".localized, style: .cancel) {
            action in
            self.reloadData()
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        reloadData()
        
        if let openBoardId = openBoardId {
            if localData.isBoardExist(board: openBoardId) {
                self.openBoardId = nil
                let storyboardInstance = UIStoryboard(name: "Main", bundle: nil)
                let view = storyboardInstance.instantiateViewController(identifier: "DrawViewController") as ViewController
                view.boardId = openBoardId
                view.password = localData.getKey(board: openBoardId)
                view.modalPresentationStyle = .fullScreen
                present(view, animated: true, completion: nil)
            }
            else {
                performSegue(withIdentifier: "addboard", sender: nil)
            }
        }
    }
    
    func reloadData() {
        boardList = localData.getBoardList()
        itemSelection = [Bool](repeating: false, count: boardList.count)
        collectionView.reloadData()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        if segue.identifier == "addboard" {
            if let openBoardId = openBoardId {
                (segue.destination as? UITabBarController)?.selectedIndex = 1
                ((segue.destination as? UITabBarController)?.viewControllers?[1] as? AttachBoardViewController)?.boardId.text = openBoardId
                self.openBoardId = nil
            }
        }
    }
    
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return boardList.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! CollectionCell
    
        // Configure the cell
        cell.label.text = boardList[indexPath.row].1
        if isEditing && itemSelection[indexPath.row] {
            cell.checkmark.isHidden = false
        }
        else {
            cell.checkmark.isHidden = true
        }
        
        if let image = localData.getImage(board: boardList[indexPath.row].0) {
            cell.imageView.image = image
        }
        else {
            cell.imageView.image = UIImage(systemName: "pencil.and.outline")
        }
        
        return cell
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            itemSelection[indexPath.row] = !itemSelection[indexPath.row]
            collectionView.reloadData()
        }
        else {
            let targetBoardId = boardList[indexPath.row].0
            let targetKey = localData.getKey(board: targetBoardId)
            RemoteData.isValidBoard(boardId: targetBoardId, key: targetKey) { exist, valid in
                guard let exist = exist else {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Failed to connect".localized, message: "Failed to connect database.".localized, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(defaultAction)
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
                guard exist, valid else {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Board deleted".localized, message: "This board has beed deleted by other user.".localized.localized, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(defaultAction)
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
                DispatchQueue.main.async {
                    let storyboardInstance = UIStoryboard(name: "Main", bundle: nil)
                    let view = storyboardInstance.instantiateViewController(identifier: "DrawViewController") as ViewController
                    view.boardId = targetBoardId
                    view.password = targetKey
                    view.modalPresentationStyle = .fullScreen
                    self.present(view, animated: true, completion: nil)
                }
            }
        }
    }
    
    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    

    
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
