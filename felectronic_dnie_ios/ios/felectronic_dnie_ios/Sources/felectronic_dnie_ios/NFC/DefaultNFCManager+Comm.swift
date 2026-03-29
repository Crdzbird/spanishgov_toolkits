//
import CoreNFC

// MARK: - Notifications from jmulticard library

extension DefaultNFCManager {
  
  @objc func sessionBegin(_ notification: Notification?) {
    guard let session = sessionTag?.session else {
      return
    }
    session.alertMessage = "Leyendo..."
    session.begin()
  }
  
  @objc func sessionInvalidate(_ notification: Notification?) {
    NFCLogger.default.devLog(.error, "sessionInvalidate")
    
    closeSessionWithOptionalError(NFCCommandError.generic.description)
  }
  
  @objc func receiveAPDU(_ notification: Notification?) {
    guard let apdu = notification?.userInfo?["apdu"] as? NFCISO7816APDU else {
      return
    }
    NFCLogger.default.devLog(.nfcReceivedMessage, "<<< receive APDU from jmulticard: \(apdu)")
    
    sendCommand(with: apdu)
  }
  
  @objc func readingDniInfo(_ notification: Notification?) {
    guard let dniNot = notification?.userInfo?["message"] as? String else {
      return
    }
    NFCLogger.default.devLog(.nfcReceivedMessage, dniNot)
    sendDniReadInfo(message: dniNot)
  }
}
