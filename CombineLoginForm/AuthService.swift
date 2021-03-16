//
//  AuthService.swift
//  CombineLoginForm
//
//  Created by Radoslav Blasko on 15/03/2021.
//

import Foundation
import Combine

struct AuthService {
    enum Error: Swift.Error {
        case unauthorized
    }

    func login(username: String, password: String) -> AnyPublisher<String, Error> {
        Future<String, Error> { block in
            let success = username == "steve" && password == "12345"
            let result: Result<String, Error>

            if success {
                result = .success("Steve")
            } else {
                result = .failure(.unauthorized)
            }

            block(result)
        }
        .delay(for: .seconds(1), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
