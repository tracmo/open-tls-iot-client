//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import CoreNFC

/// Handles writing NFC NDEF URLs to tags.
final class NFCTagWriter: NSObject {

    enum WriterError: Error, LocalizedError {
        case nfcNotAvailable
        case noTagsDetected
        case tagNotWritable
        case writeFailure(Error)
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .nfcNotAvailable:
                return "NFC is not available on this device"
            case .noTagsDetected:
                return "No NFC tags were detected"
            case .tagNotWritable:
                return "This NFC tag is not writable"
            case .writeFailure(let error):
                return "Failed to write to tag: \(error.localizedDescription)"
            case .invalidURL:
                return "Invalid URL format"
            }
        }
    }

    /// Check if NFC reading/writing is available on this device
    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private var session: NFCNDEFReaderSession?
    private var urlToWrite: String?
    private var completion: ((Result<Void, Error>) -> Void)?

    /// Writes a URL to an NFC tag.
    /// - Parameters:
    ///   - url: The URL string to write
    ///   - completion: Called with success or error
    func writeURL(_ url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard NFCTagWriter.isAvailable else {
            completion(.failure(WriterError.nfcNotAvailable))
            return
        }

        guard URL(string: url) != nil else {
            completion(.failure(WriterError.invalidURL))
            return
        }

        self.urlToWrite = url
        self.completion = completion

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag to configure it"
        session?.begin()

        NSLog("NFC Writer: Started session to write URL: \(url)")
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCTagWriter: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        NSLog("NFC Writer: Session became active")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // This delegate method is called when invalidateAfterFirstRead is true
        // We're not using it since we need to write, not just read
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        NSLog("NFC Writer: Detected \(tags.count) tag(s)")

        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tags detected")
            completion?(.failure(WriterError.noTagsDetected))
            cleanup()
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC Writer: Failed to connect to tag: \(error)")
                session.invalidate(errorMessage: "Failed to connect to tag")
                self.completion?(.failure(WriterError.writeFailure(error)))
                self.cleanup()
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    NSLog("NFC Writer: Failed to query tag status: \(error)")
                    session.invalidate(errorMessage: "Failed to read tag status")
                    self.completion?(.failure(WriterError.writeFailure(error)))
                    self.cleanup()
                    return
                }

                switch status {
                case .notSupported:
                    NSLog("NFC Writer: Tag does not support NDEF")
                    session.invalidate(errorMessage: "Tag does not support NDEF")
                    self.completion?(.failure(WriterError.tagNotWritable))
                    self.cleanup()

                case .readOnly:
                    NSLog("NFC Writer: Tag is read-only")
                    session.invalidate(errorMessage: "Tag is read-only")
                    self.completion?(.failure(WriterError.tagNotWritable))
                    self.cleanup()

                case .readWrite:
                    self.writeToTag(tag, session: session)

                @unknown default:
                    NSLog("NFC Writer: Unknown tag status")
                    session.invalidate(errorMessage: "Unknown tag status")
                    self.completion?(.failure(WriterError.tagNotWritable))
                    self.cleanup()
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        NSLog("NFC Writer: Session invalidated: \(error)")

        // Check if user cancelled
        let nfcError = error as? NFCReaderError
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            NSLog("NFC Writer: User cancelled")
            // Don't call completion for user cancellation
        } else if nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            // This is expected after successful write
            NSLog("NFC Writer: Session ended after tag read")
        } else {
            // Report other errors
            completion?(.failure(error))
        }

        cleanup()
    }

    // MARK: - Private Helpers

    private func writeToTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let urlString = urlToWrite,
              let url = URL(string: urlString),
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            NSLog("NFC Writer: Failed to create NDEF payload")
            session.invalidate(errorMessage: "Failed to create tag data")
            completion?(.failure(WriterError.invalidURL))
            cleanup()
            return
        }

        let message = NFCNDEFMessage(records: [payload])

        tag.writeNDEF(message) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC Writer: Write failed: \(error)")
                session.invalidate(errorMessage: "Failed to write to tag")
                self.completion?(.failure(WriterError.writeFailure(error)))
            } else {
                NSLog("NFC Writer: Write succeeded")
                session.alertMessage = "NFC tag configured successfully!"
                session.invalidate()
                self.completion?(.success(()))
            }

            self.cleanup()
        }
    }

    private func cleanup() {
        urlToWrite = nil
        completion = nil
        session = nil
    }
}
