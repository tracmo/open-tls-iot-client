//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import AVFoundation

/// Scans QR codes to import NFC secrets from another device.
final class QRCodeScannerViewController: UIViewController {

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onCodeScanned: (URL) -> Void
    private var hasScanned = false

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Scan QR Code"
        label.textColor = .white
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        return label
    }()

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Point your camera at the QR code on the other device"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        return label
    }()

    private lazy var cancelButton: UIButton = {
        let button = RoundedButton()
        button.backgroundColor = .systemGray6
        button.setTitleColor(.accent, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitle("Cancel", for: .normal)
        button.addAction(
            .init { [weak self] _ in
                self?.dismiss(animated: true)
            },
            for: .touchUpInside
        )
        return button
    }()

    init(onCodeScanned: @escaping (URL) -> Void) {
        self.onCodeScanned = onCodeScanned
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCamera() {
        let captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            NSLog("QR Scanner: Failed to get video capture device")
            showError("Camera not available")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            NSLog("QR Scanner: Failed to create video input: \(error)")
            showError("Cannot access camera")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            NSLog("QR Scanner: Cannot add video input to session")
            showError("Cannot configure camera")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            NSLog("QR Scanner: Cannot add metadata output to session")
            showError("Cannot configure scanner")
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = captureSession
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }

    private func setupUI() {
        view.addSubviews(
            titleLabel
                .top(to: view.safeAreaLayoutGuide.top, 32)
                .leading(to: view.safeAreaLayoutGuide.leading, 20)
                .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                .height(to: 44),
            instructionLabel
                .top(to: titleLabel.bottom, 12)
                .leading(to: view.safeAreaLayoutGuide.leading, 20)
                .trailing(to: view.safeAreaLayoutGuide.trailing, -20),
            cancelButton
                .bottom(to: view.safeAreaLayoutGuide.bottom, -20)
                .leading(to: view.safeAreaLayoutGuide.leading, 20)
                .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                .height(to: 46)
        )
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Scanner Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self?.dismiss(animated: true)
            })
            self?.present(alert, animated: true)
        }
    }

    private func handleScannedCode(_ code: String) {
        guard !hasScanned else { return }
        hasScanned = true

        NSLog("QR Scanner: Scanned code: \(code)")

        // Vibrate to confirm scan
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Parse URL
        guard let url = URL(string: code) else {
            NSLog("QR Scanner: Invalid URL format")
            showError("Invalid QR code format")
            hasScanned = false
            return
        }

        // Stop scanning
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }

        // Dismiss and pass URL to callback
        dismiss(animated: true) { [weak self] in
            self?.onCodeScanned(url)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            handleScannedCode(stringValue)
        }
    }
}
