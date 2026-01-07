//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import CoreNFC

/// Handles reading and writing NFC NDEF URLs to tags.
final class NFCTagWriter: NSObject {

    enum WriterError: Error, LocalizedError {
        case nfcNotAvailable
        case noTagsDetected
        case tagNotWritable
        case insufficientCapacity(required: Int, available: Int)
        case writeFailure(Error)
        case readFailure(Error)
        case invalidURL
        case noURLFound
        case userCancelled

        var errorDescription: String? {
            switch self {
            case .nfcNotAvailable:
                return "NFC is not available on this device"
            case .noTagsDetected:
                return "No NFC tags were detected"
            case .tagNotWritable:
                return "This NFC tag is not writable"
            case .insufficientCapacity(let required, let available):
                return "Tag too small: needs \(required) bytes but only has \(available) bytes. Use NTAG215 or NTAG216 tags (504+ bytes)."
            case .writeFailure(let error):
                return "Failed to write to tag: \(error.localizedDescription)"
            case .readFailure(let error):
                return "Failed to read tag: \(error.localizedDescription)"
            case .invalidURL:
                return "Invalid URL format"
            case .noURLFound:
                return "No URL found on this NFC tag"
            case .userCancelled:
                return "Scan cancelled"
            }
        }
    }

    /// Operation mode for the NFC session
    private enum OperationMode {
        case write
        case read
    }

    /// Check if NFC reading/writing is available on this device
    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    private var session: NFCNDEFReaderSession?
    private var urlToWrite: String?
    private var writeCompletion: ((Result<Void, Error>) -> Void)?
    private var readCompletion: ((Result<URL, Error>) -> Void)?
    private var operationMode: OperationMode = .write
    private var tagCapacity: Int = 0

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

        self.operationMode = .write
        self.urlToWrite = url
        self.writeCompletion = completion

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag to configure it"
        session?.begin()

