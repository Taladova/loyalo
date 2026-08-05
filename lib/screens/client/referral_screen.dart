import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import 'referrals_list_screen.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code parrain copié !')),
    );
  }

  void _openShareSheet(BuildContext context, WidgetRef ref, String code) {
    final message = 'Rejoins-moi sur Loyalo et gagne des récompenses dans tes restaurants '
        'préférés ! Utilise mon code $code à l\'inscription 🎁';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Partager mon lien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: AppColors.textGray, fontSize: 12.5)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ShareOption(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    color: AppColors.teal,
                    onTap: () => _finishShare(sheetContext, context, message),
                  ),
                  _ShareOption(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: AppColors.blue,
                    onTap: () => _finishShare(sheetContext, context, message),
                  ),
                  _ShareOption(
                    icon: Icons.link,
                    label: 'Copier',
                    color: AppColors.purple,
                    onTap: () => _finishShare(sheetContext, context, message),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishShare(BuildContext sheetContext, BuildContext pageContext, String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    if (!pageContext.mounted) return;
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Lien de parrainage copié, prêt à partager !')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Parrainage')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard, color: AppColors.purple, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Invitez vos amis et gagnez des avantages !',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Vous gagnez 500 points à chaque filleul qui effectue sa première visite.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray, fontSize: 13),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text('Votre code parrain', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _copyCode(context, user.referralCode),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(user.referralCode,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy, size: 16, color: AppColors.textGray),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _openShareSheet(context, ref, user.referralCode),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Partager mon lien'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReferralsListScreen()),
              ),
              child: const Text('Voir mes filleuls'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
