package es.gob.electronic_dnie.triphase.adesp_signer.utils


import es.gob.electronic_dnie.triphase.utils.encoder.Base64Encoder
import java.nio.charset.StandardCharsets

fun String.normalizeBase64ForPreSign(): String {
    return this.replace("+", "-").replace("/", "_")
}

fun String.normalizeBase64ForSelfSign(): String {
    return this.replace("-", "+").replace("_", "/")
}

fun String.fromBase64(encoder: Base64Encoder): String? {
    return try {
        val decodedBytes = encoder.decode(this)
        String(decodedBytes, StandardCharsets.UTF_8)
    } catch (e: IllegalArgumentException) {
        null
    }
}

fun String.addPKCS1forPostSign(pkcs1: String): String {
    val startTag = "<param n=\"PRE\">"
    val endTag = "</param>"

    val rangeStart = this.indexOf(startTag)
    if (rangeStart != -1) {
        val rangeEnd = this.indexOf(endTag, rangeStart + startTag.length)
        if (rangeEnd != -1) {
            val indexEnd = rangeEnd + endTag.length
            val newEntry = this.substring(0, indexEnd) + "\n" + "<param n=\"PK1\">$pkcs1</param>" + "\n" + this.substring(indexEnd)
            return newEntry
        }
    }
    return this
}

fun String.base64Decode(encoder: Base64Encoder): ByteArray? {
    return try {
        encoder.decode(this)
    } catch (e: IllegalArgumentException) {
        null
    }
}

fun String.toBase64(encoder: Base64Encoder): String? {
    return try {
        val data = this.toByteArray(Charsets.UTF_8)
        encoder.encode(data)
    } catch (e: Exception) {
        null
    }
}