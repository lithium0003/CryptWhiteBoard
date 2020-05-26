//
//  ObjectDeleter.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/05/24.
//  Copyright © 2020 lithium03. All rights reserved.
//

import Foundation

class ObjectDeleter: DrawObject {

    weak var container: DrawObjectContaier?
    
    override class func create(recordId: String?, data: Data, cmd: String, container: DrawObjectContaier) -> DrawObject? {

        let selection = ObjectDeleter(container: container, data: data)
        selection.recordId = recordId
        return selection
    }

    init(container: DrawObjectContaier) {
        super.init()
        self.container = container
    }
    
    init(container: DrawObjectContaier, data: Data) {
        super.init()
        self.container = container

        var nextData = data
        while !nextData.isEmpty {
            let (next, id) = convertData(data: nextData)
            nextData = next
            guard let sel = container.retrieveObject(recordId: id) else {
                continue
            }
            objects += [sel]
        }
    }

    private func convertData(data: Data) -> (Data, String) {
        var nextData = data
        let count = nextData.withUnsafeBytes { pointer in
            pointer.load(as: Int.self)
        }
        nextData = nextData.advanced(by: MemoryLayout<Int>.size)
        let idData = nextData.subdata(in: 0..<count)
        let id = String(bytes: idData, encoding: .utf8)!
        if nextData.count <= count {
            nextData = Data()
        }
        else {
            nextData = nextData.advanced(by: count)
        }
        return (nextData, id)
    }

    override func getLocationData() -> Data {
        var data = Data()
        
        for obj in objects {
            guard let recordId = obj.recordId else {
                continue
            }
            let idData = recordId.data(using: .utf8)!
            var count = idData.count
            data.append(Data(bytes: &count, count: MemoryLayout<Int>.size))
            data.append(idData)
        }
        
        return data
    }

    @discardableResult
    override func save(writer: (String, Data, @escaping (Bool?) -> Void) -> String?, finish: ((Bool?) -> Void)? = nil) -> String? {

        let cmd = "objectDeleter"
        
        let stroke = getLocationData()
        recordId = writer(cmd, stroke) { success in
            finish?(success)
        }
        return recordId
    }

    func add(selection: DrawObject) {
        guard let container = container else {
            return
        }
        guard let id = selection.recordId else {
            return
        }
        container.setPendingObject(recordId: id, pending: true)

        objects += [selection]
    }

}
