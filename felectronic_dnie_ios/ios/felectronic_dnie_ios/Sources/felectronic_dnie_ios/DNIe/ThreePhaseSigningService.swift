import Foundation

/// Unified three-phase signing service (replaces DNIeThreePhase + CertificateThreePhase).
///
/// Handles the pre-sign and post-sign HTTP requests to the government
/// signing service, plus XML parsing helpers.
final class ThreePhaseSigningService {

    // MARK: - Constants

    static let defaultServiceURL = URL(
        string: "https://firmamovil-appfactory.redsara.es/afirma-server-triphase-signer/SignatureService"
    )!

    // MARK: - Properties

    let serviceURL: URL

    // MARK: - Init

    init(serviceURL: URL) {
        self.serviceURL = serviceURL
    }

    // MARK: - Pre-Sign

    func preSign(
        certBase64: String,
        docData: Data,
        signatureFormat: String,
        signatureAlgorithm: String,
        extraParams: String,
        completion: @escaping (String) -> Void
    ) {
        let docBase64 = EsGobAfirmaCoreMiscBase64.encode(
            with: IOSByteArray(nsData: docData),
            withBoolean: true
        ) ?? ""
        let extraParams64 = Data(extraParams.utf8)
            .base64EncodedString(options: [])

        let preParams = "op=pre&cop=sign&format=\(signatureFormat)"
            + "&algo=\(signatureAlgorithm)"
            + "&cert=\(certBase64)"
            + "&doc=\(docBase64)"
            + "&params=\(extraParams64)"

        var request = URLRequest(
            url: serviceURL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 10.0
        )
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = preParams.data(using: .utf8)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data else {
                NFCLogger.default.log(
                    type: .error,
                    "ThreePhaseSigningService: preSign error: \(error?.localizedDescription ?? "unknown")"
                )
                completion("")
                return
            }

            guard let responseBase64 = String(data: data, encoding: .utf8) else {
                completion("")
                return
            }

            let decoded = Self.base64StringFromBase64UrlEncoded(responseBase64)
            guard let responseData = EsGobAfirmaCoreMiscBase64.decode(
                with: decoded,
                withBoolean: false
            ) else {
                completion("")
                return
            }

            let xmlString = String(
                data: responseData.toNSData(),
                encoding: .utf8
            ) ?? ""
            completion(xmlString)
        }.resume()
    }

    // MARK: - Post-Sign

    func postSign(
        certBase64: String,
        docData: Data,
        xmlSession: String,
        signatureFormat: String,
        signatureAlgorithm: String,
        extraParams: String,
        completion: @escaping (String) -> Void
    ) {
        let docBase64 = EsGobAfirmaCoreMiscBase64.encode(
            with: IOSByteArray(nsData: docData),
            withBoolean: true
        ) ?? ""
        let extraParams64 = Data(extraParams.utf8)
            .base64EncodedString(options: [])

        let xmlData = xmlSession.data(using: .utf8) ?? Data()
        let xmlByteArray = IOSByteArray(nsData: xmlData)
        let xmlBase64 = EsGobAfirmaCoreMiscBase64.encode(
            with: xmlByteArray,
            withBoolean: true
        ) ?? ""

        let postParams = "op=post&cop=sign&format=\(signatureFormat)"
            + "&algo=\(signatureAlgorithm)"
            + "&cert=\(certBase64)"
            + "&doc=\(docBase64)"
            + "&session=\(xmlBase64)"
            + "&params=\(extraParams64)"

        var request = URLRequest(
            url: serviceURL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 10.0
        )
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = postParams.data(using: .utf8)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data else {
                NFCLogger.default.log(
                    type: .error,
                    "ThreePhaseSigningService: postSign error: \(error?.localizedDescription ?? "unknown")"
                )
                completion("")
                return
            }

            guard let responseString = String(data: data, encoding: .utf8) else {
                completion("")
                return
            }

            let decoded = Self.base64StringFromBase64UrlEncoded(responseString)
            let cleaned = decoded.replacingOccurrences(of: "OK NEWID=", with: "")
            completion(cleaned)
        }.resume()
    }

    // MARK: - XML Helpers

    static func xmlSigner(preResult: String) -> Data {
        guard let xml = XMLKit.parseXMLString(preResult) else {
            return Data()
        }

        for root in xml.children ?? [] {
            guard let root = root as? XMLElement else { continue }
            for element in root.children ?? [] {
                guard let element = element as? XMLElement else { continue }
                for param in element.children ?? [] {
                    guard let param = param as? XMLElement,
                          let attrValue = param.attributes?["n"] as? String,
                          attrValue == "PRE",
                          let preBase64 = param.text,
                          !preBase64.isEmpty
                    else { continue }
                    return preBase64.data(using: .utf8) ?? Data()
                }
            }
        }
        return Data()
    }

    static func addPKCS1ToXML(
        signedData: Data,
        xmlString: String
    ) -> String? {
        guard let xml = XMLKit.parseXMLString(xmlString) else {
            return nil
        }

        let pkcs1Base64 = signedData.base64EncodedString(options: [])

        for root in xml.children ?? [] {
            guard let root = root as? XMLElement else { continue }
            for element in root.children ?? [] {
                guard let element = element as? XMLElement else { continue }
                let pk1Attributes: [AnyHashable: Any] = ["n": "PK1"]
                if let pk1Element = XMLElement.element(
                    withName: "param",
                    attributes: pk1Attributes
                ) as? XMLElement {
                    pk1Element.text = pkcs1Base64
                    element.children?.add(pk1Element)
                }
            }
        }

        return xml.convertToString()
    }

    // MARK: - Base64 Helpers

    /// Converts base64url-encoded string to standard base64 with padding.
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
