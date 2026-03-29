package es.gob.electronic_dnie.model

data class DniSignerResponse(
    val signedData: ByteArray,
    val base64signedData: String,
    val base64certificate: String
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as DniSignerResponse

        if (!signedData.contentEquals(other.signedData)) return false
        if (base64signedData != other.base64signedData) return false
        if (base64certificate != other.base64certificate) return false

        return true
    }

    override fun hashCode(): Int {
        var result = signedData.contentHashCode()
        result = 31 * result + base64signedData.hashCode()
        result = 31 * result + base64certificate.hashCode()
        return result
    }
}