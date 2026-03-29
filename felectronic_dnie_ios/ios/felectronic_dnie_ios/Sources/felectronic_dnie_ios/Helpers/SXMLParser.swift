//
//  FNMTXMLParser.swift

import Foundation

class SXMLParser: NSObject, XMLParserDelegate {
  private var readValue = false
  private var searchedParam = ""
  public var returnValue: String?

  convenience init(searchedParam: String) {
    self.init()
    self.searchedParam = searchedParam
  }

  func parserDidStartDocument(_ parser: XMLParser) {
    print("Start of the document")
    print("Line number: \(parser.lineNumber)")
  }

  func parserDidEndDocument(_ parser: XMLParser) {
    print("End of the document")
    print("Line number: \(parser.lineNumber)")
  }

  func parser(_ parser: XMLParser,
              didStartElement elementName: String,
              namespaceURI: String?,
              qualifiedName qName: String?,
              attributes attributeDict: [String : String] = [:]) {
    if elementName.elementsEqual("param") {
      if attributeDict.contains(where: { (key: String, value: String) in
        key.elementsEqual("n") && value.elementsEqual(searchedParam)
      }) {
        readValue = true
      }
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if readValue {
      returnValue = string
      readValue = false
    }
  }

}
