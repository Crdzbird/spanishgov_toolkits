//
import Foundation

extension String {
  
  var htmlToAttributedString: NSAttributedString? {
    guard let data = data(using: .utf8) else {
      return nil
    }
    do {
      return try NSAttributedString(data: data,
                                    options: [.documentType: NSAttributedString.DocumentType.html,
                                              .characterEncoding: String.Encoding.utf8.rawValue],
                                    documentAttributes: nil)
    } catch {
      return nil
    }
  }
  
  var htmlToString: String {
    htmlToAttributedString?.string ?? ""
  }
  
  var asAttributedString: NSAttributedString {
    NSAttributedString(string: self)
  }
  
  func fromBase64() -> String? {
    guard let data = Data(base64Encoded: self, options: Data.Base64DecodingOptions(rawValue: 0)) else {
      return nil
    }
    return String(data: data as Data, encoding: String.Encoding.utf8)
  }
  
  func toBase64() -> String? {
    guard let data = self.data(using: String.Encoding.utf8) else {
      return nil
    }
    return data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
  }
  
  func join<S: Sequence>(_ elements: S) -> String {
    elements.map { String(describing: $0) }.joined(separator: self)
  }
  
  func inserting(separator: String, every number: Int) -> String {
    var result = ""
    let characters = Array(self)
    stride(from: 0, to: characters.count, by: number).forEach {
      result += String(characters[$0..<min($0 + number, characters.count)])
      if $0 + number < characters.count {
        result += separator
      }
    }
    return result
  }
  
  var nsRange: NSRange {
    NSRange(location: 0, length: (self as NSString).length)
  }
  
  var firstUppercased: String {
    prefix(1).uppercased() + dropFirst().lowercased()
  }
  
  subscript (i: Int) -> Character {
    self[index(startIndex, offsetBy: i)]
  }
  
  subscript (bounds: CountableClosedRange<Int>) -> String {
    let start = index(startIndex, offsetBy: bounds.lowerBound)
    let end = index(startIndex, offsetBy: bounds.upperBound)
    return String(self[start...end])
  }
  
  subscript (bounds: CountableRange<Int>) -> String {
    let start = index(startIndex, offsetBy: bounds.lowerBound)
    let end = index(startIndex, offsetBy: bounds.upperBound)
    return String(self[start..<end])
  }
  
  func isValidUsingRegex(_ regex: String) -> Bool {
    range(of: regex, options: .regularExpression) != nil
  }
  
  func safeReplacingCharacters(in range: NSRange, with replacement: String) -> String {
    guard Range(range, in: self) != nil else {
      return ""
    }
    return (self as NSString).replacingCharacters(in: range, with: replacement)
  }
  
  func paddingLeft(with character: Character, toLength length: Int) -> String {
    let paddingLength = max(length - count, 0)
    let padding = String(repeating: character, count: paddingLength)
    return "\(padding)\(self)"
  }
  
  func removeMultiWhitespace() -> String {
    let components = self.components(separatedBy: CharacterSet.whitespacesAndNewlines)
    return components.filter { !$0.isEmpty }.joined(separator: " ")
  }
  
  func addWhitespacesBetweenCharacters() -> String {
    self.map { String($0) }.joined(separator: " ")
  }
  
  func substringToOccurence(with character: String) -> String {
    let token = self.components(separatedBy: character)
    return token[0]
  }
  
  func substringFromOccurence(with character: String) -> String {
    let token = self.components(separatedBy: character)
    return token.last ?? ""
  }
  
  /// Funciton to add header and footer to base64 keys for accomplish Certificate requirements format.
  /// - Parameters:
  ///   - header: string format header f.e. -----BEGIN RSA PRIVATE KEY-----
  ///   - footer: string format footer f.e. -----END RSA PRIVATE KEY-----
  /// - Returns: Base64 string as PEM format.
  func pemFormat(withHeader header: String, footer: String) -> String {
    var result: [String] = [header]
    let characters = Array(self)
    let lineSize = 64
    stride(from: 0, to: characters.count, by: lineSize).forEach {
      result.append(String(characters[$0..<min($0 + lineSize, characters.count)]))
    }
    result.append(footer)
    return result.joined(separator: "\n")
  }
  
  func asUTF8Data() -> Data {
    Data(self.utf8)
  }
  
  func asNSString() -> NSString {
    NSString(string: self)
  }
  
