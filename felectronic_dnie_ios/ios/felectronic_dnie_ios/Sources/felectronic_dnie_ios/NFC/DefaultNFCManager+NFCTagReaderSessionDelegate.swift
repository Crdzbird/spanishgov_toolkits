//
// MARK: - NFCTagReaderSessionDelegate
import CoreNFC

extension DefaultNFCManager: NFCTagReaderSessionDelegate {
  
  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    NFCLogger.default.devLog(.info, "tagReaderSessionDidBecomeActive: \(session)")
  }
  
  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    
    switch (error as NSError).code {
    case 200:
      if !errorHasManaged {
        closeSessionWithOptionalError(NFCCommandError.sessionCancelledByUser.description)
        delegate?.nfcManagerTagReaderSessionError(.userCancelledSession)
      }
    case 201:
      closeSessionWithOptionalError(NFCCommandError.timeout.description)
      delegate?.nfcManagerTagReaderSessionError(.readTimeOut)
    case 2, 202:
      // iOS 17.4 temporary bugfix
      print("iOS 17.4 BUGFIX, DO NOTHING...")
    default:
      closeSessionWithOptionalError(NFCCommandError.generic.description)
    }
  }
  
  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    NFCLogger.default.devLog(.info, "tagReaderSession: \(tags)")
    
    guard let tag = tags.first else {
      delegate?.nfcManagerTagReaderSessionError(.noTag)
      
      closeSessionWithOptionalError(NFCCommandError.generic.description)
      return
    }
    session.connect(to: tag) { error in
      if let error {
        NFCLogger.default.devLog(.error, "session.connect: error: \(error.localizedDescription)")
        
        self.delegate?.nfcManagerTagReaderSessionError(.noTagSession)
        
        self.closeSessionWithOptionalError(NFCCommandError.generic.description)
      } else {
        NFCLogger.default.devLog(.success, "session.connect: ok")
        
        if case let .iso7816(sessionTag) = tag {
          if let atr = self.createFakeATR(for: sessionTag) {
            NFCLogger.default.devLog(.info, "sessionTag: atr: \(atr)")
          }
          
          session.alertMessage = "DNI encontrado, no lo muevas..."
          
          self.sessionTag = sessionTag
          
          switch self.option {
          case .getCertificate:
            session.alertMessage = "DNI encontrado, no lo muevas..."
            self.getDNIeCertificate()
          case .signData:
            session.alertMessage = "DNI encontrado, no lo muevas..."
            self.signDataWithDnie { _ in }

          case .signDataWithPKCS1:
            session.alertMessage = "DNI encontrado, no lo muevas..."
            self.signPKCS1withDNIe { [self] result in
              delegate?.nfcManagerSignPKCS1(result)
            }

          case .probeCard:
            let atrHex = sessionTag.historicalBytes?.hexEncodedString(options: .upperCase)
                ?? sessionTag.applicationData?.hexEncodedString(options: .upperCase)
                ?? ""
            let tagIdHex = sessionTag.identifier.hexEncodedString(options: .upperCase)
            let isValid = self.createFakeATR(for: sessionTag) != nil
            session.alertMessage = isValid
                ? "DNIe detectado correctamente."
                : "La tarjeta no es un DNIe."
            self.closeSessionWithOptionalError(nil)
            self.delegate?.nfcManagerProbeResult(isValid, atrHex, tagIdHex)

          case .verifyPin:
            session.alertMessage = "DNI encontrado, no lo muevas..."
            self.getDNIeCertificate()
          }
        }
        else {
          self.delegate?.nfcManagerTagReaderSessionError(.iso7816Fail)
          self.closeSessionWithOptionalError(NFCCommandError.generic.description)
        }
      }
    }
  }
}
