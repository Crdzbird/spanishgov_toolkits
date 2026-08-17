package es.gob.electronic_certificates

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.security.KeyChain
import es.gob.portafirmas.certificatesigner.CertificateSigner
import es.gob.portafirmas.certificatesigner.models.PFCertificateInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.security.Signature
import java.security.cert.X509Certificate

class ElectronicCertificatesPlugin :
    FlutterPlugin,
    FelectronicCertificatesHostApi,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var certificateSigner: CertificateSigner? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var pendingImportCallback: ((Result<Unit>) -> Unit)? = null

    companion object {
        private const val IMPORT_REQUEST_CODE = 1234
        private const val PREFS_NAME = "felectronic_certificates"
        private const val KEY_DEFAULT_ALIAS = "default_alias"
        private const val KEY_KNOWN_ALIASES = "known_aliases"

        /**
         * Normalises a serial to lowercase hex with no DER sign-padding byte
         * and no leading zeros. Returns `"0"` for an all-zero serial and
         * `""` for empty input.
         *
         * Must stay behaviourally identical to `CertificateSerial.canonical`
         * (Dart) and `KeychainCertificateManager.canonicalSerial` (Swift) —
         * the serial is the keystore lookup key and all three have to agree.
         */
        fun canonicalSerial(serial: String): String {
            if (serial.isEmpty()) return ""

            var hex = serial.lowercase()
                .filterNot { it == ' ' || it == '\t' || it == ':' ||
                    it == '_' || it == '-' }
            if (hex.startsWith("0x")) hex = hex.substring(2)
            if (hex.isEmpty()) return ""

            val stripped = hex.trimStart('0')
            return if (stripped.isEmpty()) "0" else stripped
        }

        /**
         * Canonical serial for [cert].
         *
         * Uses `BigInteger.toByteArray()` rather than `toString(16)` so the
         * bytes match the DER INTEGER content octets iOS reports, then
         * canonicalises. `toString(16)` would emit a leading `-` for a serial
         * mis-encoded as negative, which is not a valid lookup key.
         */
        fun canonicalSerialOf(cert: X509Certificate): String =
            canonicalSerial(
                cert.serialNumber.toByteArray()
                    .joinToString("") { "%02x".format(it) },
            )
    }

    // ── SharedPreferences helpers ─────────────────────────────────────

    private fun prefs(): SharedPreferences? =
        activity?.getSharedPreferences(PREFS_NAME, 0)

    private fun getDefaultAlias(): String? =
        prefs()?.getString(KEY_DEFAULT_ALIAS, null)

    private fun setDefaultAlias(alias: String?) {
        val editor = prefs()?.edit() ?: return
        if (alias == null) {
            editor.remove(KEY_DEFAULT_ALIAS)
        } else {
            editor.putString(KEY_DEFAULT_ALIAS, alias)
            // Track known aliases for getAllCertificates
            addKnownAlias(alias)
        }
        editor.apply()
    }

    private fun getKnownAliases(): Set<String> =
        prefs()?.getStringSet(KEY_KNOWN_ALIASES, emptySet()) ?: emptySet()

    private fun addKnownAlias(alias: String) {
        val current = getKnownAliases().toMutableSet()
        current.add(alias)
        prefs()?.edit()?.putStringSet(KEY_KNOWN_ALIASES, current)?.apply()
    }

    private fun removeKnownAlias(alias: String) {
        val current = getKnownAliases().toMutableSet()
        current.remove(alias)
        prefs()?.edit()?.putStringSet(KEY_KNOWN_ALIASES, current)?.apply()
    }

    // ── Signer helper ─────────────────────────────────────────────────

    private fun requireSigner(
        callback: (Result<Nothing>) -> Unit,
    ): CertificateSigner? {
        if (certificateSigner == null && activity != null) {
            certificateSigner = CertificateSigner(activity!!)
        }
        val signer = certificateSigner
        if (signer == null) {
            callback(Result.failure(noActivityError()))
        }
        return signer
    }

    // ── FlutterPlugin ─────────────────────────────────────────────────

    override fun onAttachedToEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        FelectronicCertificatesHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        FelectronicCertificatesHostApi.setUp(binding.binaryMessenger, null)
    }

    // ── ActivityAware ─────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        certificateSigner = CertificateSigner(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
        certificateSigner = null
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        certificateSigner = CertificateSigner(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
        certificateSigner = null
    }

    // ── ActivityResultListener ────────────────────────────────────────

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode == IMPORT_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingImportCallback?.invoke(Result.success(Unit))
            } else {
                pendingImportCallback?.invoke(
                    Result.failure(
                        FlutterError(
                            "AddCertificateCanceled",
                            "Import cancelled by user",
                            null,
                        ),
                    ),
                )
            }
            pendingImportCallback = null
            return true
        }
        return false
    }

    // ── FelectronicCertificatesHostApi ─────────────────────────────────

    override fun getAllCertificates(
        callback: (Result<List<DeviceCertificateMessage?>>) -> Unit,
    ) {
        val ctx = activity
        if (ctx == null) {
            callback(Result.success(emptyList()))
            return
        }

        scope.launch {
            val messages = mutableListOf<DeviceCertificateMessage?>()
            val aliases = getKnownAliases()

            withContext(Dispatchers.IO) {
                for (alias in aliases) {
                    try {
                        val msg = buildMessageForAlias(ctx, alias)
                        if (msg != null) messages.add(msg)
                    } catch (_: Exception) {
                        // Alias no longer valid — remove it
                        removeKnownAlias(alias)
                    }
                }
            }

            // Also check AAR default if not already in the list
            try {
                val aarCert = certificateSigner?.getDefaultCertificate()
                if (aarCert != null) {
                    val aarSerial = canonicalSerialOf(aarCert.certificate)
                    val alreadyListed = messages
                        .filterNotNull()
                        .any { it.serialNumber == aarSerial }
                    if (!alreadyListed) {
                        messages.add(mapAarToMessage(aarCert))
                    }
                }
            } catch (_: Exception) {
                // No AAR default
            }

            callback(Result.success(messages))
        }
    }

    override fun getDefaultCertificate(
        callback: (Result<DeviceCertificateMessage?>) -> Unit,
    ) {
        val ctx = activity
        val alias = getDefaultAlias()

        // Try AAR first
        try {
            val aarCert = certificateSigner?.getDefaultCertificate()
            if (aarCert != null) {
                callback(Result.success(mapAarToMessage(aarCert)))
                return
            }
        } catch (_: Exception) {
            // Fall through
        }

        // Try KeyChain by stored alias
        if (ctx == null || alias == null) {
            callback(Result.success(null))
            return
        }

        scope.launch {
            try {
                val msg = withContext(Dispatchers.IO) {
                    buildMessageForAlias(ctx, alias)
                }
                callback(Result.success(msg))
            } catch (_: Exception) {
                callback(Result.success(null))
            }
        }
    }

    override fun selectDefaultCertificate(
        callback: (Result<DeviceCertificateMessage?>) -> Unit,
    ) {
        @Suppress("UNCHECKED_CAST")
        val signer = requireSigner(
            callback as (Result<Nothing>) -> Unit,
        ) ?: return

        signer.selectDefaultCertificate(
            { cert ->
                // Track the alias so getAllCertificates can find it
                addKnownAlias(cert.alias)
                setDefaultAlias(cert.alias)

                scope.launch {
                    callback(Result.success(mapAarToMessage(cert)))
                }
            },
            { error ->
                scope.launch {
                    if (error::class.simpleName ==
                        "CSCertificateNotPickedException"
                    ) {
                        callback(Result.success(null))
                    } else {
                        callback(Result.failure(wrapError(error)))
                    }
                }
            },
        )
    }

    override fun setDefaultCertificateBySerialNumber(
        serialNumber: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ctx = activity
        if (ctx == null) {
            callback(Result.failure(noActivityError()))
            return
        }

        // Find the alias that matches this serial number. The incoming serial
        // is canonicalised because it may have been persisted by an earlier
        // version in a platform-specific spelling.
        val wanted = canonicalSerial(serialNumber)
        scope.launch {
            withContext(Dispatchers.IO) {
                for (alias in getKnownAliases()) {
                    try {
                        val msg = buildMessageForAlias(ctx, alias)
                        if (msg?.serialNumber == wanted) {
                            setDefaultAlias(alias)
                            withContext(Dispatchers.Main) {
                                callback(Result.success(Unit))
                            }
                            return@withContext
                        }
                    } catch (_: Exception) {
                        // Skip
                    }
                }
                // Not found in known aliases — store serial as alias
                withContext(Dispatchers.Main) {
                    setDefaultAlias(serialNumber)
                    callback(Result.success(Unit))
                }
            }
        }
    }

    override fun clearDefaultCertificate(callback: (Result<Unit>) -> Unit) {
        try {
            certificateSigner?.clearDefaultCertificate()
        } catch (_: Exception) {
            // Ignore
        }
        setDefaultAlias(null)
        callback(Result.success(Unit))
    }

    override fun signWithDefaultCertificate(
        data: ByteArray,
        algorithm: CertSignAlgorithmMessage,
        callback: (Result<ByteArray>) -> Unit,
    ) {
        // Try AAR first (uses its own default selection)
        val signer = certificateSigner
        if (signer != null) {
            try {
                val aarCert = signer.getDefaultCertificate()
                if (aarCert != null) {
                    signer.signWithDefaultCertificate(
                        data,
                        // The AAR takes the legacy string form; the enum
                        // constant names match it exactly (SHA256RSA, ...).
                        algorithm.name,
                        { signedBytes ->
                            scope.launch {
                                callback(Result.success(signedBytes))
                            }
                        },
                        { error ->
                            scope.launch {
                                callback(Result.failure(
                                    FlutterError(
                                        "SigningError",
                                        error.localizedMessage
                                            ?: "Signing failed",
                                        null,
                                    ),
                                ))
                            }
                        },
                    )
                    return
                }
            } catch (_: Exception) {
                // Fall through to KeyChain signing
            }
        }

        // Fallback: sign via KeyChain API directly
        val ctx = activity
        val alias = getDefaultAlias()
        if (ctx == null || alias == null) {
            callback(Result.failure(
                FlutterError(
                    "NotSelectedCertificate",
                    "No default certificate selected",
                    null,
                ),
            ))
            return
        }

        scope.launch {
            try {
                val signature = withContext(Dispatchers.IO) {
                    val privateKey = KeyChain.getPrivateKey(ctx, alias)
                        ?: throw Exception("Private key not available")
                    val jcaAlg = mapAlgorithm(algorithm)
                    val sig = Signature.getInstance(jcaAlg)
                    sig.initSign(privateKey)
                    sig.update(data)
                    sig.sign()
                }
                callback(Result.success(signature))
            } catch (e: Exception) {
                callback(Result.failure(
                    FlutterError(
                        "SigningError",
                        e.localizedMessage ?: "Signing failed",
                        null,
                    ),
                ))
            }
        }
    }

    override fun importCertificate(
        pkcs12Data: ByteArray,
        password: String?,
        alias: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        @Suppress("UNCHECKED_CAST")
        val signer = requireSigner(
            callback as (Result<Nothing>) -> Unit,
        ) ?: return

        try {
            val success = signer.importCertificate(
                pkcs12Data,
                password ?: "",
                null,
            )
            if (success) {
                callback(Result.success(Unit))
            } else {
                callback(Result.failure(
                    FlutterError(
                        "IncorrectPassword",
                        "Failed to import certificate",
                        null,
                    ),
                ))
            }
        } catch (e: Exception) {
            callback(Result.failure(wrapError(e)))
        }
    }

    override fun deleteDefaultCertificate(callback: (Result<Unit>) -> Unit) {
        @Suppress("UNCHECKED_CAST")
        val signer = requireSigner(
            callback as (Result<Nothing>) -> Unit,
        ) ?: return

        try {
            val alias = getDefaultAlias()
            signer.deleteCertificate()
            if (alias != null) removeKnownAlias(alias)
            setDefaultAlias(null)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(wrapError(e)))
        }
    }

    override fun deleteCertificateBySerialNumber(
        serialNumber: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ctx = activity
        if (ctx == null) {
            callback(Result.failure(noActivityError()))
            return
        }

        scope.launch {
            withContext(Dispatchers.IO) {
                // Find the alias matching this serial (canonical comparison).
                val wanted = canonicalSerial(serialNumber)
                for (alias in getKnownAliases()) {
                    try {
                        val msg = buildMessageForAlias(ctx, alias)
                        if (msg?.serialNumber == wanted) {
                            removeKnownAlias(alias)
                            if (getDefaultAlias() == alias) {
                                setDefaultAlias(null)
                                try {
                                    certificateSigner?.deleteCertificate()
                                } catch (_: Exception) {
                                    // Ignore
                                }
                            }
                            break
                        }
                    } catch (_: Exception) {
                        removeKnownAlias(alias)
                    }
                }
            }
            callback(Result.success(Unit))
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    /// Build a DeviceCertificateMessage by reading the KeyChain directly.
    private fun buildMessageForAlias(
        ctx: android.content.Context,
        alias: String,
    ): DeviceCertificateMessage? {
        val chain = KeyChain.getCertificateChain(ctx, alias) ?: return null
        val cert = chain.firstOrNull() as? X509Certificate ?: return null

        // Subject CN, issuer CN, validity and key usage are intentionally not
        // computed here: Dart decodes them from `encoded` via
        // felectronic_x509, so Android and iOS cannot disagree. The previous
        // key-usage block also invented "SIGNING;AUTHENTICATION" whenever the
        // extension was absent, asserting capabilities the certificate never
        // claimed.
        return DeviceCertificateMessage(
            serialNumber = canonicalSerialOf(cert),
            alias = alias,
            encoded = cert.encoded,
        )
    }

    /// Build message from AAR's PFCertificateInfo.
    private fun mapAarToMessage(
        info: PFCertificateInfo,
    ): DeviceCertificateMessage {
        return DeviceCertificateMessage(
            serialNumber = canonicalSerialOf(info.certificate),
            alias = info.alias,
            encoded = info.certificate.encoded,
        )
    }

    /**
     * Maps the wire enum to a JCA `Signature` algorithm name.
     *
     * Exhaustive over [CertSignAlgorithmMessage] with no `else` branch, so
     * adding a case to the Pigeon schema is a compile error here rather than
     * a silent fall-through to SHA256withRSA — which previously meant a
     * misspelled algorithm signed with RSA parameters against an EC key and
     * failed with an opaque provider error.
     */
    private fun mapAlgorithm(algorithm: CertSignAlgorithmMessage): String =
        when (algorithm) {
            CertSignAlgorithmMessage.SHA256RSA -> "SHA256withRSA"
            CertSignAlgorithmMessage.SHA384RSA -> "SHA384withRSA"
            CertSignAlgorithmMessage.SHA512RSA -> "SHA512withRSA"
            CertSignAlgorithmMessage.SHA256EC -> "SHA256withECDSA"
            CertSignAlgorithmMessage.SHA384EC -> "SHA384withECDSA"
            CertSignAlgorithmMessage.SHA512EC -> "SHA512withECDSA"
        }

    private fun noActivityError() = FlutterError(
        "NO_ACTIVITY",
        "Cannot call method when not attached to activity",
        null,
    )

    private fun wrapError(e: Throwable): FlutterError {
        val code = when (e::class.simpleName) {
            "CSCertificateNotPickedException" -> "NotSelectedCertificate"
            "CSSigningCertificateNotSelectedException" ->
                "NotSelectedCertificate"
            "CSSigningException" -> "SigningError"
            "CSNullPrivateKeyException" -> "SigningError"
            "CSPrivateKeyEntryException" -> "SigningError"
            else -> e::class.simpleName ?: "UnknownError"
        }
        return FlutterError(
            code,
            e.localizedMessage ?: "Unknown error",
            null,
        )
    }
}
