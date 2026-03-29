//
//  NFCUserDNIeEntities.swift
//
//  Created by Arturo Carretero Calvo on 30/1/23.
//  Copyright © 2023 Accenture. All rights reserved.
//

import Foundation
import UIKit.UIImage

public struct NFCUserDNIeEntity {
  let name: String
  let firstSurname: String
  let secondSurname: String
  let document: String
  let address: AddressData?
  let dataSigned: String?

  static func getUserData(with dict: [AnyHashable: Any]?) -> NFCUserDNIeEntity? {
    guard let data = dict as? [String: Any] else {
      return nil
    }

    guard let name = data["name"] as? String,
          let nif = data["nif"] as? String,
          let lastname = data["lastname"] as? String,
          let secondLastName = data["secondLastName"] as? String,
          let dataSigned = data["dataSigned"] as? String else {
      return nil
    }

    guard let address = AddressData.fromDictionary(dict: data) else {
      return nil
    }

    return NFCUserDNIeEntity(name: name,
                             firstSurname: lastname,
                             secondSurname: secondLastName,
                             document: nif,
                             address:  address,
                             dataSigned: dataSigned)
  }
}

public struct NFCUserDNIeInfoEntity: Codable {
  static let DATE_FORMAT = "dd MM yyyy"

  let name: String
  let firstSurname: String
  let secondSurname: String
  let document: String
  let address: String
  let city: String
  let province: String
  let country: String
  let expirationDate: SimpleDate
  let gender: String
  let idespBNC: String
  let idespLines: MRZLines
  let parentsNames: String
  let birthDate: SimpleDate
  let birthCountry: String
  let birthCity: String
  let birthProvince: String
  let signatureImage: Data?
  let profileImage: Data?

  static func getUserDNIDataInfo(with dict: [AnyHashable: Any]?) -> NFCUserDNIeInfoEntity? {
    guard let data = dict as? [String: Any] else {
      return nil
    }

    let name = data["name"] as? String ?? "-"
    let nif = data["nif"] as? String ?? "-"
    let lastname = data["lastname"] as? String ?? "-"
    let secondLastName = data["secondLastName"] as? String ?? "-"
    let address = data["address"] as? String ?? "-"
    let city = data["city"] as? String ?? "-"
    let province = data["province"] as? String ?? "-"
    let country = data["country"] as? String ?? "-"
    let expirationDate = data["expirationDate"] as? String
    let gender = data["gender"] as? String ?? "-"
    let idespBNC = data["idespBNC"] as? String ?? "-"
    let idespLines = (data["idespLines"] as? String)?
      .idespSlice() ??
      .empty
    let parentsNames = data["parentsNames"] as? String ?? "-"
    let birthDate = data["birthDate"] as? String
    let birthCountry = data["birthCountry"] as? String ?? "-"
    let birthCity = data["birthCity"] as? String ?? "-"
    let birthProvince = data["birthProvince"] as? String ?? "-"
    let signatureImage = data["signatureImage"] as? Data
    let profileImage = data["profileImage"] as? Data

    return NFCUserDNIeInfoEntity(
      name: name,
      firstSurname: lastname,
      secondSurname: secondLastName,
      document: nif,
      address: address,
      city: city,
      province: province,
      country: country,
      expirationDate: expirationDate?
        .asDate(withFormat: Self.DATE_FORMAT)?
        .toSimpleDate() ??
        .init(year: 0, month: 0, day: 0),
      gender: gender,
      idespBNC: idespBNC,
      idespLines: idespLines,
      parentsNames: parentsNames,
      birthDate: birthDate?
        .asDate(withFormat: Self.DATE_FORMAT)?
        .toSimpleDate() ??
        .init(year: 0, month: 0, day: 0),
      birthCountry: birthCountry,
      birthCity: birthCity,
      birthProvince: birthProvince,
      signatureImage: signatureImage,
      profileImage: profileImage
    )
  }
}

struct MRZLines: Codable {
  static let empty = MRZLines(line0: "-", line1: "-", line2: "-")

  var line0: String
  var line1: String
  var line2: String
}

struct AddressData {
  let addressText: String
  let floorText: String
  let zipText: String
  let cityText: String
  let provinceText: String
  let countryText: String
  
  func asDictionary() -> [AnyHashable: Any] {
    ["addressText": addressText,
     "floorText": floorText,
     "zipText": zipText,
     "cityText": cityText,
     "provinceText": provinceText,
     "countryText": countryText]
  }
  
  public static func fromDictionary(dict: [AnyHashable: Any]?) -> AddressData? {
    guard let data = dict as? [String: Any] else {
      return nil
    }
    
    guard let address = data["address"] as? String,
          let city = data["city"] as? String,
          let province = data["province"] as? String,
          let country = data["country"] as? String,
          let zipCode = data["zipCode"] as? String else {
      return nil
    }
    
    return .init(addressText: address,
                 floorText: "",
                 zipText: zipCode,
                 cityText: city,
                 provinceText: province,
                 countryText: country)
  }
}

extension AddressData {
  func sanitized() -> AddressData {
    .init(addressText: addressText.asSanitizedAddress(),
          floorText: floorText.asSanitizedFloor(),
          zipText: zipText.asSanitizedZip(),
          cityText: cityText.asSanitizedCity(),
          provinceText: provinceText.asSanitizedProvince(),
          countryText: countryText.asSanitizedCountry())
  }
}

enum CertificateRequestType: Codable {
  case citizen
  case publicEmployee
  case representative
  
  func description() -> String {
    switch self {
    case .citizen:
      return "citizen"
    case .publicEmployee:
      return "publicEmployee"
    case .representative:
      return "representative"
    }
  }
}

