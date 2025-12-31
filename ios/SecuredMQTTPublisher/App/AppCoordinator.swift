//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class AppCoordinator: Coordinator {
    private let windowScene: UIWindowScene
    private var bag = Set<AnyCancellable>()
    
    private lazy var homeWindow: UIWindow = {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = homeNavigationController
        return window
    }()
    
    private lazy var homeNavigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        return navigationController
    }()
    
    private lazy var authWindow: UIWindow = {
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .normal + 1
        window.rootViewController = authNavigationController
        window.isHidden = true
        return window
    }()
    
    private lazy var authNavigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        return navigationController
    }()
    
    private var children = [Coordinator]()
    
    private var willResignActiveObserver: Any?
    
    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }
    
    func start() {
        showHome()
        showAuthIfNeeded()
        
        willResignActiveObserver =
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                                   object: nil,
                                                   queue: .main) { [weak self] _ in
                guard let self = self else { return }
                self.showAuthIfNeeded()
            }
    }
    
    private func showHome() {
        let homeCooridinator = HomeCoordinator(navigationController: homeNavigationController)
        homeCooridinator.start()
        
        children.append(homeCooridinator)
        
        homeWindow.makeKeyAndVisible()
    }
    
    func showAuthIfNeeded() {
        let isAuthShowing = !authWindow.isHidden
        guard Core.shared.dataStore.settings.isBiometricAuthEnabled,
              !isAuthShowing else { return }
        
        showAuth()
    }
    
    private func showAuth() {
        let authCoordinator =
            AuthCoordinator(navigationController: authNavigationController,
                            didFinishHandler: { [weak self] coordinator in
                                guard let self = self else { return }
                                self.children.removeAll { $0 === coordinator }
                                self.authWindow.isHidden = true
                            })
        authCoordinator.start()
        
        children.append(authCoordinator)
        
        authWindow.isHidden = false
    }

    // MARK: - NFC Action Execution

    /// Executes an action triggered by NFC, bypassing biometric authentication.
    /// - Parameter index: The action index (0-3)
    func executeActionFromNFC(index: Int) {
        NSLog("NFC: Executing action at index \(index)")

        // 1. Dismiss the auth window if it's showing (bypass biometric auth)
        authWindow.isHidden = true
        children.removeAll { $0 is AuthCoordinator }

        // 2. Validate index is 0-3
        let actions = Core.shared.dataStore.settings.actions
        guard index >= 0 && index < actions.count else {
            NSLog("NFC: Invalid action index \(index)")
            return
        }

        // 3. Get the action and verify it has a topic configured
        let action = actions[index]
        guard !action.topic.isEmpty else {
            NSLog("NFC: Action \(index) has no topic configured")
            return
        }

        // 4. Execute the MQTT publish immediately
        Core.shared.publish(message: action.message, to: action.topic)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    NSLog("NFC: Action failed: \(error)")
                    // Single error haptic for failure
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }, receiveValue: { [weak self] in
                NSLog("NFC: Action \(index) succeeded: \(action.title)")
                // Double vibration for NFC success
                self?.vibrateSuccessTwice()
            })
            .store(in: &bag)
    }

    /// Double vibration pattern specifically for successful NFC triggers.
    /// This feedback is NOT used for normal button presses - only NFC.
    private func vibrateSuccessTwice() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()

        // First vibration
        generator.impactOccurred()

        // Second vibration after short delay (0.2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            generator.impactOccurred()
        }
    }

    deinit {
        if let willResignActiveObserver = willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        willResignActiveObserver = nil
    }
}
