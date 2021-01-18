//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import Combine

final class ActionEditViewController: UIViewController {
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Text>.SingleCellType<TextViewCell>
    
    private enum Section: CaseIterable {
        case title
        case mqttTopic
        case message
        
        var title: String {
            switch self {
            case .title: return "Title:"
            case .mqttTopic: return "MQTT Topic:"
            case .message: return "Message:"
            }
        }
        
        var textViewHeight: CGFloat {
            switch self {
            case .title,
                 .mqttTopic: return 50
            case .message: return 300
            }
        }
        
        var isTextViewOneline: Bool {
            switch self {
            case .title,
                 .mqttTopic: return true
            case .message: return false
            }
        }
    }
    
    private struct Text: Hashable {
        let id = UUID()
        var value: String
    }
    
    private enum ElementKind: String {
        case textViewTitleView
        case okCancelButtonsView
    }
    
    private let didDisappearHandler: (ActionEditViewController) -> Void
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = false
        return collectionView
    }()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        .init { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            guard let section = Section.allCases[safe: sectionIndex] else { return nil }
            let layoutSection = self.makeLayoutSection(textViewHeight: section.textViewHeight)
            let okCancelButtonsView = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .absolute(64)),
                elementKind: ElementKind.okCancelButtonsView.rawValue,
                alignment: .bottom)
            if sectionIndex == Section.allCases.indices.last {
                layoutSection.boundarySupplementaryItems.append(okCancelButtonsView)
            }
            return layoutSection
        }
    }()
    
    private func makeLayoutSection(textViewHeight: CGFloat) -> NSCollectionLayoutSection {
        let textView = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                       heightDimension: .absolute(textViewHeight)),
                                                     subitems: [textView])
        let textViewTitleView = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                              heightDimension: .absolute(36)),
            elementKind: ElementKind.textViewTitleView.rawValue,
            alignment: .top)
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [textViewTitleView]
        section.contentInsets = .init(top: 0, leading: 0, bottom: 8, trailing: 0)
        return section
    }
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(
            collectionView: collectionView,
            cellRegistrationHandler: { [weak self] textViewCell, indexPath, text in
                guard let self = self else { return }
                guard let section = Section.allCases[safe: indexPath.section] else { return }
                textViewCell.textView.text = text.value
                textViewCell.textView.inputAccessoryView = self.doneToolBar
                textViewCell.textView.delegate = self
                textViewCell.textView.tag = indexPath.section
                textViewCell.textView.returnKeyType = section.isTextViewOneline ? .done : .default
            })
        let textViewTitleViewRegistration = UICollectionView.SupplementaryRegistration<TextViewTitleView>(
            elementKind: ElementKind.textViewTitleView.rawValue) { [weak self] textViewTitleView, _, indexPath in
            guard let self = self else { return }
            guard let section = Section.allCases[safe: indexPath.section] else { return }
            textViewTitleView.display(title: section.title)
        }
        let okCancelButtonsViewRegistration = UICollectionView.SupplementaryRegistration<OkCancelButtonsView>(
            elementKind: ElementKind.okCancelButtonsView.rawValue) { [weak self] okCancelButtonsView, _, _ in
            guard let self = self else { return }
            okCancelButtonsView.actionPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    guard let self = self else { return }
                    switch $0 {
                    case .ok: self.action = self.editingAction
                    case .cancel: break
                    }
                    self.dismiss(animated: true)
                }
                .store(in: &self.bag)
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            guard let kind = ElementKind(rawValue: kind) else { return nil }
            switch kind {
            case .textViewTitleView:
                return collectionView.dequeueConfiguredReusableSupplementary(using: textViewTitleViewRegistration,
                                                                             for: indexPath)
            case .okCancelButtonsView:
                return collectionView.dequeueConfiguredReusableSupplementary(using: okCancelButtonsViewRegistration,
                                                                             for: indexPath)
            }
        }
        return dataSource
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Button Edit"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 36)
        return label
    }()
    
    private lazy var deleteButton = UIButton(systemImageName: "trash.circle.fill",
                                             size: 48) { [weak self] _ in
        guard let self = self else { return }
        let alert = UIAlertController(title: "Sure to delete button?",
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(.init(title: "CANCEL",
                              style: .default,
                              handler: nil))
        alert.addAction(.init(title: "OK",
                              style: .default,
                              handler: { _ in
                                self.action = .init(title: "",
                                                    topic: "",
                                                    message: "")
                                self.dismiss(animated: true)
                              }))
        self.present(alert, animated: true)
    }
    
    private lazy var doneToolBar: UIToolbar = {
        // init with a big enough height to avoid constraint error
        let toolBar = UIToolbar(frame: .init(x: 0, y: 0, width: 0, height: 100))
        toolBar.setItems([.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          .init(barButtonSystemItem: .done, target: self, action: #selector(doneToolBarDoneButtonDidTap(_:)))],
                         animated: false)
        toolBar.sizeToFit()
        return toolBar
    }()
    
    @objc private func doneToolBarDoneButtonDidTap(_ sender: Any) { view.endEditing(true) }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private var editingAction: Action
    
    private var action: Action {
        didSet {
            guard oldValue != action else { return }
            actionDidChangeHandler(action)
        }
    }
    private let actionDidChangeHandler: (Action) -> Void
    
    private var bag = Set<AnyCancellable>()
    
    init(action: Action,
         actionDidChangeHandler: @escaping (Action) -> Void,
         didDisappearHandler: @escaping (ActionEditViewController) -> Void) {
        self.action = action
        self.didDisappearHandler = didDisappearHandler
        self.actionDidChangeHandler = actionDidChangeHandler
        self.editingAction = action
        super.init(nibName: nil, bundle: nil)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(handleKeyboardWillHideOrWillShowNotification(_:)),
                                       name: UIResponder.keyboardWillHideNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(handleKeyboardWillHideOrWillShowNotification(_:)),
                                       name: UIResponder.keyboardWillShowNotification,
                                       object: nil)
        setupLayouts()
        displayAction()
    }
    
    private func setupLayouts() {
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewDidTap(_:))))
        view.backgroundColor = .background
        
        let container = UIView()
        container.backgroundColor = .clear
        
        view.addSubviews(container
                            .top(to: view.safeAreaLayoutGuide.top, 16)
                            .leading(to: view.safeAreaLayoutGuide.leading, 16)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -16)
                            .bottom(to: view.safeAreaLayoutGuide.bottom, -16))
        
        let topContainer = UIView()
        topContainer.backgroundColor = .clear
        
        container.addSubviews(
            topContainer
                .top(to: container.top)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .height(to: 56),
            collectionView
                .top(to: topContainer.bottom, 16)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .bottom(to: container.bottom)
        )
        
        topContainer.addSubviews(
            titleLabel
                .centerX(to: topContainer.centerX)
                .centerY(to: topContainer.centerY),
            deleteButton
                .trailing(to: topContainer.trailing)
                .centerY(to: topContainer.centerY)
                .width(to: 48)
                .height(to: 48)
        )
    }
    
    private func displayAction() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Text>()
        Section.allCases.forEach {
            snapshot.appendSections([$0])
            switch $0 {
            case .title: snapshot.appendItems([.init(value: editingAction.title)])
            case .mqttTopic: snapshot.appendItems([.init(value: editingAction.topic)])
            case .message: snapshot.appendItems([.init(value: editingAction.message)])
            }
        }
        dataSource.apply(snapshot)
    }
    
    @objc func handleKeyboardWillHideOrWillShowNotification(_ notification: Notification) {
        let buttomInset: CGFloat
        
        switch notification.name {
        case UIResponder.keyboardWillHideNotification: buttomInset = 0
        case UIResponder.keyboardWillShowNotification:
            guard let keyboardFrameInValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            let keyboardEndFrameInScreen = keyboardFrameInValue.cgRectValue
            buttomInset = keyboardEndFrameInScreen.height - view.safeAreaInsets.bottom
        default: return
        }
        
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: buttomInset, right: 0)
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = insets
    }
    
    @objc private func viewDidTap(_ sender: Any) { view.endEditing(true) }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didDisappearHandler(self)
    }
}

extension ActionEditViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let section = Section.allCases[safe: textView.tag] else { return true }
        
        let shouldEndEditing = section.isTextViewOneline && text == "\n"
        if shouldEndEditing {
            textView.endEditing(true)
            return false
        }
        
        let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
        
        switch section {
        case .title: editingAction.title = newText
        case .mqttTopic: editingAction.topic = newText
        case .message: editingAction.message = newText
        }
        
        return true
    }
}
