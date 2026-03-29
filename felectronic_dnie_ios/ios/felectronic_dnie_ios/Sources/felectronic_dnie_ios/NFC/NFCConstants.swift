//
//  NFCConstants.swift
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

import Foundation

struct NFCConstants {
  static let atrCheck = "E1F35E11"
  static let atrFake = [0x3B, 0x88, 0x80, 0x01, 0xE1, 0xF3, 0x5E, 0x11, 0x77, 0x81, 0xA1, 0x00, 0x03]
  static let sessionBeginNotification = "session.begin"
  static let sessionInvalidateNotification = "session.invalidate"
  static let apduCommandNotification = "apdu.command"
  static let dnieReadingNotification = "dni.info"
  static let dnieReadingLoggerNotification = "dni.logger"
}
