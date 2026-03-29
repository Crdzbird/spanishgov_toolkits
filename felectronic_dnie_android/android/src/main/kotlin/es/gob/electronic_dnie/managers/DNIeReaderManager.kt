package es.gob.electronic_dnie.managers

import android.nfc.Tag
import es.gob.electronic_dnie.jmulticard.AndroidNfcConnection
import es.gob.electronic_dnie.jmulticard.DnieCallbackHandler
import es.gob.electronic_dnie.model.CertificateDetails
import es.gob.electronic_dnie.model.PersonalDataResult
import es.gob.electronic_dnie.utils.DNIeSignType
import es.gob.electronic_dnie.utils.DSDNIeConnectionException
import es.gob.electronic_dnie.utils.DSDNIeProviderException
import es.gob.electronic_dnie.utils.DSExpiredCertificateException
import es.gob.electronic_dnie.utils.DSPrivateKeyException
import es.gob.electronic_dnie.utils.DSUnderageDocumentException
import es.gob.electronic_dnie.utils.DSUnknownException
import es.gob.electronic_dnie.utils.toFNMTException
import es.gob.jmulticard.jse.provider.DnieProvider
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.security.KeyStore
import java.security.KeyStore.PrivateKeyEntry
import java.security.Provider
import java.security.Security
import java.security.cert.X509Certificate

private const val KEYSTORE_TYPE_DNI = "DNI"

class DNIeReaderManager {

    suspend fun readDni(
        pin: String,
        can: String,
        tag: Tag,
        signType: DNIeSignType
    ): Flow<Result<PrivateKeyEntry>> = flow {
        emit(readDniAndGetCertificate(pin = pin, can = can, tag = tag, signType = signType))
    }

    private fun readDniAndGetCertificate(
        pin: String,
        can: String,
        tag: Tag,
        signType: DNIeSignType
    ): Result<PrivateKeyEntry> {
        val providerBuilder = createProvider(tag)
        if (providerBuilder.isFailure) {
            return Result.failure(
                providerBuilder.exceptionOrNull() ?: DSUnknownException(1)
            )
        }

        val provider: Provider = providerBuilder.getOrNull() ?: return Result.failure(
            DSDNIeProviderException()
        )

        val privateKeyBuilder = generateConnection(pin, can, provider, signType)
        if (privateKeyBuilder.isFailure) {
            return Result.failure(privateKeyBuilder.exceptionOrNull() ?: DSUnknownException(2))
        }

        return privateKeyBuilder.getOrNull()?.let {
            Result.success(it)
        } ?: Result.failure(DSPrivateKeyException())
    }

    private fun createProvider(tag: Tag): Result<Provider> {
        return try {
            val provider = DnieProvider(AndroidNfcConnection(tag))
            if (Security.getProvider(provider.name) == null) {
                Security.insertProviderAt(provider, 1)
            }
            Result.success(provider)
        } catch (t: Throwable) {
            Result.failure(t.toFNMTException(DSDNIeProviderException()))
        }
    }

    private fun generateConnection(
        pin: String,
        can: String,
        provider: Provider,
        signType: DNIeSignType
    ): Result<PrivateKeyEntry> {
        try {
            val builder: KeyStore.Builder = KeyStore.Builder.newInstance(
                KEYSTORE_TYPE_DNI,
                provider,
                KeyStore.CallbackHandlerProtection(DnieCallbackHandler(can, pin))
            )

            val ks: KeyStore = builder.keyStore

            val keyEntry = ks.getEntry(signType.type, null)?.let {
                it as PrivateKeyEntry
            } ?: return Result.failure(DSUnderageDocumentException())

            val certificate = (keyEntry.certificate as X509Certificate)
            try {
                certificate.checkValidity()
            } catch (t: Throwable) {
                return Result.failure(DSExpiredCertificateException())
            }

            return Result.success(keyEntry)
        } catch (th: Throwable) {
            return Result.failure(th.toFNMTException(DSDNIeConnectionException()))
        }
    }

    fun extractCertificateDetails(keyEntry: PrivateKeyEntry): CertificateDetails {
        val cert = keyEntry.certificate as X509Certificate
        val subjectDN = cert.subjectX500Principal.name
        val issuerDN = cert.issuerX500Principal.name

        val subjectCN = parseDNField(subjectDN, "CN")
        val subjectSerial = parseDNField(subjectDN, "SERIALNUMBER")
            .removePrefix("IDCES-")
        val issuerCN = parseDNField(issuerDN, "CN")
        val issuerOrg = parseDNField(issuerDN, "O")

        val isValid = try {
            cert.checkValidity()
            true
        } catch (_: Throwable) {
            false
        }

        return CertificateDetails(
            subjectCommonName = subjectCN,
            subjectSerialNumber = subjectSerial,
            issuerCommonName = issuerCN,
            issuerOrganization = issuerOrg,
            notValidBefore = cert.notBefore.time,
            notValidAfter = cert.notAfter.time,
            serialNumber = cert.serialNumber.toString(16),
            isCurrentlyValid = isValid
        )
    }

    fun extractPersonalData(keyEntry: PrivateKeyEntry): PersonalDataResult {
        val cert = keyEntry.certificate as X509Certificate
        val subjectDN = cert.subjectX500Principal.name

        val cn = parseDNField(subjectDN, "CN")
        val serialNumber = parseDNField(subjectDN, "SERIALNUMBER")
            .removePrefix("IDCES-")
        val country = parseDNField(subjectDN, "C")

        // Parse CN: "APELLIDO1 APELLIDO2, NOMBRE (FIRMA)"
        var surnames = ""
        var givenName = ""
        var certificateType = ""

        val parenIdx = cn.indexOf("(")
        val nameWithoutType = if (parenIdx >= 0) {
            val closeIdx = cn.indexOf(")", parenIdx)
            if (closeIdx > parenIdx) {
                certificateType = cn.substring(parenIdx + 1, closeIdx).trim()
            }
            cn.substring(0, parenIdx).trim()
        } else {
            cn
        }

        val commaIdx = nameWithoutType.indexOf(",")
        if (commaIdx >= 0) {
            surnames = nameWithoutType.substring(0, commaIdx).trim()
            givenName = nameWithoutType.substring(commaIdx + 1).trim()
        } else {
            surnames = nameWithoutType
        }

        val fullName = if (givenName.isEmpty()) surnames else "$givenName $surnames"

        return PersonalDataResult(
            fullName = fullName,
            givenName = givenName,
            surnames = surnames,
            nif = serialNumber,
            country = country,
            certificateType = certificateType
        )
    }

    private fun parseDNField(dn: String, field: String): String {
        // Parse DN fields using regex — javax.naming.ldap.LdapName
        // is not available on Android.
        // Handles both simple values and quoted values in DN strings.
        val quotedPattern = Regex("""$field="([^"]+)"""", RegexOption.IGNORE_CASE)
        quotedPattern.find(dn)?.groupValues?.getOrNull(1)?.trim()?.let { return it }

        val simplePattern = Regex("""$field=([^,+]+)""", RegexOption.IGNORE_CASE)
        return simplePattern.find(dn)?.groupValues?.getOrNull(1)?.trim() ?: ""
    }
}
