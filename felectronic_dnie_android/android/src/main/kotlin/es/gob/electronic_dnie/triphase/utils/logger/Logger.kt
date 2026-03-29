package es.gob.electronic_dnie.triphase.utils.logger


interface Logger {
    fun d(tag: String, message: String)
    fun e(tag: String, message: String, throwable: Throwable? = null)
}