//
// MARK: - Private session functions
import CoreNFC

extension DefaultNFCManager {
  
  @objc func sendDniReadInfo(message: String) {
    print(message)
    guard let session else {
      return
    }
    session.alertMessage = message
  }
  
  /// Function to send commands to the DNIe.
  /// - Parameters:
  ///   - apdu: apdu data
  func sendCommand(with apdu: NFCISO7816APDU) {
    guard let sessionTag else {
      delegate?.nfcManagerTagReaderSessionError(.noTagSession)
      return
    }
    
    NFCLogger.default.devLog(.info, "sessionTag: sendCommand: apdu: \(apdu)")
    
    sessionTag.sendCommand(apdu: apdu) { result in
      switch result {
      case .success(let response):
        var customCommandResponse = [UInt8]()
        if let payload = response.payload {
          customCommandResponse.append(contentsOf: payload.bytes)
        }
        
        let standardResponseCode = "\(response.statusWord1.toString())\(response.statusWord2.toString())"
        
        if let nfcCommandError = NFCCommandError(rawValue: standardResponseCode),
           nfcCommandError != .necessaryObjectNotPresent {
          let errorDescription = "sessionTag: sendCommand: nfc command error: \(nfcCommandError.localizedDescription)"
          
          NFCLogger.default.devLog(.error, errorDescription)
          
          self.closeSessionWithOptionalError(NFCCommandError.generic.description)
          
          self.delegate?.nfcManagerDidInvalidateWith(nfcCommandError)
          self.errorHasManaged = true
          
        } else {
          NFCLogger.default.devLog(.info, "sessionTag: sendCommand: response: statusWord: ok: \(standardResponseCode)")
          
          customCommandResponse.append(contentsOf: [response.statusWord1, response.statusWord2])
          
          guard let dnieManager = self.dnieManager else {
            NFCLogger.default.devLog(.error, "sessionTag: sendCommand: error")

            self.closeSessionWithOptionalError(NFCCommandError.generic.description)
            return
          }

          let ccr = customCommandResponse.count
          let msg = ">>> sessionTag: sendCommand to jmulticard: data: \(customCommandResponse), count: \(ccr)"
          NFCLogger.default.devLog(.nfcSendMessage, msg)

          dnieManager.setTagSendCommandResponse(Data(customCommandResponse))
        }
      case .failure(let error):
        NFCLogger.default.devLog(.error, "sessionTag: sendCommand: error: \(error.localizedDescription)")
        self.errorHasManaged = true
        if (error as NSError).code != 2 {
          self.delegate?.nfcManagerTagReaderSessionError(.tagSendCommandFail)
          self.closeSessionWithOptionalError(NFCCommandError.generic.description)
        }
      }
    }
  }
  
  /// Function to invalidate the session of the NFC module with optional error message.
  /// - Parameters:
  ///   - session: session tag reader
  ///   - error: optional error message
  func closeSessionWithOptionalError(_ error: String?) {
    guard let session = sessionTag?.session else {
      return
    }
    errorHasManaged = true
    if let error {
      NFCLogger.default.devLog(.error, "closeSessionWithOptionalError: error: \(String(describing: error))")
      
      session.invalidate(errorMessage: NFCCommandError.generic.description)
    } else {
      NFCLogger.default.devLog(.info, "closeSessionWithOptionalError: close session ok")
      
      session.invalidate()
    }
    self.session?.invalidate()
    self.session = nil
    self.sessionTag = nil
  }
}
