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

    fun startScan(
        activity: Activity?,
        timeout: Long,
        onSuccess: (Tag) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        // Init nfc adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
        Log.i(TAG, "NFC Adapter obtained: $nfcAdapter")

        // Start NFC scan using ReaderCallback
        val readerCallback = NfcAdapter.ReaderCallback { tag ->
            onSuccess(tag)
        }

        nfcAdapter?.enableReaderMode(activity, readerCallback, NfcAdapter.FLAG_READER_NFC_B, null)
        Log.i(TAG, "Reader mode enabled")

        // Start timeout timer with coroutines
        startTimeoutTimer(activity, timeout, onError)
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
        timeout: Long,
        onError: (DSTimeoutException) -> Unit
    ) {
        timeoutJob = CoroutineScope(Dispatchers.IO).launch {
            val fixedTimeout = timeout.coerceIn(MIN_DEFAULT_TIMEOUT, MAX_DEFAULT_TIMEOUT)
            delay(fixedTimeout)
            stopScan(activity)
            onError(DSTimeoutException())
        }
    }

    companion object {
        private const val MIN_DEFAULT_TIMEOUT: Long = 3000
        private const val MAX_DEFAULT_TIMEOUT: Long = 30000
        private const val TAG: String = "NFCConnectionManager"
    }
}
