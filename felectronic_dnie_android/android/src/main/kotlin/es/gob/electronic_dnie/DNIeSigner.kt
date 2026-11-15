package es.gob.electronic_dnie

import android.app.Activity
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.nfc.tech.NfcB
import es.gob.electronic_dnie.managers.DNIeReaderManager
import es.gob.electronic_dnie.managers.DataSignerManager
import es.gob.electronic_dnie.managers.NFCConnectionManager
import es.gob.electronic_dnie.model.CertificateDetails
import es.gob.electronic_dnie.model.DniSignerResponse
import es.gob.electronic_dnie.model.PersonalDataResult
import es.gob.electronic_dnie.model.ProbeResult
import es.gob.electronic_dnie.utils.DNIeSignType
import es.gob.electronic_dnie.utils.DSCustomIOScope
import es.gob.electronic_dnie.utils.DSNotDNIeException
import es.gob.electronic_dnie.utils.observe
import es.gob.electronic_dnie.triphase.adesp_signer.TriPhaseSignerManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import java.security.KeyStore.PrivateKeyEntry

class DNIeSigner {

    private var scope: DSCustomIOScope = DSCustomIOScope()
    private var nfcConnectionManager: NFCConnectionManager = NFCConnectionManager()
    private var dnieReaderManager: DNIeReaderManager = DNIeReaderManager()

    /**
     * Reads the card and signs [data] on the phone with the private key of
     * [signType], answering the raw PKCS#1 v1.5 signature (SHA-512 with RSA)
     * and the certificate. Nothing is sent over the network.
     */
    fun signWithDnie(
        data: ByteArray,
        can: String,
        pin: String,
        timeout: Long,
        signType: DNIeSignType,
        activity: Activity,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        signAfterScan(can, pin, timeout, signType, activity, onSuccess, onError) { keyEntry ->
            DataSignerManager().signData(data, keyEntry, DataSignerManager.DNIE_ALGORITHM)
        }
    }

    /**
     * Reads the card and signs [data] as CAdES through the three-phase
     * protocol, which sends [data] and the certificate chain to the remote
     * signing service.
     */
    fun signCadesWithDnie(
        data: ByteArray,
        can: String,
        pin: String,
        timeout: Long,
        signType: DNIeSignType,
        activity: Activity,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit,
        isDebug: Boolean = true
    ) {
        signAfterScan(can, pin, timeout, signType, activity, onSuccess, onError) { keyEntry ->
            TriPhaseSignerManager(isDebug).triPhaseSign(
                data = data,
                certChain = keyEntry.certificateChain,
                keyEntry = keyEntry
            )
        }
    }

    private fun signAfterScan(
        can: String,
        pin: String,
        timeout: Long,
        signType: DNIeSignType,
        activity: Activity,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit,
        signer: suspend (PrivateKeyEntry) -> Flow<Result<DniSignerResponse>>
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                readDniAndSign(
                    pin = pin,
                    can = can,
                    tag = tag,
                    signType = signType,
                    signer = signer,
                    onError = {
                        nfcConnectionManager.stopScan(activity)
                        onError(it)
                    },
                    onSuccess = {
                        nfcConnectionManager.stopScan(activity)
                        onSuccess(it)
                    }
                )
            },
            onError = onError
        )
    }

    fun stopSigner(activity: Activity) {
        nfcConnectionManager.cancelScan(activity)
    }

    fun readCertificate(
        can: String,
        pin: String,
        activity: Activity,
        timeout: Long,
        signType: DNIeSignType,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                scope.launch {
                    dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                        onSuccess = { keyEntry ->
                            nfcConnectionManager.stopScan(activity)
                            val cert = keyEntry.certificate as java.security.cert.X509Certificate
                            val certBytes = cert.encoded
                            val certBase64 = android.util.Base64.encodeToString(
                                certBytes,
                                android.util.Base64.NO_WRAP
                            )
                            onSuccess(
                                DniSignerResponse(
                                    signedData = ByteArray(0),
                                    base64signedData = "",
                                    base64certificate = certBase64
                                )
                            )
                        },
                        onError = {
                            nfcConnectionManager.stopScan(activity)
                            onError(it)
                        }
                    )
                }
            },
            onError = onError
        )
    }

    fun probeCard(
        activity: Activity,
        timeout: Long,
        onSuccess: (ProbeResult) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                try {
                    val isoDep = IsoDep.get(tag)
                    if (isoDep == null) {
                        nfcConnectionManager.stopScan(activity)
                        onError(DSNotDNIeException())
                        return@startScan
                    }
                    isoDep.connect()
                    val atrBytes = NfcB.get(tag)?.applicationData
                        ?: isoDep.historicalBytes
                        ?: isoDep.hiLayerResponse
                        ?: ByteArray(0)
                    val atrHex = atrBytes.joinToString("") { "%02X".format(it) }
                    val tagId = tag.id.joinToString("") { "%02X".format(it) }
                    val isValid = atrHex.contains(DNIE_APPLICATION_DATA)
                    isoDep.close()
                    nfcConnectionManager.stopScan(activity)
                    onSuccess(ProbeResult(isValid, atrHex, tagId))
                } catch (e: Exception) {
                    nfcConnectionManager.stopScan(activity)
                    onError(e)
                }
            },
            onError = onError
        )
    }

    fun verifyPin(
        can: String,
        pin: String,
        activity: Activity,
        timeout: Long,
        signType: DNIeSignType,
        onSuccess: () -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                scope.launch {
                    dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                        onSuccess = {
                            nfcConnectionManager.stopScan(activity)
                            onSuccess()
                        },
                        onError = {
                            nfcConnectionManager.stopScan(activity)
                            onError(it)
                        }
                    )
                }
            },
            onError = onError
        )
    }

    fun readCertificateDetails(
        can: String,
        pin: String,
        activity: Activity,
        timeout: Long,
        signType: DNIeSignType,
        onSuccess: (CertificateDetails) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                scope.launch {
                    dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                        onSuccess = { keyEntry ->
                            nfcConnectionManager.stopScan(activity)
                            val details = dnieReaderManager.extractCertificateDetails(keyEntry)
                            onSuccess(details)
                        },
                        onError = {
                            nfcConnectionManager.stopScan(activity)
                            onError(it)
                        }
                    )
                }
            },
            onError = onError
        )
    }

    fun readPersonalData(
        can: String,
        pin: String,
        activity: Activity,
        timeout: Long,
        signType: DNIeSignType,
        onSuccess: (PersonalDataResult) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                scope.launch {
                    dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                        onSuccess = { keyEntry ->
                            nfcConnectionManager.stopScan(activity)
                            val data = dnieReaderManager.extractPersonalData(keyEntry)
                            onSuccess(data)
                        },
                        onError = {
                            nfcConnectionManager.stopScan(activity)
                            onError(it)
                        }
                    )
                }
            },
            onError = onError
        )
    }

    private fun readDniAndSign(
        pin: String,
        can: String,
        tag: Tag,
        signType: DNIeSignType,
        signer: suspend (PrivateKeyEntry) -> Flow<Result<DniSignerResponse>>,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        scope.launch {
            dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                onSuccess = { keyEntry ->
                    scope.launch {
                        signer(keyEntry).observe(onSuccess, onError)
                    }
                },
                onError = onError
            )
        }
    }

    companion object {
        private const val DNIE_APPLICATION_DATA = "E1F35E11"
    }
}
