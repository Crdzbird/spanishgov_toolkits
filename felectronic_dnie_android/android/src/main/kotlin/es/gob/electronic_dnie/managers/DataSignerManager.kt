package es.gob.electronic_dnie.managers

import es.gob.electronic_dnie.model.DniSignerResponse
import es.gob.electronic_dnie.utils.DSSigningException
import es.gob.electronic_dnie.utils.toFNMTException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import org.bouncycastle.util.encoders.Base64
import java.security.KeyStore
import java.security.Signature

private val algorithms = listOf(
    Pair("SHA1RSA", "SHA1withRSA"),
    Pair("SHA256RSA", "SHA256withRSA"),
    Pair("SHA384RSA", "SHA384withRSA"),
    Pair("SHA512RSA", "SHA512withRSA"),
    Pair("SHA256EC", "SHA256withECDSA"),
    Pair("SHA384EC", "SHA384withECDSA"),
    Pair("SHA512EC", "SHA512withECDSA")
)

/**
 * Signs on the device with a private key, the DNIe's included, so the data
 * never leaves the phone.
 *
 * The answer carries the raw signature (PKCS#1 v1.5 for the RSA algorithms),
 * its standard Base64 and the certificate DER as standard Base64, neither
 * with line breaks.
 */
class DataSignerManager {
    suspend fun signData(
        data: ByteArray,
        keyEntry: KeyStore.PrivateKeyEntry,
        algKey: String
    ): Flow<Result<DniSignerResponse>> = flow {
        emit(signDataWithPrivateKey(data = data, keyEntry = keyEntry, algKey = algKey))
    }

    fun signDataWithPrivateKey(
        data: ByteArray,
        keyEntry: KeyStore.PrivateKeyEntry,
        algKey: String
    ): Result<DniSignerResponse> {
        return try {
            val signature = Signature.getInstance(algorithms.first { it.first == algKey }.second)
            signature.initSign(keyEntry.privateKey)
            signature.update(data)
            val signed = signature.sign()
            Result.success(
                DniSignerResponse(
                    signedData = signed,
                    base64signedData = Base64.toBase64String(signed),
                    base64certificate = Base64.toBase64String(keyEntry.certificate.encoded)
                )
            )
        } catch (th: Throwable) {
            Result.failure(th.toFNMTException(DSSigningException()))
        }
    }

    companion object {
        /** The algorithm `sign` uses on both platforms: SHA-512 with RSA. */
        const val DNIE_ALGORITHM = "SHA512RSA"
    }
}
