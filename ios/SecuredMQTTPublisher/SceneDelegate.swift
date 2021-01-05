//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = .home
        window.makeKeyAndVisible()
        self.window = window
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        Core.shared.disconnect()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        Core.shared.connect()
    }
}

