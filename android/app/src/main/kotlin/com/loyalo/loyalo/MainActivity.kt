package com.loyalo.loyalo

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (et non FlutterActivity) est requis par local_auth
// pour afficher l'invite Face ID / empreinte digitale sur Android.
class MainActivity : FlutterFragmentActivity()
