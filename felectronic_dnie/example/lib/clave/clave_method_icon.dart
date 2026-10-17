import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter/material.dart';

/// An icon for each way of signing in to Cl@ve.
extension ClaveMethodIcon on ClaveAuthMethod {
  IconData get icon => switch (this) {
    ClaveAuthMethod.clavePin => Icons.pin,
    ClaveAuthMethod.clavePermanente => Icons.lock,
    ClaveAuthMethod.electronicCertificate => Icons.badge,
    ClaveAuthMethod.stork => Icons.public,
    ClaveAuthMethod.europeanCredential => Icons.language,
    ClaveAuthMethod.claveMovil => Icons.phone_android,
  };
}
