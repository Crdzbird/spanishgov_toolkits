//
//  NFCEntities.swift
//
//  Created by Arturo Carretero Calvo on 3/1/23.
//  Copyright © 2023 Accenture. All rights reserved.
//

import Foundation

// MARK: - Entities

struct NFCCustomTextEntity {
  let nearText: String
  let readingText: String
  let readDataSuccess: String
  let signText: String
  let signDataSuccess: String
}

// MARK: - Enum

enum NFCManagerOption {
  case getCertificate
  case signDataWithPKCS1
  case signData
  case probeCard
  case verifyPin
}

// MARK: - Errors

public enum NFCError: Error {
  case iso7816Fail
  case notAvailable
  case notAvailableForOSVersion
  case noTag
  case noTagSession
  case tagSendCommandFail
  case badPin(retries: Int)
  case invalidCAnOrMrz
  case burnedDNIeCard
  case invalidCard
  case authenticationModeLocked
  case underAge
  case cardExpired
  case certExpired
  case noDataReaded
  case defectiveCard
  case requestalreadyExists
  case cryptoCardException
  case readTimeOut
  case userCancelledSession
  case generic
  
  func description() -> String {
    switch self {
    case .iso7816Fail:
      "iso7816Fail"
    case .notAvailable:
      "notAvailable"
    case .notAvailableForOSVersion:
      "notAvailableForOSVersion"
    case .noTag:
      "noTag"
    case .noTagSession:
      "noTagSession"
    case .tagSendCommandFail:
      "tagSendCommandFail"
    case .badPin:
      "badPin"  // associated value not needed for description key
    case .invalidCAnOrMrz:
      "invalidCAnOrMrz"
    case .burnedDNIeCard:
      "burnedDNIeCard"
    case .invalidCard:
      "invalidCard"
    case .authenticationModeLocked:
      "authenticationModeLocked"
    case .underAge:
      "underAge"
    case .cardExpired:
      "cardExpired"
    case .certExpired:
      "certExpired"
    case .noDataReaded:
      "noDataReaded"
    case .defectiveCard:
      "defectiveCard"
    case .cryptoCardException:
      "cryptoCardException"
    case .generic:
      "generic"
    case .readTimeOut:
      "readTimeOut"
    case .userCancelledSession:
      "userCancelledSession"
    case .requestalreadyExists:
      "requestalreadyExists"
    }
  }
}

enum NFCCommandError: String, Error {
  case invalidFile = "6283"
  case memoryFail = "6581"
  case incorrectLength = "6700"
  case securizationMessagesNotAvailable = "6882"
  case securityConditionsIncorrect = "6982"
  case authenticationBlocked = "6983"
  case dataReferenceInvalid = "6984"
  case useConditionsFail = "6985"
  case commandNotPermitted = "6986"
  case necessaryObjectNotPresent = "6987"
  case incorrectObjectsInMessage = "6988"
  case incorrectParams = "6A80"
  case functionNotAvailable = "6A81"
  case notFile = "6A82"
  case registryNotAvailable = "6A83"
  case insufficientMemoryInFile = "6A84"
  case incompatibleDataLength = "6A85"
  case incorrectParamsInP1OrP2 = "6A86"
  case dataLengthFailInP1P2 = "6A87"
  case dataNotAvailable = "6A88"
  case fileAlreadyExists = "6A89"
  case dfNameAlreadyExists = "6A8A"
  case incorrectParamsInP1P2 = "6B00"
  case notSupportedClass = "6E00"
  case commandNotPermittedInPhaseActual = "6D00"
  case diagnosisNotPrecise = "6F00"
  case generic
  case badPin
  case invalidCan
  case burnedDnie
  case invalidCard
  case authenticationModeLocked
  case timeout
  case sessionCancelledByUser
}

// For each error type return the appropriate description
extension NFCCommandError: CustomStringConvertible {
  
