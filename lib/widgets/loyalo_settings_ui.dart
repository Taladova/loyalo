import 'package:flutter/material.dart';

import 'loyalo_auth_ui.dart';
import 'loyalo_page_header.dart';
import 'loyalo_ui.dart';

class LoyaloSettingsFrame extends StatelessWidget {
  const LoyaloSettingsFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => LoyaloAuthScaffold(
    showBackButton: false,
    onBack: onBack,
    headerBuilder: (context, compact, veryCompact) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: LoyaloPageHeader(
        title: title,
        centerTitle: false,
        showBackButton: true,
        onBack: onBack,
      ),
    ),
    contentBuilder: (context, compact) => child,
  );
}

class LoyaloSettingsSection extends StatelessWidget {
  const LoyaloSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.danger = false,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        LoyaloCard(
          padding: EdgeInsets.zero,
          color: danger ? const Color(0xFFFFF0F4) : Colors.white,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 14,
                    color: Color(0xFFDCE3F0),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class LoyaloSettingsItem extends StatelessWidget {
  const LoyaloSettingsItem({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.subtitle,
    this.detail,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.danger = false,
  });
  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Widget? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final end =
        trailing ??
        (onTap == null
            ? null
            : const ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  color: LoyaloAuthColors.textSecondary,
                ),
              ));
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = MediaQuery.textScalerOf(context).scale(14) > 22;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: danger ? color : LoyaloAuthColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: LoyaloAuthColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              if (detail != null) ...[const SizedBox(height: 4), detail!],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: LoyaloIconBadge(icon: icon, color: color, size: 36),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  if (end != null && !stacked) ...[
                    const SizedBox(width: 8),
                    end,
                  ],
                ],
              ),
              if (end != null && stacked) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: end),
              ],
            ],
          );
        },
      ),
    );
    return onTap == null
        ? body
        : InkWell(onTap: enabled ? onTap : null, child: body);
  }
}
