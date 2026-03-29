package es.gob.electronic_dnie.triphase.adesp_signer

import es.gob.electronic_dnie.model.DniSignerResponse
import es.gob.electronic_dnie.triphase.adesp_signer.data.SignType
import es.gob.electronic_dnie.triphase.adesp_signer.data.SignatureFormat
import es.gob.electronic_dnie.triphase.adesp_signer.retrofit.SignerService
import es.gob.electronic_dnie.triphase.adesp_signer.utils.addPKCS1forPostSign
import es.gob.electronic_dnie.triphase.adesp_signer.utils.base64Decode
import es.gob.electronic_dnie.triphase.adesp_signer.utils.fromBase64
import es.gob.electronic_dnie.triphase.adesp_signer.utils.normalizeBase64ForPreSign
import es.gob.electronic_dnie.triphase.adesp_signer.utils.normalizeBase64ForSelfSign
import es.gob.electronic_dnie.triphase.adesp_signer.utils.toBase64
import es.gob.electronic_dnie.triphase.utils.encoder.Base64Encoder
import es.gob.electronic_dnie.triphase.utils.encoder.BouncyCastleBase64Encoder
import es.gob.electronic_dnie.triphase.utils.logger.AndroidLogger
import es.gob.electronic_dnie.triphase.utils.logger.Logger
import es.gob.electronic_dnie.utils.DSSigningException
import es.gob.electronic_dnie.utils.toFNMTException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStreamWriter
import java.lang.Boolean.FALSE
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.Signature
import java.security.cert.Certificate
import java.security.cert.CertificateEncodingException
import java.util.Locale
import java.util.Properties

class TriPhaseSignerManager(isDebug: Boolean) {
    private var encoder: Base64Encoder = BouncyCastleBase64Encoder()
    private val logger: Logger = AndroidLogger(isDebug)
    private val client = OkHttpClient.Builder().build()
    private val retrofit = Retrofit.Builder()
        .baseUrl("https://firmamovil-appfactory.redsara.es")
        .client(client)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
    private val service = retrofit.create(SignerService::class.java)

    suspend fun triPhaseSign(
        data: ByteArray,
        certChain: Array<Certificate>,
        keyEntry: KeyStore.PrivateKeyEntry
    ): Flow<Result<DniSignerResponse>> = flow {

        val signatureFormat = SignatureFormat.CADES.value
        val signAlgorithm = "SHA512withRSA"
        val signType = SignType.COMMON

        try {
            preSign(
                certChain,
                encoder.encode(data),
                signatureFormat,
                signAlgorithm,
                signType
            ).fold(
                onSuccess = { preSignResult ->

                    signDataWithDniePrivateKey(
                        preSignResult,
                        keyEntry,
                        signAlgorithm
                    ).fold(
                        onSuccess = { preSignedDataWithPrivateKey ->
                            postSign(
                                certChain = certChain,
                                doc = encoder.encode(data),
                                preSignResult = preSignedDataWithPrivateKey,
                                format = signatureFormat,
                                signType = signType
                            ).fold(
                                onSuccess = { result ->
                                    emit(
                                        Result.success(
                                            DniSignerResponse(
                                                signedData = result,
                                                base64signedData = encoder.encode(result),
                                                base64certificate = encoder.encode(certChain[0].encoded)
                                            )
                                        )
                                    )
                                },
                                onFailure = {
                                    logger.e(TAG, "Postsign error", it)
                                    emit(Result.failure(it))
                                }
                            )
                        },
                        onFailure = {
                            logger.e(TAG, "Dni Sign error", it)
                            emit(Result.failure(it))
                        }
                    )
                },
                onFailure = {
                    logger.e(TAG, "Presign error", it)
                    emit(Result.failure(it))
                }
            )
        } catch (e: Exception) {
            logger.e(TAG, "Unexpected error during tri-phase signing", e)
            emit(Result.failure(e))
        }
    }

    private suspend fun preSign(
        certChain: Array<Certificate>,
        doc: String,
        format: String,
        signAlgorithm: String = "SHA512withRSA",
        signType: SignType
    ): Result<String> {

        val response = processResponse {
            service.prePostSignData(
                body = generateSignRequest(
                    operation = "pre",
                    certs = certChain,
                    doc = doc,
                    format = format,
                    signAlgorithm = signAlgorithm,
                    params = getExtraParams(signType)
                )
            )
        }

        return response.getOrNull()?.let {
            it.string().let { body ->
                if (body.startsWith("ERR-")) {
                    logger.e(TAG, "Error during pre-sign request", Throwable(body))
                    Result.failure(Exception(Throwable(body)))
                } else Result.success(body)
            }
        } ?: run {
            logger.e(TAG, "Error during pre-sign request", response.exceptionOrNull())
            Result.failure(Exception(response.exceptionOrNull()))
        }
    }

    private fun signDataWithDniePrivateKey(
        preSignResult: String,
        keyEntry: KeyStore.PrivateKeyEntry,
        signAlgorithm: String
    ): Result<String> {
        return try {
            val normalizedPreResult = preSignResult.normalizeBase64ForSelfSign()
            val xmlString = normalizedPreResult.fromBase64(encoder) ?: return Result.failure(
                DSSigningException()
            )
            val preBase64ForSign = getPREvalueXML(xmlString)
            val preDataForSign = preBase64ForSign?.base64Decode(encoder) ?: return Result.failure(
                DSSigningException()
            )

            val signature = Signature.getInstance(signAlgorithm)
            signature.initSign(keyEntry.privateKey)
            signature.update(preDataForSign)
            val signedData = signature.sign()

            val result = xmlString.addPKCS1forPostSign(encoder.encode(signedData))
                .toBase64(encoder)?.normalizeBase64ForPreSign()

            Result.success(result ?: "")
        } catch (e: Exception) {
            logger.e(TAG, "Error during Dni signature", e)
            Result.failure(e.toFNMTException(DSSigningException()))
        }
    }

