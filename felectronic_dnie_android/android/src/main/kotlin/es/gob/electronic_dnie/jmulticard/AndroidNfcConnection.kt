package es.gob.electronic_dnie.jmulticard

import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.util.Log
import es.gob.jmulticard.HexUtils
import es.gob.jmulticard.apdu.ResponseApdu
import es.gob.jmulticard.apdu.dnie.VerifyApduCommand
import es.gob.jmulticard.connection.AbstractApduConnectionIso7816
import es.gob.jmulticard.connection.ApduConnection
import es.gob.jmulticard.connection.ApduConnectionException
import es.gob.jmulticard.connection.ApduConnectionProtocol
import java.io.IOException

private const val TAG = "AndroidNfcConnection"
private const val ISODEP_TIMEOUT = 3000
private const val DEBUG = true

class AndroidNfcConnection(tag: Tag?) : AbstractApduConnectionIso7816() {
    private val mIsoDep: IsoDep?

    init {
        requireNotNull(tag) {
            "El tag NFC no puede ser nulo"
        }
        mIsoDep = IsoDep.get(tag)
        mIsoDep.connect()
        mIsoDep.timeout = ISODEP_TIMEOUT
    }

    @Throws(ApduConnectionException::class)
    public override fun internalTransmit(apdu: ByteArray): ResponseApdu {
        if (mIsoDep == null) {
            throw ApduConnectionException("No se puede transmitir sobre una conexion NFC cerrada")
        }
        val isChv = apdu[1] == VerifyApduCommand.INS_VERIFY
        if (DEBUG) {
            val apduLog = if (isChv) {
                "Verificacion de PIN"
            } else {
                HexUtils.hexify(apdu, apdu.size > 32)
            }
            Log.d(
                TAG,
                "Se va a enviar la APDU:$apduLog".trimIndent()
            )
        }

        val bResp: ByteArray = try {
            mIsoDep.transceive(apdu)
        } catch (e: IOException) {
            val apduError = if (isChv) {
                "Verificacion de PIN"
            } else {
                HexUtils.hexify(apdu, apdu.size > 32)
            }
            throw ApduConnectionException(
                "Error tratando de transmitir la APDU: $apduError".trimIndent(),
                e
            )
        }
        val response = ResponseApdu(bResp)
        if (DEBUG) {
            Log.d(
                TAG,
                "Respuesta: ${HexUtils.hexify(response.bytes, bResp.size > 32)}".trimIndent()
            )
        }
        return response
    }

    @Throws(ApduConnectionException::class)
    override fun open() {
        try {
            if (!mIsoDep!!.isConnected) {
                mIsoDep.connect()
            }
        } catch (e: Exception) {
            throw ApduConnectionException(
                "Error intentando abrir la comunicacion NFC contra la tarjeta",
                e
            )
        }
    }

    @Throws(ApduConnectionException::class)
    override fun close() {
        try {
            mIsoDep!!.close()
        } catch (ioe: IOException) {
            throw ApduConnectionException(
                "Error indefinido cerrando la conexion con la tarjeta",
                ioe
            )
        }
    }

    @Throws(ApduConnectionException::class)
    override fun reset(): ByteArray {
        if (mIsoDep != null) {
            return if (mIsoDep.historicalBytes != null) {
                mIsoDep.historicalBytes
            } else {
                mIsoDep.hiLayerResponse
            }
        }
        throw ApduConnectionException(
            "Error indefinido reiniciando la conexion con la tarjeta"
        )
    }

    override fun getTerminals(onlyWithCardPresent: Boolean): LongArray {
        return longArrayOf(0)
    }

    override fun getTerminalInfo(terminal: Int): String {
        return "Interfaz ISO-DEP NFC de Android"
    }

    override fun setTerminal(t: Int) {}

    override fun isOpen(): Boolean {
        return mIsoDep!!.isConnected
    }

    override fun setProtocol(p: ApduConnectionProtocol) {}

    override fun getSubConnection(): ApduConnection? {
        return null
    }

    override fun getMaxApduSize(): Int {
        return 0xff
    }
}
