//
//  SceneDelegate.swift
//  CryptWhiteboard
//
//  Created by rei8 on 2020/04/22.
//  Copyright © 2020 lithium03. All rights reserved.
//

import UIKit
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        guard let userActivity = connectionOptions.userActivities.first(where: { $0.webpageURL != nil }) else { return }
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return
        }
        let boardid = incomingURL.lastPathComponent
        openDirect(boardid: boardid)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        (UIApplication.shared.delegate as? AppDelegate)?.drawRequest()
        (UIApplication.shared.delegate as? AppDelegate)?.reloadRequest()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return
        }
        let boardid = incomingURL.lastPathComponent
        openDirect(boardid: boardid)
    }
    
    func openDirect(boardid: String) {
        (UIApplication.shared.delegate as? AppDelegate)?.openBoardId = boardid
        
        guard let window = window else {
            return
        }
        guard let rootViewController = window.rootViewController as? UINavigationController else {
            return
        }
        guard let vc = rootViewController.viewControllers.first as? BoardCollectionViewController else {
            return
        }
        if vc.presentedViewController != nil {
            vc.presentedViewController?.dismiss(animated: false, completion: nil)
        }
        if vc.localData.isBoardExist(board: boardid) {
            let storyboardInstance = UIStoryboard(name: "Main", bundle: nil)
            let view = storyboardInstance.instantiateViewController(identifier: "DrawViewController") as ViewController
            view.boardId = boardid
            view.password = vc.localData.getKey(board: boardid)
            view.modalPresentationStyle = .fullScreen
            vc.present(view, animated: true, completion: nil)
        }
        else {
            vc.openBoardId = boardid
            vc.performSegue(withIdentifier: "addboard", sender: nil)
        }
    }
}

