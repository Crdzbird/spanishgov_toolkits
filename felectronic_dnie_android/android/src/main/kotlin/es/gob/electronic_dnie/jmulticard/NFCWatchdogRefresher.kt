package es.gob.electronic_dnie.jmulticard

import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import java.lang.ref.WeakReference

private const val TAG = "NFCWatchdogRefresher"

internal object NFCWatchdogRefresher {

    private const val TECHNOLOGY_ISO_DEP = 3
    private var sHandlerThread: HandlerThread? = null
    private var sHandler: Handler? = null
    private var sRefresher: WatchdogRefresher? = null

    @Volatile
    var sIsRunning = false

    fun holdConnection(isoDep: IsoDep?) {
        Log.v(TAG, "holdConnection()")
        if (sHandlerThread != null || sHandler != null || sRefresher != null) {
            Log.d(
                TAG,
                "holdConnection(): Existing background thread found, stopping!"
            )
            stopHoldingConnection()
        }
        sHandlerThread = HandlerThread("NFCWatchdogRefresherThread")
        try {
            sHandlerThread!!.start()
        } catch (e: IllegalThreadStateException) {
            Log.d(TAG, "holdConnection(): Failed starting background thread!", e)
        }
        val looper = sHandlerThread!!.looper
        sHandler = if (looper != null) {
            Handler(looper)
        } else {
            Log.d(TAG, "holdConnection(): No looper on background thread!")
            sHandlerThread!!.quit()
            Handler(Looper.getMainLooper())
        }
        sIsRunning = true
        sRefresher = WatchdogRefresher(sHandler, isoDep)
        sHandler!!.post(sRefresher!!)
    }

    fun stopHoldingConnection() {
        Log.v(TAG, "stopHoldingConnection()")
        sIsRunning = false
        if (sHandler != null) {
            if (sRefresher != null) {
                sHandler!!.removeCallbacks(sRefresher!!)
            }
            sHandler!!.removeCallbacksAndMessages(null)
            sHandler = null
        }
        if (sRefresher != null) {
            sRefresher = null
        }
        if (sHandlerThread != null) {
            sHandlerThread!!.quit()
            sHandlerThread = null
        }
    }

    private class WatchdogRefresher(handler: Handler?, isoDep: IsoDep?) :
        Runnable {
        private val mHandler: WeakReference<Handler?>
        private val mIsoDep: WeakReference<IsoDep?>
        private var mCurrentRuntime = 0

        init {
            mHandler = WeakReference(handler)
            mIsoDep = WeakReference(isoDep)
        }

        override fun run() {
            val tag = tag
            if (tag != null) {
                try {
                    val getTagService = Tag::class.java.getMethod("getTagService")
                    val tagService = getTagService.invoke(tag)
                    val getServiceHandle =
                        Tag::class.java.getMethod("getServiceHandle")
                    val serviceHandle = getServiceHandle.invoke(tag)
                    val connect = tagService.javaClass.getMethod(
                        "connect",
                        Int::class.javaPrimitiveType,
                        Int::class.javaPrimitiveType
                    )
                    val result = connect.invoke(
                        tagService,
                        serviceHandle,
                        Integer.valueOf(TECHNOLOGY_ISO_DEP)
                    )
                    val handler = handler
                    if (result != null && result == Integer.valueOf(0) && handler != null &&
                        sIsRunning && mCurrentRuntime < RUNTIME_MAX
                    ) {
                        handler.postDelayed(this, INTERVAL.toLong())
                        mCurrentRuntime += INTERVAL
                        Log.v(TAG, "Told NFC Watchdog to wait")
                    } else {
                        Log.d(TAG, "result: $result")
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "WatchdogRefresher.run()", e)
                }
            }
        }

        private val handler: Handler?
            get() = mHandler.get()
        private val tag: Tag?
            get() {
                val isoDep = mIsoDep.get()
                return isoDep?.tag
            }

        companion object {
            private const val INTERVAL = 100
            private const val RUNTIME_MAX = 30 * 1000
        }
    }
}
