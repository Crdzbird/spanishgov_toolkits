package es.gob.electronic_dnie.utils

import es.gob.jmulticard.card.AuthenticationModeLockedException
import es.gob.jmulticard.card.BadPinException
import es.gob.jmulticard.card.InvalidCardException
import es.gob.jmulticard.card.icao.InvalidCanOrMrzException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.ProviderException
import java.security.SignatureException

class ExceptionMappingTest {

    private fun map(cause: Throwable): Throwable =
        SignatureException(ProviderException(cause)).toFNMTException(DSSigningException())

    @Test
    fun `a wrong PIN raised while signing keeps the tries left`() {
        val mapped = map(BadPinException(2))
        assertTrue(mapped is DSDNIeWrongPINException)
        assertEquals(2, (mapped as DSDNIeWrongPINException).remainingRetries)
        assertEquals("DNIe wrong PIN. Retries remaining: 2", mapped.message)
    }

    @Test
    fun `card failures map to the exceptions Dart knows`() {
        assertTrue(map(InvalidCanOrMrzException("can")) is DSDNIeWrongCANException)
        assertTrue(map(AuthenticationModeLockedException()) is DSDNIeLockedPINException)
        assertTrue(map(InvalidCardException("card")) is DSNotDNIeException)
    }

    @Test
    fun `anything else is a signing error`() {
        assertTrue(map(IllegalStateException()) is DSSigningException)
    }

    @Test
    fun `wire codes are the class names Dart maps`() {
        assertEquals("DSNfcUnavailableException", DSNfcUnavailableException()::class.java.simpleName)
        assertEquals("DSDNIeWrongPINException", DSDNIeWrongPINException(1)::class.java.simpleName)
    }
}
