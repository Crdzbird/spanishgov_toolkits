package es.gob.electronic_dnie

import android.app.Activity
import android.nfc.NfcAdapter
import es.gob.electronic_dnie.utils.DNIeSignType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference

class ElectronicDniePlugin :
    FlutterPlugin,
    FelectronicDnieHostApi,
    ActivityAware {

    private var activity: WeakReference<Activity> = WeakReference(null)
    private var dnieSigner: DNIeSigner = DNIeSigner()

    override fun onAttachedToEngine(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        FelectronicDnieHostApi.setUp(
            flutterPluginBinding.binaryMessenger,
            this,
        )
    }

    override fun onDetachedFromEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        FelectronicDnieHostApi.setUp(binding.binaryMessenger, null)
    }

    // MARK: - Helpers

    private fun resolveSignType(certificateType: String): DNIeSignType =
        if (certificateType == "AUTH") DNIeSignType.AUTH else DNIeSignType.SIGN

    private fun requireActivity(
        onError: (Result<Nothing>) -> Unit,
    ): Activity? {
        val currentActivity = activity.get()
        if (currentActivity == null) {
            onError(
                Result.failure(
                    FlutterError(
                        "NO_ACTIVITY",
                        "Cannot call method when not attached to activity",
                    ),
                ),
            )
        }
        return currentActivity
    }

    // MARK: - FelectronicDnieHostApi

    override fun sign(
        data: ByteArray,
        can: String,
        pin: String,
        timeout: Long,
        certificateType: String,
        callback: (Result<DnieSignedDataMessage>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return
        val signType = resolveSignType(certificateType)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.signWithDnie(
                    data = data,
                    can = can,
                    pin = pin,
                    activity = currentActivity,
                    timeout = timeout,
                    signType = signType,
                    onSuccess = { response ->
                        val result = DnieSignedDataMessage(
                            signedData = response.signedData,
                            signedDataBase64 = response.base64signedData,
                            certificate = response.base64certificate,
                        )
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(result))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                    onCardFound = {},
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun stopSign(callback: (Result<Unit>) -> Unit) {
        val currentActivity = requireActivity(callback) ?: return

        try {
            dnieSigner.stopSigner(currentActivity)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(
                Result.failure(
                    FlutterError(
                        "DSUnknownException",
                        e.localizedMessage,
                    ),
                ),
            )
        }
    }

    override fun readCertificate(
        can: String,
        pin: String,
        timeout: Long,
        certificateType: String,
        callback: (Result<DnieSignedDataMessage>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return
        val signType = resolveSignType(certificateType)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.readCertificate(
                    can = can,
                    pin = pin,
                    activity = currentActivity,
                    timeout = timeout,
                    signType = signType,
                    onSuccess = { response ->
                        val result = DnieSignedDataMessage(
                            signedData = response.signedData,
                            signedDataBase64 = response.base64signedData,
                            certificate = response.base64certificate,
                        )
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(result))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun probeCard(
        timeout: Long,
        callback: (Result<DnieCardProbeMessage>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.probeCard(
                    activity = currentActivity,
                    timeout = timeout,
                    onSuccess = { probeResult ->
                        val result = DnieCardProbeMessage(
                            isValidDnie = probeResult.isValidDnie,
                            atrHex = probeResult.atrHex,
                            tagId = probeResult.tagId,
                        )
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(result))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun readCertificateDetails(
        can: String,
        pin: String,
        timeout: Long,
        certificateType: String,
        callback: (Result<DnieCertificateDetailsMessage>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return
        val signType = resolveSignType(certificateType)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.readCertificateDetails(
                    can = can,
                    pin = pin,
                    activity = currentActivity,
                    timeout = timeout,
                    signType = signType,
                    onSuccess = { details ->
                        val result = DnieCertificateDetailsMessage(
                            subjectCommonName = details.subjectCommonName,
                            subjectSerialNumber = details.subjectSerialNumber,
                            issuerCommonName = details.issuerCommonName,
                            issuerOrganization = details.issuerOrganization,
                            notValidBefore = details.notValidBefore,
                            notValidAfter = details.notValidAfter,
                            serialNumber = details.serialNumber,
                            isCurrentlyValid = details.isCurrentlyValid,
                        )
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(result))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun readPersonalData(
        can: String,
        pin: String,
        timeout: Long,
        certificateType: String,
        callback: (Result<DniePersonalDataMessage>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return
        val signType = resolveSignType(certificateType)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.readPersonalData(
                    can = can,
                    pin = pin,
                    activity = currentActivity,
                    timeout = timeout,
                    signType = signType,
                    onSuccess = { data ->
                        val result = DniePersonalDataMessage(
                            fullName = data.fullName,
                            givenName = data.givenName,
                            surnames = data.surnames,
                            nif = data.nif,
                            country = data.country,
                            certificateType = data.certificateType,
                        )
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(result))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun verifyPin(
        can: String,
        pin: String,
        timeout: Long,
        certificateType: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        val currentActivity = requireActivity(callback) ?: return
        val signType = resolveSignType(certificateType)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                dnieSigner.verifyPin(
                    can = can,
                    pin = pin,
                    activity = currentActivity,
                    timeout = timeout,
                    signType = signType,
                    onSuccess = {
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(Result.success(Unit))
                        }
                    },
                    onError = { throwable ->
                        CoroutineScope(Dispatchers.Main).launch {
                            callback(
                                Result.failure(
                                    FlutterError(
                                        throwable::class.java.simpleName,
                                        throwable.localizedMessage,
                                    ),
                                ),
                            )
                        }
                    },
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(
                        Result.failure(
                            FlutterError(
                                e::class.java.simpleName,
                                e.localizedMessage,
                            ),
                        ),
                    )
                }
            }
        }
    }

    override fun checkNfcAvailability(
        callback: (Result<DnieNfcStatusMessage>) -> Unit,
    ) {
        val currentActivity = activity.get()
        val adapter = currentActivity?.let { NfcAdapter.getDefaultAdapter(it) }
        val result = DnieNfcStatusMessage(
            isAvailable = adapter != null,
            isEnabled = adapter?.isEnabled ?: false,
        )
        callback(Result.success(result))
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity.clear()
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        activity = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity.clear()
    }
}
