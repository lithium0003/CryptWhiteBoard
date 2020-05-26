//
//  PasteImageCache.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/23.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import UIKit

class PasteImageCache {
    class func saveImage(recordId: String, image: UIImage) {
        let folderURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dirURL = folderURLs[0].appendingPathComponent("pasteImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        
        let fileURL = dirURL.appendingPathComponent("\(recordId)")
        
        try? image.pngData()?.write(to: fileURL)
    }

    class func deleteImage(recordId: String) {
        let folderURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dirURL = folderURLs[0].appendingPathComponent("pasteImages", isDirectory: true)
        let fileURL = dirURL.appendingPathComponent("\(recordId)")
        
        try? FileManager.default.removeItem(at: fileURL)
    }

    class func deleteAllImage() {
        let folderURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dirURL = folderURLs[0].appendingPathComponent("pasteImages", isDirectory: true)

        try? FileManager.default.removeItem(at: dirURL)
    }
    
    class func getImage(recordId: String) -> UIImage? {
        let folderURLs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dirURL = folderURLs[0].appendingPathComponent("pasteImages", isDirectory: true)
        let fileURL = dirURL.appendingPathComponent("\(recordId)")
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }
}
