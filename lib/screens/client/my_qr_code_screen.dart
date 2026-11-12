import 'package:flutter/material.dart';

import '../../widgets/loyalo_auth_ui.dart';
import '../../widgets/loyalo_page_header.dart';
import '../../widgets/loyalo_visit_validation_ui.dart';

/// Écran préparé sans émission locale de jeton ni appel à un backend non activé.
class MyQrCodeScreen extends StatelessWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) => LoyaloAuthScaffold(
    onBack: () => Navigator.of(context).maybePop(),
    showBackButton: false,
    headerBuilder: (context, compact, veryCompact) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: LoyaloPageHeader(
        title: 'Mon QR code',
        showBackButton: Navigator.of(context).canPop(),
        onBack: () => Navigator.of(context).maybePop(),
      ),
    ),
    contentBuilder: (context, compact) => LoyaloVisitQrUnavailable(
      client: true,
      onCode: () => Navigator.of(context).maybePop(),
    ),
  );
}
