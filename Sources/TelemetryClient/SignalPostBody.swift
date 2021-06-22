//
//  File.swift
//  
//
//  Created by Daniel Jilg on 22.06.21.
//

import Foundation

struct SignalPostBody: Codable, Equatable {
    let receivedAt: Date
    let type: String
    let clientUser: String
    let sessionID: String
    let payload: [String: String]?
}
