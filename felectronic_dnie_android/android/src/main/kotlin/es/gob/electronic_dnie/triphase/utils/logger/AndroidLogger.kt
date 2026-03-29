package es.gob.electronic_dnie.triphase.utils.logger

import android.util.Log

class AndroidLogger(private val debug: Boolean = false) : Logger {

    override fun d(tag: String, message: String) {
        if (debug) {
            Log.d(tag, message)
        }
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        if (debug) {
            Log.e(tag, message, throwable)
        }
    }

}