  public var description: String {
    switch self {
    case .invalidFile:
      return "El fichero seleccionado está invalidado (6283)"
    case .memoryFail:
      return "Fallo en la memoria (6581)"
    case .incorrectLength:
      return "Longitud incorrecta (6700)"
    case .securizationMessagesNotAvailable:
      return "Securizacion de mensajes no soportada (6882)"
    case .securityConditionsIncorrect:
      return "Condiciones de seguridad no satisfechas (6982)"
    case .authenticationBlocked:
      return "Metodo de autenticacion bloqueado (6983)"
    case .dataReferenceInvalid:
      return "Dato referenciado invalido (6984)"
    case .useConditionsFail:
      return "Condiciones de uso no satisfechas (6985)"
    case .commandNotPermitted:
      return "Comando no permitido [no existe ningun EF seleccionado] (6986)"
    case .necessaryObjectNotPresent:
      return "Falta un objeto necesario en el mensaje seguro (6987)"
    case .incorrectObjectsInMessage:
      return "Objetos de datos incorrectos para el mensaje seguro (6988)"
    case .incorrectParams:
      return "Parametros incorrectos en el campo de datos (6A80)"
    case .functionNotAvailable:
      return "Funcion no soportada (6A81)"
    case .notFile:
      return "No se encuentra el fichero (6A82)"
    case .registryNotAvailable:
      return "Registro no encontrado (6A83)";
    case .insufficientMemoryInFile:
      return "No hay suficiente espacio de memoria en el fichero (6A84)"
    case .incompatibleDataLength:
      return "La longitud de datos (Lc) es incompatible con la estructura TLV (6A85)"
    case .incorrectParamsInP1OrP2:
      return "Parametros incorrectos en P1 o P2 (6A86)"
    case .dataLengthFailInP1P2:
      return "La longitud de los datos es inconsistente con P1-P2 (6A87)"
    case .dataNotAvailable:
      return "Datos referenciados no encontrados (6A88)"
    case .fileAlreadyExists:
      return "El fichero ya existe (6A89)"
    case .dfNameAlreadyExists:
      return "El nombre del DF ya existe (6A8A)"
    case .incorrectParamsInP1P2:
      return "Parametro(s) incorrecto(s) P1-P2 (6B00)"
    case .notSupportedClass:
      return "Clase no soportada (6E00)"
    case .commandNotPermittedInPhaseActual:
      return "Comando no permitido en la fase de vida actual (6D00)"
    case .diagnosisNotPrecise:
      return "Diagnostico no preciso (6F00)"
    case .generic:
      return "Ha ocurrido un error..."
    case .badPin:
      return "El pin introducido no es correcto. Te quedan %@ intentos"
    case .invalidCan:
      return "El CAN introducido no es correcto"
    case .burnedDnie:
      return "Tu DNIe no es válido"
    case .invalidCard:
      return "Tu DNIe no es válido"
    case .authenticationModeLocked:
      return "Tu DNIe está bloqueado"
    case .timeout:
      return "Tiempo de espera superado"
    case .sessionCancelledByUser:
      return "Sesión cancelada por el usuarios"
    }
  }
}

// For each error type return the appropriate localized description
extension NFCCommandError: LocalizedError {
  
  public var errorDescription: String? {
    switch self {
    case .invalidFile:
      return "El fichero seleccionado está invalidado (6283)"
    case .memoryFail:
      return "Fallo en la memoria (6581)"
    case .incorrectLength:
      return "Longitud incorrecta (6700)"
    case .securizationMessagesNotAvailable:
      return "Securizacion de mensajes no soportada (6882)"
    case .securityConditionsIncorrect:
      return "Condiciones de seguridad no satisfechas (6982)"
    case .authenticationBlocked:
      return "Metodo de autenticacion bloqueado (6983)"
    case .dataReferenceInvalid:
      return "Dato referenciado invalido (6984)"
    case .useConditionsFail:
      return "Condiciones de uso no satisfechas (6985)"
    case .commandNotPermitted:
      return "Comando no permitido [no existe ningun EF seleccionado] (6986)"
    case .necessaryObjectNotPresent:
      return "Falta un objeto necesario en el mensaje seguro (6987)"
    case .incorrectObjectsInMessage:
      return "Objetos de datos incorrectos para el mensaje seguro (6988)"
    case .incorrectParams:
      return "Parametros incorrectos en el campo de datos (6A80)"
    case .functionNotAvailable:
      return "Funcion no soportada (6A81)"
    case .notFile:
      return "No se encuentra el fichero (6A82)"
    case .registryNotAvailable:
      return "Registro no encontrado (6A83)";
    case .insufficientMemoryInFile:
      return "No hay suficiente espacio de memoria en el fichero (6A84)"
    case .incompatibleDataLength:
      return "La longitud de datos (Lc) es incompatible con la estructura TLV (6A85)"
    case .incorrectParamsInP1OrP2:
      return "Parametros incorrectos en P1 o P2 (6A86)"
    case .dataLengthFailInP1P2:
      return "La longitud de los datos es inconsistente con P1-P2 (6A87)"
    case .dataNotAvailable:
      return "Datos referenciados no encontrados (6A88)"
    case .fileAlreadyExists:
      return "El fichero ya existe (6A89)"
    case .dfNameAlreadyExists:
      return "El nombre del DF ya existe (6A8A)"
    case .incorrectParamsInP1P2:
      return "Parametro(s) incorrecto(s) P1-P2 (6B00)"
    case .notSupportedClass:
      return "Clase no soportada (6E00)"
    case .commandNotPermittedInPhaseActual:
      return "Comando no permitido en la fase de vida actual (6D00)"
    case .diagnosisNotPrecise:
      return "Diagnostico no preciso (6F00)"
    case .generic:
      return "Ha ocurrido un error..."
    case .badPin:
      return "El pin introducido no es correcto. Te quedan %@ intentos"
    case .invalidCan:
      return "El CAN introducido no es correcto"
    case .burnedDnie:
      return "Tu DNIe no es válido"
    case .invalidCard:
      return "Tu DNIe no es válido"
    case .authenticationModeLocked:
      return "Tu DNIe está bloqueado"
    case .timeout:
      return "Tiempo de espera superado"
    case .sessionCancelledByUser:
      return "Sesión cancelada por el usuarios"
    }
  }
}
