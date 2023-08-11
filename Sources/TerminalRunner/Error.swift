//
//  Error.swift
//  TerminalRunner
//
//  Created by Tiger on 8/11/23.
//

import Foundation

public struct Error: Swift.Error, CustomStringConvertible {
    
    let message: String
    
    init(_ reason: String) {
        message = reason
    }
    
    public var description: String {
        message
    }
    
}
