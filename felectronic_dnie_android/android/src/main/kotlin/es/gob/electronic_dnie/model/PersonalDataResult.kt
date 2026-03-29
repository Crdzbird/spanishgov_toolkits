package es.gob.electronic_dnie.model

data class PersonalDataResult(
    val fullName: String,
    val givenName: String,
    val surnames: String,
    val nif: String,
    val country: String,
    val certificateType: String
)
