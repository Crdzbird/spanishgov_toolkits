//
//  Data.swift
//  DNISandboxing
//
//  Created by david.martin.saiz on 15/4/24.
//

import Foundation

extension Data {
  
  /// Show data in  UInt8 format.
  var bytes: [UInt8] {
    [UInt8](self)
  }
  
  /// Encoding options for Hex data.
  struct HexEncodingOptions: OptionSet {
    let rawValue: Int
    
    static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
  }
  
  /// Function for show hexadecimal data as String format.
  /// - Parameter options: Encoding options for hex.
  /// - Returns: result as String.
  func hexEncodedString(options: HexEncodingOptions = []) -> String {
    let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
    return self.map { String(format: format, $0) }.joined()
  }
  
  func toUtf8String() -> String {
    return String(data: self, encoding: .utf8) ?? ""
  }
}

