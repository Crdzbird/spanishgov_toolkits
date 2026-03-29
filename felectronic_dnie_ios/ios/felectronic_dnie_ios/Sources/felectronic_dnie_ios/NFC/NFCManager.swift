//
//  NFCManager.swift
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023. All rights reserved.
//

import Foundation

protocol NFCManager: AnyObject {
  
  func sign(delegate: NFCManagerDelegate?,
            can: String,
            pin: String,
            data: Data,
            completion: @escaping(_ error: NFCError?) -> Void)

func signPKCS1WithDnie(delegate: NFCManagerDelegate?,
                       can: String,
                       pin: String,
                       data: Data,
                       completion: @escaping(_ error: NFCError?) -> Void)
}

protocol NFCManagerDelegate: AnyObject {
  func nfcManagerDidInvalidateWith(_ error: NFCCommandError)
  func nfcManagerTagReaderSessionError(_ error: NFCError)
  func nfcManagerExceptionError(_ error: NFCError, badPinTries: String?)
  func nfcManagerReadResponse(_ userData: NFCUserDNIeEntity?, _ error: NFCError?)
  func nfcManagerReadResponseRaw(_ response: String?, _ error: NFCError?)
  func nfcManagerGetCertificate(_ certB64: String?, _ error: NFCError?)
  func nfcManagerSignPKCS1(_ result: DniResult?)
  func nfcManagerReadDniInfoResponse(_ userData: NFCUserDNIeInfoEntity?, _ error: NFCError?)
  func nfcManagerProbeResult(_ isValidDnie: Bool, _ atrHex: String, _ tagId: String)
}

extension NFCManagerDelegate {
  func nfcManagerDidInvalidateWith(_ error: NFCCommandError) {}
  func nfcManagerTagReaderSessionError(_ error: NFCError) {}
  func nfcManagerExceptionError(_ error: NFCError, badPinTries: String?) {}
  func nfcManagerReadResponse(_ userData: NFCUserDNIeEntity?, _ error: NFCError?) {}
  func nfcManagerReadResponseRaw(_ response: String?, _ error: NFCError?) {}
  func nfcManagerGetCertificate(_ certB64: String?, _ error: NFCError?) {}
  func nfcManagerSignPKCS1(_ result: DniResult?) {}
  func nfcManagerReadDniInfoResponse(_ userData: NFCUserDNIeInfoEntity?, _ error: NFCError?) {}
  func nfcManagerProbeResult(_ isValidDnie: Bool, _ atrHex: String, _ tagId: String) {}
}
