package es.gob.electronic_dnie.managers

import android.util.Base64
import es.gob.electronic_dnie.model.DniSignerResponse
import es.gob.electronic_dnie.utils.DSSigningException
import es.gob.electronic_dnie.utils.toFNMTException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
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

class DataSignerManager {
    suspend fun signData(
        data: ByteArray,
        keyEntry: KeyStore.PrivateKeyEntry,
        algKey: String
    ): Flow<Result<DniSignerResponse>> = flow {
        emit(signDataWithPrivateKey(data = data, keyEntry = keyEntry, algKey = algKey))
    }

    private fun signDataWithPrivateKey(
        data: ByteArray,
        keyEntry: KeyStore.PrivateKeyEntry,
        algKey: String
    ): Result<DniSignerResponse> {
        return try {
            // 1. Init signature with algorithm
            val signature = Signature.getInstance(algorithms.first { it.first == algKey }.second)
            signature.initSign(keyEntry.privateKey)

            // 2. Update data to be signed
            signature.update(data)

            // 3. Sign and return data model
            val response = DniSignerResponse(
                signedData = signature.sign(),
                base64signedData = Base64.encodeToString(signature.sign(), Base64.DEFAULT),
                base64certificate = Base64.encodeToString(
                    keyEntry.certificate.encoded,
                    Base64.DEFAULT
                )
            )

            Result.success(response)
        } catch (th: Throwable) {
            Result.failure(th.toFNMTException(DSSigningException()))
        }
    }
}
