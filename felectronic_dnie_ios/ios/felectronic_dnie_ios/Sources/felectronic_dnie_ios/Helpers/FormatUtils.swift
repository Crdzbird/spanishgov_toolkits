//

import Foundation

enum FormatUtils {
  static func sanitizeNIF(_ nif: String) -> String {
    nif
      .uppercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  static func sanitizeEmail(_ email: String) -> String {
    email
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }
  
  static func sanitizePhone(_ phone: String) -> String {
    phone
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !$0.isWhitespace }
  }
  
  static func sanitizeAddress(_ address: String) -> String {
    address
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .withRepeatedSpacesRemoved()
  }
  
  static func sanitizeZip(_ zip: String) -> String {
    zip
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .filter { !$0.isWhitespace }
  }
  
  static func sanitizeFloor(_ floor: String) -> String {
    floor
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .withRepeatedSpacesRemoved()
  }
  
  static func sanitizeCity(_ floor: String) -> String {
    floor
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .withRepeatedSpacesRemoved()
  }
  
  static func sanitizeCountry(_ country: String) -> String {
    country
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .withRepeatedSpacesRemoved()
  }
  
  static func sanitizeProvince(_ province: String) -> String {
    province
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .withRepeatedSpacesRemoved()
  }
}
