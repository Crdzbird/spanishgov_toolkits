package es.gob.electronic_dnie.utils

import es.gob.jmulticard.card.AuthenticationModeLockedException
import es.gob.jmulticard.card.BadPinException
import es.gob.jmulticard.card.InvalidCardException
import es.gob.jmulticard.card.dnie.BurnedDnieCardException
import es.gob.jmulticard.card.icao.InvalidCanOrMrzException

open class DNIeSignerException(error: String) : Throwable(error)

class DSTimeoutException :
    DNIeSignerException(
        "DNIe card detection timeout. The expected card wasn't detected within the specified time."
    )

class DSCardTagException :
    DNIeSignerException("Could not get NFC Tag from the detected card. Scan stopped!")

class DSDNIeProviderException : DNIeSignerException("Failed to create DNIe provider.")

class DSUnderageDocumentException :
    DNIeSignerException(
        "The document belongs to an underage user and it does not have signing capabilities."
    )

class DSExpiredCertificateException :
    DNIeSignerException("The detected document has its certificate expired.")

class DSDNIeConnectionException : DNIeSignerException("Failed to read DNIe data.")

class DSPrivateKeyException : DNIeSignerException("Failed to get private key from DNIe document.")
class DSSigningException : DNIeSignerException("Failed to sign data!")

class DSUnknownException(val code: Int) : DNIeSignerException("Unknown exception with code: $code")

class DSDNIeWrongPINException(val remainingRetries: Int) :
    DNIeSignerException("DNIe wrong PIN. Retries remaining: $remainingRetries")

class DSDNIeWrongCANException : DNIeSignerException("DNIe wrong CAN!")
class DSDNIeLockedPINException : DNIeSignerException("DNIe locked. Too many wrong PIN tries.")
class DSNotDNIeException : DNIeSignerException("Detected document is not a DNIe.")
class DSDNIeDamagedException : DNIeSignerException("DNIe burned or damaged.")

fun Throwable.toFNMTException(defaultException: Throwable): Throwable =
    parseCause(this, defaultException, Cause.FIRST)

private fun parseCause(throwable: Throwable, defaultException: Throwable, cause: Cause): Throwable {
    return when (throwable) {
        is BadPinException -> DSDNIeWrongPINException(throwable.remainingRetries)
        is InvalidCanOrMrzException -> DSDNIeWrongCANException()
        is BurnedDnieCardException -> DSDNIeDamagedException()
        is InvalidCardException -> DSNotDNIeException()
        is AuthenticationModeLockedException -> DSDNIeLockedPINException()
        else -> when (cause) {
            Cause.FIRST -> throwable.cause?.let { parseCause(it, defaultException, Cause.SECOND) }
                ?: defaultException

            Cause.SECOND -> throwable.cause?.let { parseCause(it, defaultException, Cause.THIRD) }
                ?: defaultException

            Cause.THIRD -> defaultException
        }
    }
}

private enum class Cause() {
    FIRST, SECOND, THIRD
}
