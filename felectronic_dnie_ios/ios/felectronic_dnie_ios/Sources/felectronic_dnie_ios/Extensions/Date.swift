//

import Foundation

enum FNDateFormat: String {
  case short = "MM-dd-yyyy"
}

struct SimpleDate: Codable {
  var year: Int
  var month: Int
  var day: Int
}

extension Date {
  static func - (lhs: Date, rhs: Date) -> TimeInterval {
    return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
  }
  
  func formattedDate() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    return dateFormatter.string(from: self)
  }
  
  func toSimpleDate(calendar: Calendar = Calendar.current) -> SimpleDate? {
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
    
    guard let year = components.year else {
      return nil
    }
    guard let month = components.month else {
      return nil
    }
    guard let day = components.day else {
      return nil
    }
    
    return .init(
      year: year,
      month: month,
      day: day
    )
  }
}
