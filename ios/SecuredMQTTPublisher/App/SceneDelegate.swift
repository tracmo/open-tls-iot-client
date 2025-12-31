//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
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
        NFCDebugLog("scene willConnectTo called")
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let coordinator = AppCoordinator(windowScene: windowScene)
        self.coordinator = coordinator

        // Check if this is an NFC launch - if so, skip auth initially
        let hasNFCURL = connectionOptions.urlContexts.first?.url.scheme == NFCTokenManager.urlScheme
        NFCDebugLog("Cold launch hasNFCURL: \(hasNFCURL)")

        // Start coordinator, but skip auth if we have an NFC URL pending
        coordinator.start(skipAuth: hasNFCURL)

        // Handle URL from cold launch
        if let urlContext = connectionOptions.urlContexts.first {
            NFCDebugLog("Cold launch with URL: \(urlContext.url.absoluteString)")
            handleNFCURL(urlContext.url)
        } else {
            NFCDebugLog("Cold launch with NO URL")
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URL from warm launch
        NFCDebugLog("openURLContexts called with \(URLContexts.count) URLs")
        guard let urlContext = URLContexts.first else { return }
        NFCDebugLog("Warm launch with URL: \(urlContext.url.absoluteString)")
        handleNFCURL(urlContext.url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NFCDebugLog("sceneDidBecomeActive called, pendingURL: \(pendingNFCURL?.absoluteString ?? "nil")")
        // Process any pending NFC URL when app becomes active
        if let url = pendingNFCURL {
            pendingNFCURL = nil
            NFCDebugLog("Processing pending URL now (bypassing state check)")
            // Bypass state check since we KNOW we just became active
            processNFCURL(url)
        }
    }

    // MARK: - NFC URL Handling

    private func handleNFCURL(_ url: URL) {
        NFCDebugLog("handleNFCURL called")
        NFCDebugLog("URL = \(url.absoluteString)")
        NFCDebugLog("App state = \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")

        // Check if app is active, otherwise queue for later
        guard UIApplication.shared.applicationState == .active else {
            NFCDebugLog("App not active, queuing URL for later")
            pendingNFCURL = url
            return
        }

        processNFCURL(url)
    }

    /// Process the NFC URL (validate and execute). Called when we're sure the app is ready.
    private func processNFCURL(_ url: URL) {
        NFCDebugLog("processNFCURL - validating...")

        // Validate the URL and get action index
        guard let actionIndex = NFCTokenManager.validateURLSimple(url) else {
            NFCDebugLog("❌ URL validation FAILED - showing auth if needed")
            // NFC validation failed, show auth if it was skipped
            coordinator?.showAuthIfNeeded()
            return
        }

        NFCDebugLog("✓ URL validated, actionIndex = \(actionIndex)")
        NFCDebugLog("Calling executeActionFromNFC...")

        // Execute the action
        coordinator?.executeActionFromNFC(index: actionIndex)
    }
}

