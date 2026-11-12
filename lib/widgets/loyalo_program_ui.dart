import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/restaurant.dart';
import 'loyalo_auth_ui.dart';
import 'loyalo_page_header.dart';
import 'loyalo_ui.dart';

class LoyaloProgramHeader extends StatelessWidget {
  const LoyaloProgramHeader({
    super.key,
    required this.draft,
    required this.compact,
    required this.veryCompact,
    required this.onBack,
  });

  final bool draft;
  final bool compact;
  final bool veryCompact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 12 : 16),
    child: Column(
      children: [
        LoyaloPageHeader(
          title: 'Configurer mon programme',
          onBack: onBack,
          showBackButton: true,
        ),
        const SizedBox(height: 8),
        Text(
          draft
              ? 'Votre commerce reste en brouillon. Configurez votre programme de fidélité pour activer et publier votre commerce.'
              : 'Configurez les paramètres et la récompense de votre programme de fidélité.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class LoyaloSectionHeader extends StatelessWidget {
  const LoyaloSectionHeader(this.title, {super.key, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: LoyaloAuthColors.purple, size: 25),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: LoyaloAuthColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class LoyaloProgramSection extends StatelessWidget {
  const LoyaloProgramSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LoyaloSectionHeader(title, icon: icon),
      const SizedBox(height: 10),
      LoyaloCard(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    ],
  );
}

class LoyaloSegmentedControl<T> extends StatelessWidget {
  const LoyaloSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });
  final List<ButtonSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var width = 0.0;
      for (final segment in segments) {
        final text = segment.label;
        final painter = TextPainter(
          text: TextSpan(
            text: text is Text ? text.data : '',
            style: DefaultTextStyle.of(context).style.merge(
              const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        width = math.max(width, painter.width + 56);
        painter.dispose();
      }
      return SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          direction: width * segments.length <= constraints.maxWidth
              ? Axis.horizontal
              : Axis.vertical,
          segments: segments,
          selected: {value},
          showSelectedIcon: true,
          selectedIcon: const Icon(Icons.check_rounded, size: 19),
          onSelectionChanged: onChanged == null
              ? null
              : (values) => onChanged!(values.first),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? LoyaloAuthColors.purple.withValues(alpha: 0.12)
                  : Colors.white,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? LoyaloAuthColors.textSecondary
                  : states.contains(WidgetState.selected)
                  ? LoyaloAuthColors.purple
                  : LoyaloAuthColors.textPrimary,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFD5DEED)),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      );
    },
  );
}

class LoyaloProgramField extends StatelessWidget {
  const LoyaloProgramField({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: LoyaloAuthColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Semantics(label: label, child: child),
    ],
  );
}

class LoyaloNumericSelector extends StatelessWidget {
  const LoyaloNumericSelector({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.validator,
    required this.onChanged,
    required this.icon,
    this.enabled = true,
  });
  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final bool enabled;

  int? nextValue(int step) {
    final current = int.tryParse(controller.text);
    if (current == null || current < 1) return null;
    final next = current + step;
    if (next < 1 || (step > 0 && next <= current)) return null;
    return next;
  }

  void change(int value) {
    controller.value = TextEditingValue(
      text: '$value',
      selection: TextSelection.collapsed(offset: '$value'.length),
    );
    onChanged(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    Widget step(int delta, IconData icon, String action) {
      final next = nextValue(delta);
      return IconButton.outlined(
        tooltip: '$action : $label',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: LoyaloAuthColors.purple,
          side: BorderSide(
            color: LoyaloAuthColors.purple.withValues(alpha: 0.25),
          ),
        ),
        onPressed: enabled && next != null ? () => change(next) : null,
        icon: Icon(icon, size: 23),
      );
    }

    final field = LoyaloAuthTextField(
      key: fieldKey,
      controller: controller,
      validator: validator,
      hintText: '',
      prefixIcon: icon,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      enabled: enabled,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: step(-1, Icons.remove_rounded, 'Diminuer'),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: step(1, Icons.add_rounded, 'Augmenter'),
        ),
      ],
    );
    return LoyaloProgramField(
      label: label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(16) > 22.4) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 6),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class LoyaloProgramPreview extends StatelessWidget {
  const LoyaloProgramPreview({
    super.key,
    required this.enabled,
    required this.type,
    required this.current,
    required this.threshold,
    required this.remaining,
    required this.pointsPerVisit,
    required this.rewardLabel,
  });
  final bool enabled;
  final LoyaltyProgramType type;
  final int current;
  final int threshold;
  final int remaining;
  final int pointsPerVisit;
  final String rewardLabel;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const Text(
        'Ce commerce n’a pas encore activé son programme de fidélité.',
        style: TextStyle(color: LoyaloAuthColors.textSecondary, fontSize: 13),
      );
    }
    final unit = type == LoyaltyProgramType.points ? 'points' : 'visites';
    final intro = type == LoyaltyProgramType.points
        ? '1 visite = +$pointsPerVisit pts · objectif $threshold points'
        : '$threshold visites = 1 récompense';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 46,
            height: 62,
            decoration: BoxDecoration(
              color: LoyaloAuthColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFB800),
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Votre programme',
                style: TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                intro,
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$current / $threshold $unit',
                key: const Key('program-preview-progress'),
                style: const TextStyle(
                  color: LoyaloAuthColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: current / threshold,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE5E9F2),
                  color: LoyaloAuthColors.turquoise,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rewardLabel.trim().isEmpty
                    ? 'Encore $remaining $unit avant votre récompense !'
                    : 'Encore $remaining $unit avant : $rewardLabel',
                key: const Key('program-preview-reward'),
                style: const TextStyle(
                  color: LoyaloAuthColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
