//
//  HabiticaResponseCall.swift
//  Habitica API Client
//
//  Created by Phillip Thelen on 07.03.18.
//  Copyright © 2018 HabitRPG Inc. All rights reserved.
//

import Foundation
import FunkyNetwork
import ReactiveSwift
import Result

class HabiticaResponseCall<T: Any, C: Decodable>: AuthenticatedCall {
    public lazy var habiticaResponseSignal: Signal<HabiticaResponse<C>?, NoError> = jsonSignal.map({ json in
        return json as? Dictionary<String, Any>
    })
        .skipNil()
        .map { (jsonData) -> Data? in
            return try? JSONSerialization.data(withJSONObject: jsonData)
        }
        .skipNil()
        .map(type(of: self).parse)
        .merge(with: errorDataSignal.map { _ -> HabiticaResponse<C>? in
            return nil
        })
        .take(first: 1)
    
    static func parse(_ data: Data) -> HabiticaResponse<C>? {
        let decoder = JSONDecoder()
        decoder.setHabiticaDateDecodingStrategy()
        do {
            return try decoder.decode(HabiticaResponse<C>.self, from: data)
        } catch {
            if let errorHandler = self.errorHandler {
                type(of: errorHandler).handle(error: error as NSError, messages: [])
            }
        }
        return nil
    }
    
    override func setupErrorHandler() {
        AuthenticatedCall.errorHandler?.observe(signal: errorSignal)
        AuthenticatedCall.errorHandler?.observe(signal: errorJsonSignal.map({ json -> [String] in
            return [json["message"] as? String ?? ""]
        }))
        AuthenticatedCall.errorHandler?.observe(signal: serverErrorSignal.combineLatest(with: jsonSignal)
            .map({ (error, jsonAny) -> (NSError, [String]) in
                let json = jsonAny as? Dictionary<String, Any>
                var errors = [String]()
                if let jsonErrors = json?["errors"] as? [[String: Any]] {
                    for jsonError in jsonErrors {
                        if let errorMessage = jsonError["message"] as? String {
                            errors.append(errorMessage)
                        }
                    }
                }
                if let message = json?["message"] as? String {
                    errors.append(message)
                }
                return (error, errors)
            }))
    }
}
