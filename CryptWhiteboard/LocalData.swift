//
//  LocalData.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/24.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class LocalData {
    let viewContext = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    
    func getBoardList() -> [(String, String)] {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(value: true)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        return fetchData?.compactMap {
            if let board = $0.board, let name = $0.name {
                return (board, name)
            }
            else {
                return nil
            }
        } ?? []
    }
    
    func isBoardExist(board: String) -> Bool {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        return fetchData?.count ?? 0 > 0
    }
    
    func getKey(board: String) -> String {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        return fetchData?.first?.key ?? ""
    }

    func setImage(board: String, image: UIImage?) {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        if let data = fetchData?.first {
            data.image = image?.jpegData(compressionQuality: 0.8)
            try? viewContext?.save()
        }
    }

    func getImage(board: String) -> UIImage? {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        if let imdata = fetchData?.first?.image, let image = UIImage(data: imdata) {
            return image
        }
        return nil
    }
    
    func setScroll(board: String, offset: CGPoint, scale: CGFloat) {
        let x = offset.x
        let y = offset.y
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        if let data = fetchData?.first {
            data.scrollx = Double(x)
            data.scrolly = Double(y)
            data.zoomscale = Double(scale)
            try? viewContext?.save()
        }
    }
    
    func getScroll(board: String) -> (CGPoint, CGFloat) {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        let fetchData = try? viewContext?.fetch(fetchRequest)
        if let data = fetchData?.first {
            let x = data.scrollx
            let y = data.scrolly
            let scale = data.zoomscale
            if scale > 0.1 {
                return (CGPoint(x: x, y: y), CGFloat(scale))
            }
        }
        return (CGPoint(x: 0, y: 0), 1.0)
    }
    
    func waitNewboard(boardId: String, key: String, count: Int = 0, finished: @escaping ()->Void) {
        RemoteData.isValidBoard(boardId: boardId, key: key) { exist, valid in
            guard let exist = exist else {
                if count > 10 {
                    finished()
                }
                DispatchQueue.global().asyncAfter(deadline: .now()+1) {
                    self.waitNewboard(boardId: boardId, key: key, count: count+1, finished: finished)
                }
                return
            }
            if exist && valid {
                finished()
            }
            else {
                if count > 10 {
                    finished()
                }
                DispatchQueue.global().asyncAfter(deadline: .now()+1) {
                    self.waitNewboard(boardId: boardId, key: key, count: count+1, finished: finished)
                }
            }
        }
    }
    
    func addNewBoard(board: String, name: String, key: String, attach: Bool, finish: @escaping (Bool?)->Void) {
        guard let viewContext = viewContext else {
            finish(nil)
            return
        }
        if attach {
            RemoteData.isValidBoard(boardId: board, key: key) { exist, valid in
                guard let exist = exist else {
                    finish(nil)
                    return
                }
                if exist && valid {
                    DispatchQueue.main.async {
                        let newboard = BoardList(context: viewContext)
                        newboard.board = board
                        newboard.name = name
                        newboard.key = key
                        do {
                            try viewContext.save()
                        }
                        catch {
                            finish(nil)
                            return
                        }
                        finish(true)
                    }
                }
                else {
                    finish(false)
                    return
                }
            }
        }
        else {
            RemoteData.isValidBoard(boardId: board, key: key) { exist, valid in
                guard let exist = exist else {
                    finish(nil)
                    return
                }
                if exist && valid {
                    DispatchQueue.main.async {
                        let newboard = BoardList(context: viewContext)
                        newboard.board = board
                        newboard.name = name
                        newboard.key = key
                        do {
                            try viewContext.save()
                        }
                        catch {
                            finish(nil)
                            return
                        }
                        finish(true)
                    }
                }
                else {
                    if exist {
                        finish(false)
                        return
                    }
                    RemoteData.makeBoard(boardId: board, key: key) { success in
                        guard let success = success else {
                            finish(nil)
                            return
                        }
                        if success {
                            DispatchQueue.main.async {
                                let newboard = BoardList(context: viewContext)
                                newboard.board = board
                                newboard.name = name
                                newboard.key = key
                                do {
                                    try viewContext.save()
                                }
                                catch {
                                    finish(nil)
                                    return
                                }
                                self.waitNewboard(boardId: board, key: key) {
                                    finish(true)
                                }
                            }
                        }
                        else {
                            finish(false)
                        }
                    }
                }
            }
        }
    }
    
    func deleteBoard(board: String, key: String, destoryBoard: Bool, finish: @escaping ()->Void) {
        let fetchRequest:NSFetchRequest<BoardList> = BoardList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "board == %@", board)
        guard let fetchData = try? viewContext?.fetch(fetchRequest) else {
            return
        }
        
        RemoteClone.deleteAllstroke(boardId: board)
        let im = ImageCache(board: board)
        im.clearImages()
        
        if destoryBoard {
            RemoteData.isValidBoard(boardId: board, key: key) { exist, valid in
                guard let exist = exist else {
                    return
                }
                if exist && valid {
                    let remote = RemoteData(board: board, key: key)
                    remote.destoryBoard()
                }
                DispatchQueue.main.async {
                    for item in fetchData {
                        self.viewContext?.delete(item)
                    }
                    try? self.viewContext?.save()
                    finish()
                }
            }
        }
        else {
            for item in fetchData {
                self.viewContext?.delete(item)
            }
            try? self.viewContext?.save()
            finish()
        }
    }
}
