package es.gob.electronic_dnie.managers

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.util.Log
import es.gob.electronic_dnie.utils.DSTimeoutException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class NFCConnectionManager {

    private var nfcAdapter: NfcAdapter? = null
    private var timeoutJob: Job? = null

    /**
     * Enables reader mode and waits up to [timeoutSeconds] for a card.
     *
     * The timeout only bounds the wait for a card. Once a tag is detected it
     * is cancelled, so a slow PACE handshake or signature is never cut off.
     */
    fun startScan(
        activity: Activity?,
        timeoutSeconds: Long,
        onSuccess: (Tag) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        Log.i(TAG, "NFC Adapter obtained: $nfcAdapter")

        val readerCallback = NfcAdapter.ReaderCallback { tag ->
            Log.i(TAG, "Tag detected: ${tag.techList.joinToString()}")
            timeoutJob?.cancel()
            onSuccess(tag)
        }

        nfcAdapter?.enableReaderMode(activity, readerCallback, READER_FLAGS, null)
        Log.i(TAG, "Reader mode enabled")

        startTimeoutTimer(activity, timeoutSeconds, onError)
        Log.i(TAG, "Timeout configured")
    }

    fun stopScan(activity: Activity?) {
        activity?.let {
            nfcAdapter?.disableReaderMode(it)
        }
        timeoutJob?.cancel()
    }

    private fun startTimeoutTimer(
        activity: Activity?,
        timeoutSeconds: Long,
        onError: (DSTimeoutException) -> Unit
    ) {
        timeoutJob?.cancel()
        timeoutJob = CoroutineScope(Dispatchers.IO).launch {
            val timeoutMillis = (timeoutSeconds * 1000)
                .coerceIn(MIN_DEFAULT_TIMEOUT, MAX_DEFAULT_TIMEOUT)
            delay(timeoutMillis)
            stopScan(activity)
            onError(DSTimeoutException())
        }
    }

    companion object {
        private const val MIN_DEFAULT_TIMEOUT: Long = 3000
        private const val MAX_DEFAULT_TIMEOUT: Long = 30000
        private const val TAG: String = "NFCConnectionManager"
        private const val READER_FLAGS: Int = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
    }
}