        NSLog("NFC Writer: Started session to write URL: \(url)")
    }

    /// Reads a URL from an NFC tag.
    /// - Parameter completion: Called with the URL found on the tag, or an error
    func readURL(completion: @escaping (Result<URL, Error>) -> Void) {
        guard NFCTagWriter.isAvailable else {
            completion(.failure(WriterError.nfcNotAvailable))
            return
        }

        self.operationMode = .read
        self.readCompletion = completion

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag to scan it"
        session?.begin()

        NSLog("NFC Reader: Started session to read URL")
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCTagWriter: NFCNDEFReaderSessionDelegate {

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        NSLog("NFC: Session became active")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // This method is required by protocol but not used - we use manual tag querying instead
        NSLog("NFC: didDetectNDEFs called (not using automatic detection)")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        NSLog("NFC: Detected \(tags.count) tag(s) in \(operationMode == .read ? "READ" : "WRITE") mode")

        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tags detected")
            if operationMode == .write {
                writeCompletion?(.failure(WriterError.noTagsDetected))
            } else {
                readCompletion?(.failure(WriterError.noTagsDetected))
            }
            cleanup()
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC: Failed to connect to tag: \(error)")
                session.invalidate(errorMessage: "Failed to connect to tag")
                if self.operationMode == .write {
                    self.writeCompletion?(.failure(WriterError.writeFailure(error)))
                } else {
                    self.readCompletion?(.failure(WriterError.readFailure(error)))
                }
                self.cleanup()
                return
            }

            // Handle based on operation mode
            if self.operationMode == .read {
                self.readFromTag(tag, session: session)
            } else {
                self.queryAndWriteTag(tag, session: session)
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        NSLog("NFC: Session invalidated: \(error)")

        // Check if user cancelled
        let nfcError = error as? NFCReaderError
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled {
            NSLog("NFC: User cancelled")
            // Report cancellation
            if operationMode == .write {
                writeCompletion?(.failure(WriterError.userCancelled))
            } else {
                readCompletion?(.failure(WriterError.userCancelled))
            }
        } else if nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            // This is expected after successful read - completion already called
            NSLog("NFC: Session ended after tag read (expected)")
        } else {
            // Report other errors
            if operationMode == .write {
                writeCompletion?(.failure(error))
            } else {
                readCompletion?(.failure(WriterError.readFailure(error)))
            }
        }

        cleanup()
    }

    // MARK: - Private Helpers

    private func readFromTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        NSLog("NFC Reader: Reading NDEF message from tag")

        tag.readNDEF { [weak self] message, error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC Reader: Failed to read NDEF: \(error)")
                session.invalidate(errorMessage: "Failed to read tag")
                self.readCompletion?(.failure(WriterError.readFailure(error)))
                self.cleanup()
                return
            }

            guard let message = message else {
                NSLog("NFC Reader: No NDEF message on tag")
                session.invalidate(errorMessage: "No data on tag")
                self.readCompletion?(.failure(WriterError.noURLFound))
                self.cleanup()
                return
            }

            NSLog("NFC Reader: Found NDEF message with \(message.records.count) record(s)")

            // Look for a URL in the NDEF records
            for record in message.records {
                if let url = record.wellKnownTypeURIPayload() {
                    NSLog("NFC Reader: Found URL: \(url.absoluteString)")
                    session.alertMessage = "NFC tag scanned successfully!"
                    session.invalidate()
                    self.readCompletion?(.success(url))
                    self.cleanup()
                    return
                }
            }

            // No URL found in any record
            NSLog("NFC Reader: No URL found in NDEF records")
            session.invalidate(errorMessage: "No URL found on this tag")
            self.readCompletion?(.failure(WriterError.noURLFound))
            self.cleanup()
        }
    }

    private func queryAndWriteTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { [weak self] status, capacity, error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC Writer: Failed to query tag status: \(error)")
                session.invalidate(errorMessage: "Failed to read tag status")
                self.writeCompletion?(.failure(WriterError.writeFailure(error)))
                self.cleanup()
                return
            }

            NSLog("NFC Writer: Tag capacity: \(capacity) bytes, status: \(status.rawValue)")
            self.tagCapacity = capacity

            switch status {
            case .notSupported:
                NSLog("NFC Writer: Tag does not support NDEF")
                session.invalidate(errorMessage: "Tag does not support NDEF")
                self.writeCompletion?(.failure(WriterError.tagNotWritable))
                self.cleanup()

            case .readOnly:
                NSLog("NFC Writer: Tag is read-only")
                session.invalidate(errorMessage: "Tag is read-only")
                self.writeCompletion?(.failure(WriterError.tagNotWritable))
                self.cleanup()

            case .readWrite:
                self.writeToTag(tag, session: session, capacity: capacity)

            @unknown default:
                NSLog("NFC Writer: Unknown tag status")
                session.invalidate(errorMessage: "Unknown tag status")
                self.writeCompletion?(.failure(WriterError.tagNotWritable))
                self.cleanup()
            }
        }
    }

    private func writeToTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession, capacity: Int) {
        guard let urlString = urlToWrite,
              let url = URL(string: urlString),
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            NSLog("NFC Writer: Failed to create NDEF payload")
            session.invalidate(errorMessage: "Failed to create tag data")
            writeCompletion?(.failure(WriterError.invalidURL))
            cleanup()
            return
        }

        let message = NFCNDEFMessage(records: [payload])
        let messageLength = message.length

        NSLog("NFC Writer: Message size: \(messageLength) bytes, Tag capacity: \(capacity) bytes")

        // Check if message fits in tag
        if messageLength > capacity {
            NSLog("NFC Writer: Insufficient capacity - need \(messageLength), have \(capacity)")
            session.invalidate(errorMessage: "Tag too small (\(capacity) bytes). Use NTAG215+")
            writeCompletion?(.failure(WriterError.insufficientCapacity(required: messageLength, available: capacity)))
            cleanup()
            return
        }

        tag.writeNDEF(message) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                NSLog("NFC Writer: Write failed: \(error)")
                // Check if it's a capacity-related error
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("space") || errorString.contains("capacity") || errorString.contains("size") {
                    session.invalidate(errorMessage: "Tag too small. Use NTAG215 or larger.")
                    self.writeCompletion?(.failure(WriterError.insufficientCapacity(required: messageLength, available: capacity)))
                } else {
                    session.invalidate(errorMessage: "Failed to write to tag")
                    self.writeCompletion?(.failure(WriterError.writeFailure(error)))
                }
            } else {
                NSLog("NFC Writer: Write succeeded")
                session.alertMessage = "NFC tag configured successfully!"
                session.invalidate()
                self.writeCompletion?(.success(()))
            }

            self.cleanup()
        }
    }

    private func cleanup() {
        urlToWrite = nil
        writeCompletion = nil
        readCompletion = nil
        session = nil
        tagCapacity = 0
    }
}
