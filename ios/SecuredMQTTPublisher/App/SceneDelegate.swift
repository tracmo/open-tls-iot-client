//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

extension UIWindow {
    static var main: UIWindow?
    static var auth: UIWindow?
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    private var bag = Set<AnyCancellable>()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let mainWindow = UIWindow(windowScene: windowScene)
        mainWindow.rootViewController = .home
        mainWindow.makeKeyAndVisible()
        self.window = mainWindow
        UIWindow.main = mainWindow
        
        let authWindow = UIWindow(windowScene: windowScene)
        authWindow.windowLevel = .normal + 1
        authWindow.rootViewController = .auth
        authWindow.isHidden = !Core.shared.dataStore.settings.isBiometricAuthEnabled
        UIWindow.auth = authWindow
    }
}

