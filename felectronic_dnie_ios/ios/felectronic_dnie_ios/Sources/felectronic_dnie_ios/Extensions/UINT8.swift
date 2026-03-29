//

import Foundation

extension UInt8 {
  
  func toString() -> String {
    String(format: "%02X", self)
  }
}
