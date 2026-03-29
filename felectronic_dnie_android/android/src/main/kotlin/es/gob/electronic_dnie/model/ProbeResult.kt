package es.gob.electronic_dnie.model

data class ProbeResult(
    val isValidDnie: Boolean,
    val atrHex: String,
    val tagId: String
)
