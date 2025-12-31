//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var coordinator: AppCoordinator?

    /// Pending NFC URL to process when app becomes active
    private var pendingNFCURL: URL?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let coordinator = AppCoordinator(windowScene: windowScene)
        coordinator.start()

        self.coordinator = coordinator

        // Handle URL from cold launch
        if let urlContext = connectionOptions.urlContexts.first {
            handleNFCURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URL from warm launch
        guard let urlContext = URLContexts.first else { return }
        handleNFCURL(urlContext.url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Process any pending NFC URL when app becomes active
        if let url = pendingNFCURL {
            pendingNFCURL = nil
            handleNFCURL(url)
        }
    }

    // MARK: - NFC URL Handling

    private func handleNFCURL(_ url: URL) {
        NSLog("NFC: Received URL: \(url.absoluteString)")

        // Check if app is active, otherwise queue for later
        guard UIApplication.shared.applicationState == .active else {
            NSLog("NFC: App not active, queuing URL for later")
            pendingNFCURL = url
            return
        }

        // Validate the URL and get action index
        guard let actionIndex = NFCTokenManager.validateURL(url) else {
            NSLog("NFC: URL validation failed")
            return
        }

        // Execute the action
        coordinator?.executeActionFromNFC(index: actionIndex)
    }
}

