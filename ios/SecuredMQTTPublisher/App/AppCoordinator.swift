//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit

final class AppCoordinator: Coordinator {
    private let windowScene: UIWindowScene
    
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
    
    private func showAuthIfNeeded() {
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
    
    deinit {
        if let willResignActiveObserver = willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        willResignActiveObserver = nil
    }
}
