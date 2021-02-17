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
    enum Action { case ok, cancel, delete }
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Text>.SingleCellType<TextViewCell>
    
    private enum Layout {
        static let collectionViewContentInsetBottom: CGFloat = 60
    }
    
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
                 .mqttTopic: return 40
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
    }
    
    private let actionHandler: (ActionEditViewController, Action) -> Void
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.contentInset = .init(top: 0, left: 0, bottom: Layout.collectionViewContentInsetBottom, right: 0)
        return collectionView
    }()
    
    private lazy var layout: UICollectionViewCompositionalLayout = {
        .init { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            guard let section = Section.allCases[safe: sectionIndex] else { return nil }
            return self.makeLayoutSection(textViewHeight: section.textViewHeight)
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
                              heightDimension: .absolute(33)),
            elementKind: ElementKind.textViewTitleView.rawValue,
            alignment: .top)
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [textViewTitleView]
        section.contentInsets = .init(top: 0, leading: 0, bottom: 10, trailing: 0)
        return section
    }
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(
            collectionView: collectionView,
            cellRegistrationHandler: { [weak self] textViewCell, indexPath, _ in
                guard let self = self else { return }
                guard let section = Section.allCases[safe: indexPath.section] else { return }
                let text: String?
                switch section {
                case .title: text = self.editingAction.title
                case .mqttTopic: text = self.editingAction.topic
                case .message: text = self.editingAction.message
                }
                textViewCell.textView.text = text
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
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            guard let kind = ElementKind(rawValue: kind) else { return nil }
            switch kind {
            case .textViewTitleView:
                return collectionView.dequeueConfiguredReusableSupplementary(using: textViewTitleViewRegistration,
                                                                             for: indexPath)
            }
        }
        return dataSource
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Button Edit"
        label.textColor = .accent
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    private lazy var deleteButton = UIButton(systemImageName: "trash.circle.fill",
                                             size: 40) { [weak self] _ in
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
                                self.actionHandler(self, .delete)
                              }))
        self.present(alert, animated: true)
    }
    
    private lazy var okCancelButtonView: OkCancelButtonsView = {
        let okCancelButtonsView = OkCancelButtonsView()
        okCancelButtonsView.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                switch $0 {
                case .ok:
                    self.action = self.editingAction
                    self.actionHandler(self, .ok)
                case .cancel:
                    self.actionHandler(self, .cancel)
                }
            }
            .store(in: &self.bag)
        return okCancelButtonsView
    }()
    
    
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
    
    private var editingAction: SecuredMQTTPublisher.Action
    
    private var action: SecuredMQTTPublisher.Action {
        didSet {
            guard oldValue != action else { return }
            actionDidChangeHandler(action)
        }
    }
    private let actionDidChangeHandler: (SecuredMQTTPublisher.Action) -> Void
    
    private var bag = Set<AnyCancellable>()
    
    init(action: SecuredMQTTPublisher.Action,
         actionDidChangeHandler: @escaping (SecuredMQTTPublisher.Action) -> Void,
         actionHandler: @escaping (ActionEditViewController, Action) -> Void) {
        self.action = action
        self.actionDidChangeHandler = actionDidChangeHandler
        self.actionHandler = actionHandler
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
                            .top(to: view.safeAreaLayoutGuide.top, 32)
                            .leading(to: view.safeAreaLayoutGuide.leading, 20)
                            .trailing(to: view.safeAreaLayoutGuide.trailing, -20)
                            .bottom(to: view.safeAreaLayoutGuide.bottom, -16))
        
        container.addSubviews(
            titleLabel
                .top(to: container.top)
                .centerX(to: container.centerX),
            deleteButton
                .centerY(to: titleLabel.centerY)
                .trailing(to: container.trailing)
                .width(to: 40)
                .height(to: 40),
            collectionView
                .top(to: titleLabel.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing),
            okCancelButtonView
                .top(to: collectionView.bottom, 20)
                .leading(to: container.leading)
                .trailing(to: container.trailing)
                .bottom(to: container.bottom)
                .height(to: 46)
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
        let bottomInset: CGFloat
        
        switch notification.name {
        case UIResponder.keyboardWillHideNotification: bottomInset = Layout.collectionViewContentInsetBottom
        case UIResponder.keyboardWillShowNotification:
            guard let keyboardFrameInValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
            let keyboardEndFrameInScreen = keyboardFrameInValue.cgRectValue
            bottomInset = keyboardEndFrameInScreen.height - view.safeAreaInsets.bottom
        default: return
        }
        
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        collectionView.contentInset = insets
        collectionView.scrollIndicatorInsets = insets
    }
    
    @objc private func viewDidTap(_ sender: Any) { view.endEditing(true) }
}

extension ActionEditViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        let textViewFrameInCollectionView = textView.convert(textView.bounds, to: collectionView)
        collectionView.scrollRectToVisible(textViewFrameInCollectionView, animated: true)
    }
    
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
