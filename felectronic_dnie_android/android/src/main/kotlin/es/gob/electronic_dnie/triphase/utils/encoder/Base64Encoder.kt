package es.gob.electronic_dnie.triphase.utils.encoder

interface Base64Encoder {
    fun encode(bytes: ByteArray): String
    fun decode(string: String): ByteArray
}