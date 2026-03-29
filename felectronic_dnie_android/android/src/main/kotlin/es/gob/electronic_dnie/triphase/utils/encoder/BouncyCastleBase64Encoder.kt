package es.gob.electronic_dnie.triphase.utils.encoder

import org.bouncycastle.util.encoders.Base64

class BouncyCastleBase64Encoder : Base64Encoder {
    override fun encode(bytes: ByteArray): String = Base64.toBase64String(bytes)
    override fun decode(string: String): ByteArray = Base64.decode(string)
}