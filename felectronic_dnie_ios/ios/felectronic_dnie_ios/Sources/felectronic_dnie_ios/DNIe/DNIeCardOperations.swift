import Foundation

/// Swift replacement for DNIeManager (Objective-C).
///
/// Wraps J2ObjC jmulticard calls using `DNIeExceptionCatcher`
/// to safely handle NSExceptions from the transpiled Java code.
final class DNIeCardOperations: NSObject {

    // MARK: - Properties

    var apduConnection: CustomApduConnection?

    // MARK: - Public

    func setTagSendCommandResponse(_ data: Data) {
        apduConnection?.setTagSendCommandResponse(data)
    }

    func getCertificate(
        can: String,
        pin: String,
        certAlias: String,
        completion: @escaping (String?, NFCError?) -> Void
    ) {
        DispatchQueue.global(qos: .default).async { [self] in
            var error: NSError?
            var certBase64Result: String?

            let success = DNIeExceptionCatcher.tryBlock({
                self.apduConnection = CustomApduConnection()
                let cryptHelper = EsGobJmulticardCryptoBcCryptoHelper()
                let callbackHandler = CustomDnieCallbackHandler(nsString: can, with: pin)

                let dnieFactory = EsGobJmulticardCardDnieDnieFactory.getDnieNfc(
                    withEsGobJmulticardConnectionApduConnection: self.apduConnection,
                    with: cryptHelper,
                    withJavaxSecurityAuthCallbackCallbackHandler: callbackHandler
                )

                let j509cert = dnieFactory?.getCertificate(
                    with: certAlias
                )
                let securityCert = j509cert as? JavaSecurityCertCertificate

                certBase64Result = EsGobAfirmaCoreMiscBase64.encode(
                    with: securityCert?.getEncoded(),
                    withBoolean: true
                )
            }, error: &error)

            if success, let cert = certBase64Result {
                completion(cert, nil)
            } else if let error {
                let nfcError = self.createNFCError(from: error)
                DispatchQueue.main.async {
                    completion(nil, nfcError)
                }
            }
        }
    }

