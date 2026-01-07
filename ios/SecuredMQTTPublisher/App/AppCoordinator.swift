//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
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

    /// Window for NFC confirmation dialog (above everything including auth)
    private lazy var nfcConfirmationWindow: UIWindow = {
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        let vc = UIViewController()
        // Semi-transparent dark background so dialog is clearly visible
        vc.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        window.rootViewController = vc
        window.isHidden = true
        return window
    }()
    
    private var children = [Coordinator]()
    
    private var willResignActiveObserver: Any?

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func start(skipAuth: Bool = false) {
        showHome()

        if !skipAuth {
            showAuthIfNeeded()
        }

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

    /// Timeout for waiting for MQTT connection (seconds)
    /// Note: Set to 15 seconds because app lifecycle can cause connect/disconnect cycles
    private let connectionTimeout: TimeInterval = 15.0

    /// Countdown duration for NFC confirmation (seconds)
    private let nfcConfirmationCountdown: Int = 3

    /// Timer for NFC confirmation countdown
    private var nfcCountdownTimer: Timer?

    /// Current NFC confirmation alert (for updating countdown)
    private weak var nfcConfirmationAlert: UIAlertController?

    /// Executes an action triggered by NFC, bypassing biometric authentication.
    /// Shows a 3-second confirmation window with cancel option.
    /// - Parameter index: The action index (0-3)
    func executeActionFromNFC(index: Int) {
        NFCDebugLog("========== EXECUTE ACTION START ==========")
        NFCDebugLog("executeActionFromNFC called with index: \(index)")

        // 1. Dismiss the auth window if it's showing (bypass biometric auth)
        NFCDebugLog("Auth window hidden: \(authWindow.isHidden)")
        authWindow.isHidden = true
        children.removeAll { $0 is AuthCoordinator }
        NFCDebugLog("Auth window dismissed, children count: \(children.count)")

        // 2. Validate index is 0-3
        let actions = Core.shared.dataStore.settings.actions
        NFCDebugLog("Total actions: \(actions.count)")
        guard index >= 0 && index < actions.count else {
            NFCDebugLog("❌ Invalid action index \(index)")
            return
        }

        // 3. Get the action and verify it has a topic configured
        let action = actions[index]
        NFCDebugLog("Action title: '\(action.title)'")
        NFCDebugLog("Action topic: '\(action.topic)'")
        NFCDebugLog("Action message: '\(action.message)'")
        guard !action.topic.isEmpty else {
            NFCDebugLog("❌ Action \(index) has no topic configured")
            return
        }

        // 4. Show confirmation dialog with countdown
        showNFCConfirmation(action: action, index: index)
    }

    /// Whether countdown has completed
    private var nfcCountdownDone = false

    /// Whether connection is ready
    private var nfcConnectionReady = false

    /// Whether NFC action was cancelled
    private var nfcCancelled = false

    /// Pending action to execute when both countdown and connection are ready
    private var nfcPendingAction: (action: Action, index: Int)?

    /// Cancellable for NFC connection waiting
    private var nfcConnectionCancellable: AnyCancellable?

    /// Timeout work item for connection
    private var nfcTimeoutWorkItem: DispatchWorkItem?

    /// Shows a confirmation dialog with countdown before executing NFC action.
    /// Connection waiting starts in parallel with countdown to minimize total wait time.
    private func showNFCConfirmation(action: Action, index: Int) {
        NFCDebugLog("Showing confirmation dialog for action: \(action.title)")

        // Prevent automatic disconnect during NFC execution
        Core.shared.isNFCExecutionInProgress = true

        // Reset state
        nfcCountdownDone = false
        nfcConnectionReady = false
        nfcCancelled = false
        nfcPendingAction = (action, index)

        var remainingSeconds = nfcConfirmationCountdown

        let alert = UIAlertController(
            title: "NFC Trigger",
            message: "Run \"\(action.title)\" in \(remainingSeconds)...",
            preferredStyle: .alert
        )

        // Cancel button only - no run button to avoid accidental taps
        let cancelAction = UIAlertAction(title: "Cancel \"\(action.title)\"", style: .destructive) { [weak self] _ in
            NFCDebugLog("❌ User cancelled NFC action: \(action.title)")
            self?.cancelNFCAction()
            // Light haptic to confirm cancellation
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        alert.addAction(cancelAction)

        nfcConfirmationAlert = alert

        // Show the NFC confirmation window and present alert on it
        nfcConfirmationWindow.isHidden = false
        nfcConfirmationWindow.makeKeyAndVisible()
        nfcConfirmationWindow.rootViewController?.present(alert, animated: true)
        NFCDebugLog("Alert presented on NFC confirmation window")

        // Start connection waiting IN PARALLEL with countdown
        startConnectionWaiting()

        // Start countdown timer
        nfcCountdownTimer?.invalidate()
        nfcCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak alert] timer in
            guard let self = self, !self.nfcCancelled else {
                timer.invalidate()
                return
            }

            remainingSeconds -= 1
            NFCDebugLog("Countdown: \(remainingSeconds)")

            if remainingSeconds > 0 {
                // Update message
                alert?.message = "Run \"\(action.title)\" in \(remainingSeconds)..."
            } else {
                // Time's up - countdown complete
                timer.invalidate()
                self.nfcCountdownTimer = nil

                // Dismiss alert
                alert?.dismiss(animated: true) { [weak self] in
                    guard let self = self, !self.nfcCancelled else { return }
                    self.nfcConfirmationWindow.isHidden = true
                    NFCDebugLog("Countdown complete for action: \(action.title)")
                    self.nfcCountdownDone = true
                    self.tryExecuteNFCAction()
                }
            }
        }
    }

    /// Starts waiting for MQTT connection in parallel with countdown
    private func startConnectionWaiting() {
        NFCDebugLog("Starting connection waiting (parallel with countdown)")

        // Cancel any previous subscription
        nfcConnectionCancellable?.cancel()
        nfcConnectionCancellable = nil
        nfcTimeoutWorkItem?.cancel()

        // Check if already connected
        if Core.shared.state == .connected {
            NFCDebugLog("✓ Already connected!")
            nfcConnectionReady = true
            return
        }

        // Manually trigger connect since we're blocking automatic connects during NFC
        NFCDebugLog("Triggering manual connect for NFC")
        Core.shared.manualConnect()

        // Set up timeout (starts from now, runs in parallel with countdown)
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.nfcCancelled, !self.nfcConnectionReady else { return }
            NFCDebugLog("❌ Connection TIMEOUT after \(self.connectionTimeout) seconds")
            self.nfcConnectionCancellable?.cancel()
            self.nfcConnectionCancellable = nil
            // Allow automatic disconnect again
            Core.shared.isNFCExecutionInProgress = false
            // Only show error if countdown is already done (otherwise user is still waiting)
            if self.nfcCountdownDone {
                SoundEffect.failure.play()
                self.showNFCError("Connection timeout. Please try again.")
            }
        }
        nfcTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout, execute: timeoutWorkItem)
        NFCDebugLog("Connection timeout scheduled for \(connectionTimeout) seconds")

        // Subscribe to connection state changes
        nfcConnectionCancellable = Core.shared.$state
            .receive(on: DispatchQueue.main)
            .first { $0 == .connected }
            .sink { [weak self] state in
                guard let self = self, !self.nfcCancelled else { return }
                NFCDebugLog("✓ Connection established!")
                self.nfcTimeoutWorkItem?.cancel()
                self.nfcConnectionReady = true
                self.tryExecuteNFCAction()
            }
        NFCDebugLog("Subscribed to connection state changes")
    }

    /// Tries to execute the NFC action if both countdown and connection are ready
    private func tryExecuteNFCAction() {
        guard !nfcCancelled else {
            NFCDebugLog("Action was cancelled, not executing")
            return
        }

        NFCDebugLog("tryExecuteNFCAction - countdownDone: \(nfcCountdownDone), connectionReady: \(nfcConnectionReady)")

        guard nfcCountdownDone && nfcConnectionReady else {
            if nfcCountdownDone && !nfcConnectionReady {
                NFCDebugLog("Countdown done but still waiting for connection...")
            }
            return
        }

        guard let pending = nfcPendingAction else {
            NFCDebugLog("No pending action to execute")
            return
        }

        NFCDebugLog("✓ Both conditions met, publishing now!")
        nfcPendingAction = nil
        publishNFCAction(pending.action, index: pending.index)
    }

    /// Cancels the current NFC action
    private func cancelNFCAction() {
        nfcCancelled = true
        nfcCountdownTimer?.invalidate()
        nfcCountdownTimer = nil
        nfcConnectionCancellable?.cancel()
        nfcConnectionCancellable = nil
        nfcTimeoutWorkItem?.cancel()
        nfcTimeoutWorkItem = nil
        nfcConfirmationWindow.isHidden = true
        nfcPendingAction = nil
        // Allow automatic disconnect again
        Core.shared.isNFCExecutionInProgress = false
    }

    /// Publishes the MQTT message for an NFC-triggered action
    private func publishNFCAction(_ action: Action, index: Int) {
        NFCDebugLog("========== PUBLISH START ==========")
        NFCDebugLog("Publishing to topic: \(action.topic)")
        NFCDebugLog("Message: \(action.message)")

        Core.shared.publish(message: action.message, to: action.topic)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                // NFC execution complete - allow automatic disconnect again
                Core.shared.isNFCExecutionInProgress = false

                if case .failure(let error) = completion {
                    NFCDebugLog("❌ Publish FAILED: \(error)")
                    SoundEffect.failure.play()
                    self?.showNFCError("Action failed: \(error.localizedDescription)")
                } else {
                    NFCDebugLog("Publish completed (no error)")
                }
            }, receiveValue: { [weak self] in
                NFCDebugLog("✓✓✓ PUBLISH SUCCESS! Action \(index): \(action.title)")
                // Play success sound (same as regular button)
                SoundEffect.success.play()
                // Quadruple vibration for NFC success
                NFCDebugLog("Triggering quadruple vibration")
                self?.vibrateSuccessFourTimes()

                // Auto-exit app after successful NFC action (after short delay for feedback)
                NFCDebugLog("Auto-exiting app after successful NFC action")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self?.suspendApp()
                }
            })
            .store(in: &bag)
        NFCDebugLog("Publish request sent")
    }

    /// Shows an error alert for NFC action failures
    private func showNFCError(_ message: String) {
        // Error haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        // Show alert on the home window's root view controller
        let alert = UIAlertController(title: "NFC Action Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        homeNavigationController.topViewController?.present(alert, animated: true)
    }

    /// Suspends the app (sends to background). Used after successful NFC action.
    private func suspendApp() {
        // This sends the app to background, effectively "exiting" for the user
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

    /// Quadruple vibration pattern specifically for successful NFC triggers.
    /// This feedback is NOT used for normal button presses - only NFC.
    private func vibrateSuccessFourTimes() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()

        // Four vibrations with short delays
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            generator.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
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
