//
import CoreNFC
import Foundation

enum SignatureFormat: String {
  case cades = "cades" // Cades es binario
  case pades = "pades" // Pades es PDF
  case xades = "xades" // Xades es XML
}

enum SignatureAlgorithm: String {
  case sha512withRSA = "SHA512withRSA"
  case sha256withRSA = "SHA256withRSA"
}

class DefaultNFCManager: NSObject, NFCManager {


  // MARK: - Properties

  weak var delegate: NFCManagerDelegate?

  var session: NFCTagReaderSession?
  var sessionTag: NFCISO7816Tag?
  var dnieManager: DNIeCardOperations?
  var can: String?
  var pin: String?
  var certAlias: String?
  var option: NFCManagerOption = .signDataWithPKCS1
  var data: Data?
  var errorHasManaged: Bool = false

  // MARK: - Init

  public init(delegate: NFCManagerDelegate? = nil) {
    self.delegate = delegate
  }


  // MARK: - Public

  /// Sign a custom file with the DNIe and three phase sign
  func sign(delegate: NFCManagerDelegate?,
            can: String,
            pin: String,
            certAlias: String,
            data: Data,
            completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.can = can
    self.pin = pin
    self.certAlias = certAlias
    self.data = data
    self.option = .signData

    openSession { error in
      completion(error)
    }
  }

  func getDNICertificate(delegate: NFCManagerDelegate?,
                         can: String,
                         pin: String,
                         certAlias: String,
                         completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.can = can
    self.pin = pin
    self.certAlias = certAlias
    self.option = .getCertificate

    openSession { error in
      completion(error)
    }
  }

  func probeCard(delegate: NFCManagerDelegate?,
                 completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.option = .probeCard

    openSession { error in
      completion(error)
    }
  }

  func verifyPinWithDnie(delegate: NFCManagerDelegate?,
                         can: String,
                         pin: String,
                         certAlias: String,
                         completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.can = can
    self.pin = pin
    self.certAlias = certAlias
    self.option = .verifyPin

    openSession { error in
      completion(error)
    }
  }

  func signPKCS1WithDnie(delegate: NFCManagerDelegate?,
                         can: String,
                         pin: String,
                         certAlias: String,
                         data: Data,
                         completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.can = can
    self.pin = pin
    self.certAlias = certAlias
    self.data = data
    self.option = .signDataWithPKCS1

    openSession { error in
      completion(error)
    }
  }

  func signDataWithDnie(delegate: NFCManagerDelegate?,
                         can: String,
                         pin: String,
                         certAlias: String,
                         data: Data,
                         completion: @escaping(_ error: NFCError?) -> Void) {
    self.delegate = delegate
    self.can = can
    self.pin = pin
    self.certAlias = certAlias
    self.data = data
    self.option = .signData

    openSession { error in
      completion(error)
    }
  }



}

// MARK: - Private

extension DefaultNFCManager {

  func notificationConfig() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sessionBegin(_:)),
                                           name: NSNotification.Name(NFCConstants.sessionBeginNotification),
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sessionInvalidate(_:)),
                                           name: NSNotification.Name(NFCConstants.sessionInvalidateNotification),
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(receiveAPDU(_:)),
                                           name: NSNotification.Name(NFCConstants.apduCommandNotification),
                                           object: nil)

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(readingDniInfo(_:)),
                                           name: NSNotification.Name(NFCConstants.dnieReadingNotification),
                                           object: nil)


  }

  func openSession(completion: @escaping(_ error: NFCError?) -> Void) {
    guard NFCTagReaderSession.readingAvailable else {
      completion(.notAvailable)
      return
    }

    if #available(iOS 15.0, *) {
      notificationConfig()
      self.dnieManager = DNIeCardOperations()
      session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: DispatchQueue.global())
      session?.alertMessage = "Acerca el iPhone... con cuidado..."
      session?.begin()

      completion(nil)
    } else {
      NFCLogger.default.devLog(.error, "openSession: error: this device doesn't support tag scanning for iOS version")
      completion(.notAvailableForOSVersion)
    }
  }
}

// MARK: - Private helper functions

extension DefaultNFCManager {

  func getDNIeCertificate() {
    guard let dnieManager, let can, let pin, let certAlias else {
      return
    }

    dnieManager.getCertificate(can: can, pin: pin, certAlias: certAlias) { [weak self] certB64, nfcError in
      guard let self else { return }
      if let nfcError {
        self.closeSessionWithOptionalError(nfcError.description())
        self.delegate?.nfcManagerExceptionError(nfcError, badPinTries: nil)
      } else {
        self.session?.alertMessage = "Proceso finalizado correcto!"
        self.closeSessionWithOptionalError(nil)
        self.delegate?.nfcManagerGetCertificate(certB64, nil)
      }
    }
  }