    func signPKCS1(
        can: String,
        pin: String,
        certAlias: String,
        data: Data?,
        completion: @escaping (String?, String?, NFCError?) -> Void
    ) {
        DispatchQueue.global(qos: .default).async { [self] in
            var error: NSError?
            var pkcs1Base64Result: String?
            var certBase64Result: String?

            let success = DNIeExceptionCatcher.tryBlock({
                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Creando el conector ADPU"]
                )

                self.apduConnection = CustomApduConnection()
                let cryptHelper = EsGobJmulticardCryptoBcCryptoHelper()

                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Creando el callback handler..."]
                )

                let callbackHandler = CustomDnieCallbackHandler(nsString: can, with: pin)

                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Creando la entidad de DNI..."]
                )

                let dnieFactory = EsGobJmulticardCardDnieDnieFactory.getDnieNfc(
                    withEsGobJmulticardConnectionApduConnection: self.apduConnection,
                    with: cryptHelper,
                    withJavaxSecurityAuthCallbackCallbackHandler: callbackHandler
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Obteniendo el certificado..."]
                )

                let j509cert = dnieFactory?.getCertificate(
                    with: certAlias
                )
                let securityCert = j509cert as? JavaSecurityCertCertificate

                certBase64Result = EsGobAfirmaCoreMiscBase64.encode(
                    with: securityCert?.getEncoded(),
                    withBoolean: true
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Leyendo la clave privada..."]
                )

                let privateKey = dnieFactory?.getPrivateKey(
                    with: certAlias
                )

                let dataByte = IOSByteArray(nsData: data)

                NotificationCenter.default.post(
                    name: NSNotification.Name("dni.info"),
                    object: nil,
                    userInfo: ["message": "Firma de datos para la Pre firma..."]
                )

                let pkSign = dnieFactory?.sign(
                    with: dataByte,
                    with: "SHA512withRSA",
                    withEsGobJmulticardCardPrivateKeyReference: privateKey
                )

                pkcs1Base64Result = pkSign?.toNSData()
                    .base64EncodedString(options: [])
            }, error: &error)

            if success,
               let pkcs1 = pkcs1Base64Result,
               let cert = certBase64Result {
                completion(pkcs1, cert, nil)
            } else if let error {
                let nfcError = self.createNFCError(from: error)
                DispatchQueue.main.async {
                    completion(nil, nil, nfcError)
                }
            }
        }
    }

    func signData(
        can: String,
        pin: String,
        certAlias: String,
        signatureAlgorithm: String,
        signatureFormat: String,
        data: Data?,
        completion: @escaping (String?, NFCError?) -> Void
    ) {
        DispatchQueue.global(qos: .default).async { [self] in
            var error: NSError?

            let success = DNIeExceptionCatcher.tryBlock({
                self.apduConnection = CustomApduConnection()
                let cryptoHelper = EsGobJmulticardCryptoBcCryptoHelper()
                let callbackHandler = CustomDnieCallbackHandler(nsString: can, with: pin)

                let dnie = EsGobJmulticardCardDnieDnieFactory.getDnie(
                    withEsGobJmulticardConnectionApduConnection: self.apduConnection,
                    withJavaxSecurityAuthCallbackPasswordCallback: nil,
                    with: cryptoHelper,
                    withJavaxSecurityAuthCallbackCallbackHandler: callbackHandler,
                    withBoolean: true
                )

                let certificate = dnie?.getCertificate(
                    with: certAlias
                )
                let cert = certificate as? JavaSecurityCertCertificate

                let certBase64 = EsGobAfirmaCoreMiscBase64.encode(
                    with: cert?.getEncoded(),
                    withBoolean: true
                )

                guard let certBase64 else { return }

                let normalizedCert = Self.base64StringFromBase64UrlEncoded(certBase64)

                let threePhaseService = ThreePhaseSigningService(
                    serviceURL: ThreePhaseSigningService.defaultServiceURL
                )

                threePhaseService.preSign(
                    certBase64: normalizedCert,
                    docData: data ?? Data(),
                    signatureFormat: signatureFormat,
                    signatureAlgorithm: signatureAlgorithm,
                    extraParams: "mode=implicit"
                ) { preSignXml in
                    guard !preSignXml.isEmpty else {
                        DispatchQueue.main.async {
                            completion(nil, .generic)
                        }
                        return
                    }

                    let preDataSigned = ThreePhaseSigningService.xmlSigner(
                        preResult: preSignXml
                    )
                    let preDataBase64 = IOSByteArray(nsData: preDataSigned)
                    let preData = EsGobAfirmaCoreMiscBase64.decode(
                        with: preDataBase64,
                        with: 0,
                        with: preDataBase64?.length() ?? 0,
                        withBoolean: false
                    )

                    dnie?.openSecureChannelIfNotAlreadyOpened(withBoolean: true)

                    let pke = dnie?.getPrivateKey(
                        with: certAlias
                    )

                    let pkcs1 = dnie?.sign(
                        with: preData,
                        with: signatureAlgorithm,
                        withEsGobJmulticardCardPrivateKeyReference: pke
                    )

                    let xmlWithPkcs1 = ThreePhaseSigningService.addPKCS1ToXML(
                        signedData: pkcs1?.toNSData() ?? Data(),
                        xmlString: preSignXml
                    )

                    guard let xmlWithPkcs1 else {
                        DispatchQueue.main.async {
                            completion(nil, .generic)
                        }
                        return
                    }

                    threePhaseService.postSign(
                        certBase64: normalizedCert,
                        docData: data ?? Data(),
                        xmlSession: xmlWithPkcs1,
                        signatureFormat: signatureFormat,
                        signatureAlgorithm: signatureAlgorithm,
                        extraParams: "mode=implicit"
                    ) { response in
                        DispatchQueue.main.async {
                            if response.isEmpty {
                                completion(nil, .generic)
                            } else {
                                completion(response, nil)
                            }
                        }
                    }
                }
            }, error: &error)

            if !success, let error {
                let nfcError = self.createNFCError(from: error)
                DispatchQueue.main.async {
                    completion(nil, nfcError)
                }
            }
        }
    }

    // MARK: - Private

    private func createNFCError(from error: NSError) -> NFCError {
        switch error.domain {
        case "EsGobJmulticardCardBadPinException":
            let retries = Self.parseRetries(from: error)
            return .badPin(retries: retries)
        case "EsGobJmulticardCardIcaoInvalidCanOrMrzException":
            return .invalidCAnOrMrz
        case "EsGobJmulticardCardDnieBurnedDnieCardException":
            return .burnedDNIeCard
        case "EsGobJmulticardCardInvalidCardException":
            return .invalidCard
        case "EsGobJmulticardCardAuthenticationModeLockedException":
            return .authenticationModeLocked
        case "UnderAgeException":
            return .underAge
        case "CardExpiredException":
            return .cardExpired
        case "CertExpiredException":
            return .certExpired
        case "DefectiveCardException":
            return .defectiveCard
        default:
            return .generic
        }
    }

    /// Extracts PIN retry count from a jmulticard BadPinException NSError.
    private static func parseRetries(from error: NSError) -> Int {
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

    /// Converts base64url-encoded string to standard base64.
    static func base64StringFromBase64UrlEncoded(_ base64UrlEncoded: String) -> String {
        var s = base64UrlEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        switch s.count % 4 {
        case 2: s += "=="
        case 3: s += "="
        default: break
        }
        return s
    }
}
