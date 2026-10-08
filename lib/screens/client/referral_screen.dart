import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/referral.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loyalo_ui.dart';
import 'referrals_list_screen.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code parrain copié !')));
  }

  void _openShareSheet(BuildContext context, WidgetRef ref, String code) {
    final message =
        'Rejoins-moi sur Loyalo et gagne des récompenses dans tes restaurants '
        'préférés. Utilise mon code $code à l\'inscription.';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Partager mon lien',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12.5,
                ),
              ),
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

  Future<void> _finishShare(
    BuildContext sheetContext,
    BuildContext pageContext,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    if (!pageContext.mounted) return;
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(
        content: Text('Lien de parrainage copié, prêt à partager !'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.watch(loyaltyRepositoryProvider);
    final referrals = repo.referralsFor(user.id);
    final rewarded = referrals
        .where((referral) => referral.status == ReferralStatus.rewarded)
        .length;
    final pending = referrals
        .where((referral) => referral.status == ReferralStatus.pending)
        .length;
    final points = referrals.fold<int>(
      0,
      (sum, referral) => sum + referral.pointsEarned,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Parrainage')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              color: AppColors.lavender.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const Positioned(
                  top: 24,
                  right: 36,
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.orange,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Invitez vos amis\net gagnez des points !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous gagnez 500 points à chaque filleul qui effectue sa première visite.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
          const SizedBox(height: 28),
          LoyaloCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Votre code parrain',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _copyCode(context, user.referralCode),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.referralCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.textGray,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LoyaloGradientButton(
            label: 'Partager mon code',
            onPressed: () => _openShareSheet(context, ref, user.referralCode),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ReferralStat(
                  label: 'Mes filleuls',
                  value: '${referrals.length}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ReferralStat(label: 'En attente', value: '$pending'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReferralStat(label: 'Validés', value: '$rewarded'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ReferralStat(
                  label: 'Points gagnés',
                  value: '$points pts',
                ),
              ),
            ],
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
    );
  }
}

class _ReferralStat extends StatelessWidget {
  final String label;
  final String value;

  const _ReferralStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LoyaloCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