  func signPKCS1withDNIe(handler: @escaping (DniResult) -> Void) {
    guard let dnieManager, let can, let pin, let certAlias else {
      return
    }

    dnieManager.signPKCS1(can: can, pin: pin, certAlias: certAlias, data: data) { [weak self] pkcs1Signed, certBase64, nfcError in
      guard let self else { return }
      if let nfcError {
        self.closeSessionWithOptionalError(nfcError.description())
        self.delegate?.nfcManagerExceptionError(nfcError, badPinTries: nil)
      } else {
        self.session?.alertMessage = "Proceso finalizado correcto!"
        self.closeSessionWithOptionalError(nil)
        guard let pkcs1signedData = pkcs1Signed?.base64Decode(),
              let certBase64,
              let pkcs1Signed else {
          return
        }
        handler(.init(
            dataSignedString: pkcs1Signed,
            dataSigned: pkcs1signedData,
            certificate: certBase64
        ))
      }
    }
  }

  func signDataWithDnie(completion: @escaping (String?) -> Void) {
    guard let dnieManager, let can, let pin, let certAlias else {
      return
    }

    dnieManager.signData(
        can: can,
        pin: pin,
        certAlias: certAlias,
        signatureAlgorithm: SignatureAlgorithm.sha512withRSA.rawValue,
        signatureFormat: SignatureFormat.xades.rawValue,
        data: data
    ) { [weak self] response, nfcError in
      guard let self else { return }
      if let nfcError {
        self.closeSessionWithOptionalError(nfcError.description())
        self.delegate?.nfcManagerExceptionError(nfcError, badPinTries: nil)
      } else {
        self.session?.alertMessage = "Proceso finalizado correcto!"
        self.closeSessionWithOptionalError(nil)
        completion(response)
      }
    }
  }


  /// When we receive the DNIe tag we do not receive the complete Answer To Response (ATR), so to validate if it is a
  /// DNIe we create one as long as the data received from the DNIe is within a validation ATR that we have previously.
  /// - Parameter sessionTag: session tag
  /// - Returns: We return a previously set ATR if the data received from the DNIe communication is included in our own,
  /// otherwise we return nil.
  func createFakeATR(for sessionTag: NFCISO7816Tag) -> [Int]? {
    var hex: String?
    if let historicalBytes = sessionTag.historicalBytes {
      NFCLogger.default.devLog(.info,
                               "sessionTag: historicalBytes: \(historicalBytes.hexEncodedString(options: .upperCase))")

      hex = historicalBytes.hexEncodedString(options: .upperCase)
    } else if let applicationData = sessionTag.applicationData {
      NFCLogger.default.devLog(.info,
                               "sessionTag: applicationData: \(applicationData.hexEncodedString(options: .upperCase))")

      hex = applicationData.hexEncodedString(options: .upperCase)
    }

    guard let hex, hex == NFCConstants.atrCheck else {
      NFCLogger.default.devLog(.error, "createFakeATR: sessionTag: error")

      return nil
    }

    return NFCConstants.atrFake
  }

  /// Create nfc error for jmulticard exception
  /// - Parameter error: error
  /// - Returns: NFCError type
  func createNFCErrorForException(_ error: NSError) -> NFCError {
    var nfcError: NFCError
    switch error.domain {
    case "EsGobJmulticardCardBadPinException":
      let retries = DefaultNFCManager.parseRetriesFromError(error)
      nfcError = .badPin(retries: retries)
    case "EsGobJmulticardCardInvalidCanOrMrzException":
      nfcError = .invalidCAnOrMrz
    case "EsGobJmulticardCardBurnedDnieCardException":
      nfcError = .burnedDNIeCard
    case "EsGobJmulticardCardInvalidCardException":
      nfcError = .invalidCard
    case "EsGobJmulticardCardAuthenticationModeLockedException":
      nfcError = .authenticationModeLocked
    case "UnderAgeException":
      nfcError = .underAge
    case "CardExpiredException":
      nfcError = .cardExpired
    case "CertExpiredException":
      nfcError = .certExpired
    case "DefectiveCardException":
      nfcError = .defectiveCard

    default:
      nfcError = .generic
    }
    return nfcError
  }

  /// Parses PIN retry count from NSError description or reason.
  static func parseRetriesFromError(_ error: NSError) -> Int {
    let description = error.localizedDescription
    if let match = description.range(of: #"\d+"#, options: .regularExpression) {
      return Int(description[match]) ?? -1
    }
    if let reason = error.userInfo["reason"] as? String,
       let match = reason.range(of: #"\d+"#, options: .regularExpression) {
      return Int(reason[match]) ?? -1
    }
    return -1
  }

  /// Delete user data.
  func emptyUserData() {
    can = nil
    pin = nil
    certAlias = nil
    data = nil
  }
}
