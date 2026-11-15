import 'package:flutter/material.dart';
import '../widgets/loyalo_auth_ui.dart';
import '../widgets/loyalo_secondary_scaffold.dart';
import '../widgets/loyalo_ui.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final paragraphs = content.trim().split('\n\n');
    final hasDate = paragraphs.first.startsWith('Dernière mise à jour');

    return LoyaloSecondaryScaffold(
      title: title,
      body: SingleChildScrollView(
        key: const Key('legal-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasDate) ...[
              Container(
                key: const ValueKey('legal-block-0'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: LoyaloAuthColors.purple.withValues(alpha: 0.05),
                  border: Border.all(
                    color: LoyaloAuthColors.purple.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: LoyaloAuthColors.purple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        paragraphs.first,
                        style: const TextStyle(
                          color: LoyaloAuthColors.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            LoyaloCard(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = hasDate ? 1 : 0; i < paragraphs.length; i++) ...[
                    if (i > (hasDate ? 1 : 0)) const SizedBox(height: 28),
                    _LegalBlock(
                      key: ValueKey('legal-block-$i'),
                      text: paragraphs[i],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalBlock extends StatelessWidget {
  const _LegalBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      color: LoyaloAuthColors.textSecondary,
      fontSize: 15,
      height: 1.7,
    );
    final separator = text.indexOf('\n');
    final heading = separator < 0 ? text : text.substring(0, separator);
    final hasHeading =
        separator > 0 &&
        heading == heading.toUpperCase() &&
        heading != heading.toLowerCase();

    if (!hasHeading) return Text(text, style: bodyStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: const TextStyle(
              color: LoyaloAuthColors.textPrimary,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(text.substring(separator + 1), style: bodyStyle),
      ],
    );
  }
}
