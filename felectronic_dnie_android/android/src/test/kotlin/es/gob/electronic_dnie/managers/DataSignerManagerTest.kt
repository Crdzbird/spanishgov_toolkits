package es.gob.electronic_dnie.managers

import es.gob.electronic_dnie.utils.DSSigningException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.util.encoders.Base64
import org.bouncycastle.util.encoders.Hex
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.security.cert.X509Certificate
import java.util.Date

class DataSignerManagerTest {

    private val keyPair: KeyPair = KeyPairGenerator.getInstance("RSA")
        .apply { initialize(2048) }
        .generateKeyPair()

    private val certificate: X509Certificate = JcaX509CertificateConverter().getCertificate(
        JcaX509v3CertificateBuilder(
            X500Name("CN=TEST, SERIALNUMBER=IDCES-12345678Z"),
            BigInteger.ONE,
            Date(0),
            Date(4_102_444_800_000),
            X500Name("CN=TEST, SERIALNUMBER=IDCES-12345678Z"),
            keyPair.public
        ).build(JcaContentSignerBuilder("SHA256withRSA").build(keyPair.private))
    )

    private val keyEntry = KeyStore.PrivateKeyEntry(keyPair.private, arrayOf(certificate))

    private val challenge = "one-time server challenge".toByteArray()

    private fun sign(algorithm: String = DataSignerManager.DNIE_ALGORITHM) = runBlocking {
        DataSignerManager().signData(challenge, keyEntry, algorithm).first()
    }

    @Test
    fun `sign answers a raw PKCS1 v1_5 SHA-512 signature that verifies`() {
        val response = sign().getOrThrow()

        val verifier = Signature.getInstance("SHA512withRSA")
        verifier.initVerify(keyPair.public)
        verifier.update(challenge)
        assertTrue(verifier.verify(response.signedData))
        assertEquals(256, response.signedData.size)
    }

    @Test
    fun `the signature is EMSA-PKCS1-v1_5 over a SHA-512 DigestInfo`() {
        val signed = sign().getOrThrow().signedData
        val key = keyPair.public as RSAPublicKey

        val encoded = BigInteger(1, signed).modPow(key.publicExponent, key.modulus)
        val digestInfo = Hex.decode("3051300d060960864801650304020305000440") +
            MessageDigest.getInstance("SHA-512").digest(challenge)
        val padding = ByteArray(256 - 3 - digestInfo.size) { 0xFF.toByte() }
        val expected = byteArrayOf(0x00, 0x01) + padding + byteArrayOf(0x00) + digestInfo

        assertEquals(BigInteger(1, expected), encoded)
    }

    @Test
    fun `base64 fields are standard Base64 on one line`() {
        val response = sign().getOrThrow()

        assertEquals(Base64.toBase64String(response.signedData), response.base64signedData)
        assertArrayEquals(certificate.encoded, Base64.decode(response.base64certificate))
        assertFalse(response.base64certificate.contains('\n'))
        assertFalse(response.base64certificate.contains('-'))
        assertFalse(response.base64certificate.contains('_'))
    }

    @Test
    fun `an unknown algorithm fails as a signing error`() {
        assertTrue(sign("MD5RSA").exceptionOrNull() is DSSigningException)
    }
}
