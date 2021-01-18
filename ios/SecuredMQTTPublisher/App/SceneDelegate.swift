//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

extension UIWindow {
    static var auth: UIWindow?
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let coordinator = AppCoordinator(window: window)
        coordinator.start()
        
        self.window = window
        self.coordinator = coordinator
        
        let authWindow = UIWindow(windowScene: windowScene)
        authWindow.windowLevel = .normal + 1
        authWindow.rootViewController = .auth
        authWindow.isHidden = !Core.shared.dataStore.settings.isBiometricAuthEnabled
        UIWindow.auth = authWindow
    }
}

