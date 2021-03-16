//
//  ViewController.swift
//  CombineLoginForm
//
//  Created by Radoslav Blasko on 15/03/2021.
//

import UIKit
import Combine

class ViewController: UIViewController {
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var greetingLabel: UILabel!
    @IBOutlet weak var errorLabel: UILabel!
    
    private var uiControls: [UIControl] { [username, password, loginButton] }
    private var cancellables = Set<AnyCancellable>()
    private let authService = AuthService()

    override func viewDidLoad() {
        super.viewDidLoad()

        let isValidUsername = username.textPublisher.map { !$0.isEmpty }
        let isValidPassword = password.textPublisher.map { !$0.isEmpty }

        let isValid = isValidUsername.combineLatest(isValidPassword)
            .map { $0 && $1 }

        isValid.assign(to: \.isEnabled, on: loginButton)
            .store(in: &cancellables)

        let isLoadingSubject = PassthroughSubject<Bool, Never>()
        let login: AnyPublisher<Result<String, Error>, Never> = loginButton.publisher(for: .touchUpInside)
            .map { [unowned self] _ in (self.username.text ?? "", self.password.text ?? "") }
            .flatMap { [unowned self] credentials -> AnyPublisher<Result<String, Error>, Never> in
                isLoadingSubject.send(true)
                return self.authService.login(username: credentials.0, password: credentials.1)
                    .map { .success($0) }
                    .catch { Just(.failure($0)) }
                    .handleEvents(receiveCompletion: { _ in isLoadingSubject.send(false) })
                    .eraseToAnyPublisher()
            }
            .share()
            .eraseToAnyPublisher()

        let errorLabelText: AnyPublisher<String?, Never> = login.map { r -> String? in
            switch r {
            case .success:
                return nil
            case .failure:
                return "Wrong credentials, try again..."
            }
        }
        .merge(with: isLoadingSubject.filter { $0 }.map { _ in nil })
        .share()
        .eraseToAnyPublisher()

        errorLabelText
            .map { $0 == nil }
            .sink(receiveValue: { [unowned self] isHidden in
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                    self.errorLabel.alpha = isHidden ? 0 : 1
                }
            })
            .store(in: &cancellables)

        errorLabelText
            .assign(to: \.text, on: errorLabel)
            .store(in: &cancellables)

        let onLoggedIn: AnyPublisher<String, Never> = login
            .compactMap { result -> String? in
                switch result {
                case let .success(name):
                    return name
                case .failure:
                    return nil
                }
            }
            .share()
            .eraseToAnyPublisher()

        let isUIEnabled: AnyPublisher<Bool, Never> = isLoadingSubject
            .prefix(untilOutputFrom: onLoggedIn)
            .map { !$0 }
            .eraseToAnyPublisher()
        uiControls.forEach {
            isUIEnabled.assign(to: \.isEnabled, on: $0)
            .store(in: &cancellables)
        }

        onLoggedIn
            .sink { [unowned self] name in
                let transform = CGAffineTransform(translationX: 0, y: -self.view.frame.size.height)
                UIView.animate(withDuration: 0.5, delay: 0.1, options: .curveEaseIn) {
                    self.uiControls.forEach {
                        $0.transform = transform
                        $0.alpha = 0
                    }
                } completion: { _ in
                    self.uiControls.forEach { $0.isHidden = true }
                }

                self.greetingLabel.transform = CGAffineTransform(translationX: 0, y: self.view.frame.size.height - self.greetingLabel.frame.minY)
                self.greetingLabel.alpha = 0
                self.greetingLabel.text = "Welcome back\n\(name.capitalized)"
                UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut) {
                    self.greetingLabel.alpha = 1
                    self.greetingLabel.transform = .identity
                    self.view.backgroundColor = .systemBackground
                }
            }
            .store(in: &cancellables)

        let tap = UITapGestureRecognizer(target: self, action: #selector(greetingTapped))
        greetingLabel.isUserInteractionEnabled = true
        greetingLabel.addGestureRecognizer(tap)
    }

    @objc private func greetingTapped() {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()!
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true, completion: nil)
    }
}