    private suspend fun postSign(
        certChain: Array<Certificate>,
        doc: String,
        format: String,
        signAlgorithm: String = "SHA512withRSA",
        preSignResult: String,
        signType: SignType
    ): Result<ByteArray> {
        val response = processResponse {
            service.prePostSignData(
                body = generateSignRequest(
                    operation = "post",
                    certs = certChain,
                    doc = doc,
                    format = format,
                    signAlgorithm = signAlgorithm,
                    params = getExtraParams(signType),
                    preSignResult = preSignResult
                )
            )
        }

        return response.fold(
            onSuccess = { body ->
                val trimmedBody = body.string().trim()
                if (trimmedBody.startsWith("OK")) {
                    try {
                        val decodedData = encoder.decode(
                            trimmedBody.substring("OK NEWID=".length).normalizeBase64ForSelfSign()
                        )
                        Result.success(decodedData)
                    } catch (e: Exception) {
                        logger.e(TAG, "Error decoding response", e)
                        Result.failure(e)
                    }
                } else {
                    logger.e(TAG, "KO response for trimmedBody: $trimmedBody")
                    Result.failure(Exception("KO response for trimmedBody: $trimmedBody"))
                }
            },
            onFailure = {
                logger.e(TAG, "Error processing response", it)
                Result.failure(it)
            }
        )
    }

    private fun getPREvalueXML(xmlString: String): String? {
        val regex = "<param n=\"PRE\">(.*?)</param>".toRegex()
        return regex.find(xmlString)?.groups?.get(1)?.value
    }

    private fun generateSignRequest(
        operation: String,
        certs: Array<Certificate>,
        doc: String,
        format: String,
        signAlgorithm: String = "SHA512withRSA",
        params: Properties? = null,
        preSignResult: String? = null
    ): RequestBody {
        var prePostSignData =
            "op=$operation&cop=sign&format=$format&algo=$signAlgorithm&cert=${
                prepareCertChainParam(certs, params).normalizeBase64ForPreSign()
            }&doc=${doc.normalizeBase64ForPreSign()}"

        if (!params.isNullOrEmpty()) {
            prePostSignData =
                "$prePostSignData&params=${properties2Base64(params)}"
        }

        if (!preSignResult.isNullOrEmpty()) {
            prePostSignData = "$prePostSignData&session=$preSignResult"
        }

        return prePostSignData.toRequestBody("text/plain".toMediaTypeOrNull())
    }

    @Throws(IOException::class)
    fun properties2Base64(properties: Properties): String {
        val baos = ByteArrayOutputStream()
        val osw = OutputStreamWriter(baos, StandardCharsets.UTF_8)
        properties.store(osw, "")
        return encoder.encode(baos.toByteArray())
    }

    private suspend fun <T> processResponse(
        service: suspend () -> Response<T>
    ): Result<T> {
        return try {
            val response = service()
            if (response.isSuccessful) {
                response.body()?.let {
                    Result.success(it)
                } ?: run {
                    logger.e(TAG, "Error processing response ${response.message()}")
                    Result.failure(Exception(response.message()))
                }
            } else {
                logger.e(TAG, "Error processing response ${response.message()}")
                Result.failure(Exception(response.message()))
            }
        } catch (e: Exception) {
            logger.e(TAG, "Error processing response", e)
            Result.failure(e)
        }
    }

    @Throws(CertificateEncodingException::class)
    fun prepareCertChainParam(certChain: Array<Certificate>?, extraParams: Properties?): String {
        require(!certChain.isNullOrEmpty()) {
            "Cert chain cannot be null or empty"
        }
        if (extraParams == null || extraParams.getProperty(
                "includeOnlySigningCertificate",
                FALSE.toString()
            ).toBoolean()
        ) {
            return encoder.encode(certChain[0].encoded)
        }
        val sb = StringBuilder()
        for (cert in certChain) {
            sb.append(encoder.encode(cert.encoded))
            sb.append(",")
        }
        val ret = sb.toString()
        return ret.substring(
            0,
            ret.length - 1
        )
    }

    private fun getExtraParams(signType: SignType): Properties {
        return if (signType.value.uppercase(Locale.getDefault()) == SignType.COMMON.value) {
            Properties().apply {
                setProperty("mode", "implicit")
            }
        } else {
            Properties().apply {
                setProperty("policyIdentifierHash", "V8lVVNGDCPen6VELRD1Ja8HARFk=")
                setProperty("format", "XAdES Detached")
                setProperty("mode", "implicit")
                setProperty(
                    "policyDescription",
                    "Politica de firma electronica para las Administraciones Publicas en Espana"
                )
                setProperty("policyIdentifier", "urn:oid:2.16.724.1.3.1.1.2.1.8")
                setProperty(
                    "policyIdentifierHashAlgorithm",
                    "http://www.w3.org/2000/09/xmldsig#sha1"
                )
                setProperty(
                    "policyQualifier",
                    "http://administracionelectronica.gob.es/es/ctt/politicafirma/politica_firma_AGE_v1_8.pdf"
                )
            }
        }
    }

    companion object {
        private const val TAG = "TriPhaseSignerManager"
    }
}