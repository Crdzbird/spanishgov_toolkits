//
//  NFCLogging.swift
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

import Foundation
import UIKit

enum NFCLogType {
  case action
  case canceled
  case error
  case info
  case nfcReceivedMessage
  case nfcSendMessage
  case success
  case warning
}

struct NFCLogger {

  static let `default` = NFCLogger()

  func devLog(_ logType: NFCLogType,
              _ message: String,
              utf8Data: Data? = nil,
              ignoreFunctionName: Bool = true,
              function: String = #function) {
#if DEBUG
    let functionName = ignoreFunctionName ? "" : "\(function): "
    if let data = utf8Data, let dataString = String(data: data, encoding: .utf8) {
      let dataMessage = (dataString.isEmpty) ? "No data" : dataString
      log(logType, "\(functionName)\(message)\n\(dataMessage)")
    } else {
      log(logType, "\(functionName)\(message)")
    }
#endif
  }

  func devLog(_ logType: NFCLogType, _ message: String, userInfo: [AnyHashable: Any], function: String = #function) {
#if DEBUG
    if let data = try? JSONSerialization.data(withJSONObject: userInfo, options: [.prettyPrinted]),
       let jsonString = String(data: data, encoding: .utf8) {
      log(logType, "\(function): \(message)\n\(jsonString)")
    } else {
      log(logType, "\(function): \(message)\n\(userInfo)")
    }
#endif
  }

  private func log(_ logType: NFCLogType, _ message: String) {
#if DEBUG
    switch logType {
    case .action:
      print("🚀 Action: \(message)")
    case .canceled:
      print("❌ Cancelled: \(message)")
    case .error:
      print("💣 Error: \(message)")
    case .info:
      print("ℹ️ Info: \(message)")
    case .nfcReceivedMessage:
      print("💬 NFC received message: \(message)")
    case .nfcSendMessage:
      print("💬 NFC send message: \(message)")
    case .success:
      print("✅ Success: \(message)")
    case .warning:
      print("⚠️ Warning: \(message)")
    }
#endif
  }
}
