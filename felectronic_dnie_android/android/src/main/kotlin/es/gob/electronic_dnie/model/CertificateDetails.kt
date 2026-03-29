package es.gob.electronic_dnie.model

data class CertificateDetails(
    val subjectCommonName: String,
    val subjectSerialNumber: String,
    val issuerCommonName: String,
    val issuerOrganization: String,
    val notValidBefore: Long,
    val notValidAfter: Long,
    val serialNumber: String,
    val isCurrentlyValid: Boolean
)
