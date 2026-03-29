import Foundation

@objc public class SignManager: NSObject {

    private var nfcManager: DefaultNFCManager!
    private var pin: String!
    private var can: String!
    private weak var delegate: ElectronicDnieDelegate?

    // MARK: - Public

    public func signPKCS1WithDNI(
        delegate: ElectronicDnieDelegate,
        can: String,
        pin: String,
        certAlias: String,
        document: Data
    ) {
        self.can = can
        self.pin = pin
        self.delegate = delegate
        nfcManager = DefaultNFCManager()
        nfcManager.pin = pin
        nfcManager.can = can
        nfcManager.certAlias = certAlias
        nfcManager.data = document

        nfcManager.signPKCS1WithDnie(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: certAlias,
            data: document
        ) { error in
            if let error {
                NFCLogger.default.log(
                    type: .error,
                    "SignManager PKCS1 error: \(error)"
                )
            }
        }
    }

    public func signDataWithDNIe(
        can: String,
        pin: String,
        certAlias: String,
        document: Data,
        completion: @escaping (Data?) -> Void
    ) {
        self.can = can
        self.pin = pin
        nfcManager = DefaultNFCManager()
        nfcManager.pin = pin
        nfcManager.can = can
        nfcManager.certAlias = certAlias
        nfcManager.data = document

        nfcManager.signDataWithDnie(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: certAlias,
            data: document
        ) { error in
            NFCLogger.default.log(
                type: .error,
                "SignManager data sign error: \(error)"
            )
        }
    }

    public func probeDNIeCard(
        delegate: ElectronicDnieDelegate
    ) {
        self.delegate = delegate
        nfcManager = DefaultNFCManager()
        nfcManager.probeCard(delegate: self) { error in
            if let error {
                NFCLogger.default.log(
                    type: .error,
                    "SignManager probe error: \(error)"
                )
            }
        }
    }

    public func verifyDNIePin(
        delegate: ElectronicDnieDelegate,
        can: String,
        pin: String,
        certAlias: String
    ) {
        self.can = can
        self.pin = pin
        self.delegate = delegate
        nfcManager = DefaultNFCManager()
        nfcManager.verifyPinWithDnie(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: certAlias
        ) { error in
            if let error {
                NFCLogger.default.log(
                    type: .error,
                    "SignManager verify PIN error: \(error)"
                )
            }
        }
    }

    public func getDNIeCertificate(
        delegate: ElectronicDnieDelegate,
        can: String,
        pin: String,
        certAlias: String
    ) {
        self.can = can
        self.pin = pin
        self.delegate = delegate
        nfcManager = DefaultNFCManager()

        nfcManager.getDNICertificate(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: certAlias
        ) { error in
            if let error {
                NFCLogger.default.log(
                    type: .error,
                    "SignManager certificate error: \(error)"
                )
            }
        }
    }
}

extension SignManager: NFCManagerDelegate {
    func nfcManagerGetCertificate(_ certB64: String?, _ error: NFCError?) {
        if let error {
            delegate?.dnieError(error: error)
            return
        }
        if let certB64 {
            delegate?.dnieCertificateResult(certificate: certB64)
        }
    }

    func nfcManagerSignPKCS1(_ result: DniResult?) {
        guard let result else { return }
        delegate?.dnieReadingResult(result: result)
    }

    func nfcManagerProbeResult(_ isValidDnie: Bool, _ atrHex: String, _ tagId: String) {
        delegate?.dnieProbeResult(isValidDnie: isValidDnie, atrHex: atrHex, tagId: tagId)
    }
}
