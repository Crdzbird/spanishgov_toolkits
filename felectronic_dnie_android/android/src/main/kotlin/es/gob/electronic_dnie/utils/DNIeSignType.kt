package es.gob.electronic_dnie.utils

import es.gob.jmulticard.card.dnie.Dnie

enum class DNIeSignType(val type: String) {
    SIGN(Dnie.CERT_ALIAS_SIGN),
    AUTH(Dnie.CERT_ALIAS_AUTH);
}
