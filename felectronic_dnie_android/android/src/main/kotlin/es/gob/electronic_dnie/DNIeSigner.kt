package es.gob.electronic_dnie

import android.app.Activity
import android.nfc.Tag
import android.nfc.tech.IsoDep
import es.gob.electronic_dnie.managers.DNIeReaderManager
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
import kotlinx.coroutines.launch

class DNIeSigner {

    private var scope: DSCustomIOScope = DSCustomIOScope()
    private var nfcConnectionManager: NFCConnectionManager = NFCConnectionManager()
    private var dnieReaderManager: DNIeReaderManager = DNIeReaderManager()

    fun signWithDnie(
        data: ByteArray,
        can: String,
        pin: String,
        timeout: Long,
        signType: DNIeSignType,
        activity: Activity,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit,
        onCardFound: (Unit) -> Unit,
        isDebug: Boolean = true
    ) {
        nfcConnectionManager.startScan(
            activity,
            timeout,
            onSuccess = { tag ->
                onCardFound(Unit)
                readDni(
                    data = data,
                    pin = pin,
                    can = can,
                    tag = tag,
                    signType = signType,
                    onError = onError,
                    onSuccess = onSuccess,
                    isDebug = isDebug
                )
            },
            onError = onError
        )
    }

    fun stopSigner(activity: Activity) {
        nfcConnectionManager.stopScan(activity)
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
                    val historicalBytes = isoDep.historicalBytes ?: isoDep.hiLayerResponse ?: ByteArray(0)
                    val atrHex = historicalBytes.joinToString("") { "%02X".format(it) }
                    val tagId = tag.id.joinToString("") { "%02X".format(it) }
                    val isValid = atrHex.contains("E1F35E11")
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

    private fun readDni(
        data: ByteArray,
        pin: String,
        can: String,
        tag: Tag,
        signType: DNIeSignType,
        onSuccess: (DniSignerResponse) -> Unit,
        onError: (Throwable) -> Unit,
        isDebug: Boolean
    ) {
        scope.launch {
            dnieReaderManager.readDni(pin = pin, can = can, tag = tag, signType = signType).observe(
                onSuccess = { dniePrivateKeyEntry ->
                    scope.launch {
                        TriPhaseSignerManager(isDebug).triPhaseSign(
                            data = data,
                            certChain = dniePrivateKeyEntry.certificateChain,
                            keyEntry = dniePrivateKeyEntry
                        ).observe(onSuccess, onError)
                    }
                },
                onError = onError
            )
        }
    }
}