  func asDate(withFormat format: String = "yyyy/MM/dd") -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter.date(from: self)
  }
  
  /// Extension function for convert string to Data
  /// - Returns: Data stream bytes.
  func toUtf8Data() -> Data {
    Data(self.utf8)
  }
  
  func normalizeBase64ForPreSign() -> String {
    self.replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
  }
  
  func normalizeBase64ForSelfSign() -> String {
    self.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
  }
  
  func base64DecodedString() -> String? {
    if let data = Data(base64Encoded: self) {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
  
  func base64Decode() -> Data? {
    if let data = Data(base64Encoded: self) {
      return data
    }
    return nil
  }
  
  
  
  func xmlParser() -> XMLParser? {
    guard let data = self.data(using: .utf8) else {
      return nil
    }
    return XMLParser(data: data)
  }
  
  func addPKCS1forPostSign( pkcs1: String) -> String {
    if let rangoInicio = self.range(of: "<param n=\"PRE\">"),
       let rangoFin = self.range(of: "</param>", range: rangoInicio.upperBound..<self.endIndex) {
      // Se encontró la línea que comienza con "<param n=\"PRE\">" y termina con "</param>"
      let indiceInicio = self.distance(from: self.startIndex, to: rangoInicio.lowerBound)
      let indiceFin = self.distance(from: self.startIndex, to: rangoFin.upperBound)
      let nuevaEntrada = self.prefix(indiceFin) + "\n" + "<param n=\"PK1\">\(pkcs1)</param>" + "\n" + self.suffix(from: rangoFin.upperBound)
      return String(nuevaEntrada)
    } else {
      // No se encontró la línea, se devuelve el XML original.
      return self
    }
  }
  
  func idespSlice() -> MRZLines {
    let longitud = self.count
    let tercios = longitud / 3
    
    let inicioPrimeraParte = self.startIndex
    let finalPrimeraParte = self.index(inicioPrimeraParte, offsetBy: tercios)
    let primeraParte = self[inicioPrimeraParte..<finalPrimeraParte]
    
    let inicioSegundaParte = finalPrimeraParte
    let finalSegundaParte = self.index(inicioSegundaParte, offsetBy: tercios)
    let segundaParte = self[inicioSegundaParte..<finalSegundaParte]
    
    let inicioTerceraParte = finalSegundaParte
    let finalTerceraParte = self.endIndex
    let terceraParte = self[inicioTerceraParte..<finalTerceraParte]
    
    return .init(
      line0: String(primeraParte),
      line1: String(segundaParte),
      line2: String(terceraParte)
    )
  }
  
  func splitDateBy(splitChar: String) -> (day: String, month: String, year: String) {
    let slices = self.components(separatedBy: splitChar)
    if slices.count == 3 {
      return (slices.first ?? "", slices[1] ?? "", slices.last ?? "")
    }
    return ("", "", "")
    
  }
  func isDateExpired() -> Bool {
    let currentDate = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    let dateString = self
    
    if let date = dateFormatter.date(from: dateString) {
      if date > currentDate {
        return false
      } else {
        return true
      }
    } else {
      return true
    }
  }
  
  func removeHeaderAndFooter() -> String {
    self
      .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
      .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
      .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
      .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
      .replacingOccurrences(of: "\n", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func compareVersions(_ version2: String) -> ComparisonResult {
    let components1 = self.components(separatedBy: ".")
    let components2 = version2.components(separatedBy: ".")
    
    let maxLength = max(components1.count, components2.count)
    
    for index in 0..<maxLength {
      let component1 = index < components1.count ? components1[index] : "0"
      let component2 = index < components2.count ? components2[index] : "0"
      
      if let number1 = Int(component1), let number2 = Int(component2) {
        if number1 < number2 {
          return .orderedAscending
        } else if number1 > number2 {
          return .orderedDescending
        }
      } else {
        
        return .orderedSame
      }
    }
    return .orderedSame
  }
  
  
  func withRepeatedSpacesRemoved() -> String {
    self
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
  
  func asSanitizedNIF() -> String {
    FormatUtils.sanitizeNIF(self)
  }
  
  func asSanitizedEmail() -> String {
    FormatUtils.sanitizeEmail(self)
  }
  
  func asSanitizedZip() -> String {
    FormatUtils.sanitizeZip(self)
  }
  
  func asSanitizedAddress() -> String {
    FormatUtils.sanitizeAddress(self)
  }
  
  func asSanitizedPhone() -> String {
    FormatUtils.sanitizePhone(self)
  }
  
  func asSanitizedFloor() -> String {
    FormatUtils.sanitizeFloor(self)
  }
  
  func asSanitizedCity() -> String {
    FormatUtils.sanitizeCity(self)
  }
  
  func asSanitizedCountry() -> String {
    FormatUtils.sanitizeCountry(self)
  }
  
  func asSanitizedProvince() -> String {
    FormatUtils.sanitizeProvince(self)
  }
}
