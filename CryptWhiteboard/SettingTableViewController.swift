//
//  SettingTableViewController.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/09.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit

class SettingTableViewController: UITableViewController {

    let sections: [String] = [
        "Cache Control".localized,
        "Apple Pencil Double-tap action".localized,
        "Help".localized,
    ]
    let titleMap: [[(String, Int)]] = [
    // Cache Control
        [("Clear image cache".localized, 1)],
    // Apple pencil Double-tap action
        [("None".localized, 10),
         ("Undo".localized, 11),
         ("Eraser".localized, 12),
         ("Disable finger tap".localized, 13),
        ],
    // Help
        [("Version".localized, 2),
         ("Online help".localized, 3),
         ("Privacy policy".localized, 4)
        ],
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        self.title = "Settings".localized
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return titleMap[section].count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingCell", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = nil
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .none
        
        let (title, idx) = titleMap[indexPath.section][indexPath.row]
        cell.textLabel?.text = title
        switch idx {
        case 1:
            cell.accessoryType = .disclosureIndicator
        case 2:
            let version = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")"
            let build = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")"
            cell.detailTextLabel?.text = "\(version) (\(build))"
        case 3:
            cell.accessoryType = .detailButton
        case 4:
            cell.accessoryType = .detailButton
        case 10...14:
            cell.accessoryType = .none
            if idx - 10 == UserDefaults.standard.integer(forKey: "APDoubleTap") {
                cell.accessoryType = .checkmark
            }
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let (_, idx) = titleMap[indexPath.section][indexPath.row]
        switch idx {
        case 1:
            let alart = UIAlertController(title: "Clear cache".localized, message: "Clear internal image cache?".localized, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Clear".localized, style: .destructive) { action in
                ImageCache.clearAll()
                PasteImageCache.deleteAllImage()
            }
            let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
            
            alart.addAction(deleteAction)
            alart.addAction(cancelAction)
            
            present(alart, animated: true, completion: nil)
        case 10...14:
            UserDefaults.standard.set(idx - 10, forKey: "APDoubleTap")
            tableView.reloadData()
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let (_, idx) = titleMap[indexPath.section][indexPath.row]
        switch idx {
        case 3:
            let url = URL(string: "Online help URL".localized)!
            UIApplication.shared.open(url)
        case 4:
            let url = URL(string: "Privacy policy URL".localized)!
            UIApplication.shared.open(url)
        default:
            break
        }
    }

}
