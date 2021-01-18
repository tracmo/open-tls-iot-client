//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

extension Subscribers.Completion {
    func getError() -> Failure? {
        switch self {
        case .finished: return nil
        case .failure(let error): return error
        }
    }
}

extension Result where Success == Void {
    static var success: Result<Success, Failure> { .success(()) }
}

extension Result {
    func getError() -> Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

extension MutableCollection {
    mutating func mutateEach(_ body: (Index, inout Element) throws -> Void) rethrows {
        for index in indices { try body(index, &self[index]) }
    }
}

extension MutableCollection {
    subscript(safe index: Index) -> Element? {
        get { self.indices.contains(index) ? self[index] : nil }
        set {
            guard self.indices.contains(index),
                let newValue = newValue else { return }
            self[index] = newValue
        }
    }
}

extension UIViewController {
    func present(_ destination: UIViewController?,
                 in modalPresentationStyle: UIModalPresentationStyle = .automatic,
                 with modalTransitionStyle: UIModalTransitionStyle = .coverVertical,
                 animated: Bool = true,
                 completion: (() -> Void)? = nil) {
        guard let destination = destination else { return }
        destination.modalPresentationStyle = modalPresentationStyle
        destination.modalTransitionStyle = modalTransitionStyle
        present(destination, animated: animated, completion: completion)
    }
}

extension UIButton {
    convenience init(systemImageName: String, size: CGFloat, didTapHandler: @escaping UIActionHandler) {
        self.init()
        let systemImage = UIImage(systemName: systemImageName,
                                  withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: size)))?
            .withTintColor(.accent, renderingMode: .alwaysOriginal)
        setImage(systemImage, for: .normal)
        addAction(.init(handler: didTapHandler), for: .touchUpInside)
    }
}

extension UICollectionViewDiffableDataSource {
    class SingleCellType<Cell: UICollectionViewCell>: UICollectionViewDiffableDataSource {
        convenience init(
            collectionView: UICollectionView,
            cellRegistrationHandler: @escaping UICollectionView.CellRegistration<Cell, ItemIdentifierType>.Handler
        ) {
            self.init(collectionView: collectionView,
                      cellProvider: { collectionView, indexPath, item in
                        collectionView.dequeueConfiguredReusableCell(
                            using: .init(handler: cellRegistrationHandler),
                            for: indexPath,
                            item: item)
                      })
        }
    }
}
