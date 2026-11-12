import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'loyalo_auth_ui.dart';

/// En-tête fonctionnel sans marque ni illustration. Sa hauteur suit le titre.
class LoyaloPageHeader extends StatelessWidget {
  const LoyaloPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showBackButton = false,
    this.actions = const [],
    this.inverse = true,
    this.centerTitle = true,
    this.titleStyle,
  });
  final String title;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget> actions;
  final bool inverse;
  final bool centerTitle;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: inverse ? Colors.white : Theme.of(context).colorScheme.onSurface,
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ).merge(titleStyle);
    final heading = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
        child: Semantics(
          header: true,
          child: Text(
            title,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            softWrap: true,
            style: style,
          ),
        ),
      ),
    );
    final back = showBackButton
        ? inverse
              ? LoyaloAuthBackButton(onPressed: onBack)
              : IconButton(
                  tooltip: 'Retour',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            MediaQuery.textScalerOf(context).scale(16) > 23 ||
            (constraints.maxWidth < 330 && actions.isNotEmpty);
        final controls = actions.isEmpty
            ? null
            : _HeaderActions(actions: actions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stack) ...[
              if (back != null || controls != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?back,
                    if (controls != null)
                      Expanded(child: controls)
                    else
                      const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              heading,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (back != null) ...[back, const SizedBox(width: 8)],
                  Expanded(child: heading),
                  if (controls != null) ...[const SizedBox(width: 8), controls],
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Adaptateur du même modèle aux Scaffold existants. Les actions et le
/// comportement de retour restent ceux de l'AppBar native de l'application.
PreferredSizeWidget loyaloPageAppBar(
  BuildContext context, {
  required Text title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? actionsWidth,
}) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final width = MediaQuery.sizeOf(context).width;
  final items = actions ?? const <Widget>[];
  final hasLeading =
      leading != null ||
      (automaticallyImplyLeading &&
          (ModalRoute.of(context)?.impliesAppBarDismissal ??
              Navigator.of(context).canPop()));
  final textActionScale = scaler.scale(14) / 14;
  final actionWidth = actionsWidth != null
      ? actionsWidth * (items.any(_containsTextAction) ? textActionScale : 1)
      : items.fold<double>(
          0,
          (width, item) =>
              width + (_containsTextAction(item) ? 96 * textActionScale : 48),
        );
  final stacked =
      items.isNotEmpty &&
      (scaler.scale(16) > 23 ||
          actionWidth + (hasLeading ? 56 : 0) + 112 > width);
  final style =
      (theme.appBarTheme.titleTextStyle ??
              theme.textTheme.titleLarge ??
              const TextStyle(fontSize: 18))
          .merge(title.style);
  final available = math.max(
    24.0,
    width - 32 - (hasLeading ? 56 : 0) - (stacked ? 0 : actionWidth),
  );
  final painter = TextPainter(
    text: TextSpan(
      text: title.data ?? title.textSpan?.toPlainText() ?? '',
      style: style,
    ),
    textDirection: Directionality.of(context),
    textScaler: scaler,
  )..layout(maxWidth: available);
  final height = math.max(kToolbarHeight, painter.height + 16);
  painter.dispose();
  final actionHeight = items.any(_containsTextAction)
      ? math.max(48.0, scaler.scale(18) * 1.5 + 24)
      : 48.0;
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    toolbarHeight: height,
    titleSpacing: 16,
    title: MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: DefaultTextStyle(
        style: style.copyWith(inherit: false),
        softWrap: true,
        overflow: TextOverflow.visible,
        child: title,
      ),
    ),
    actions: stacked ? null : actions,
    bottom: stacked
        ? PreferredSize(
            preferredSize: Size.fromHeight(actionHeight),
            child: SizedBox(
              height: actionHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _HeaderActions(actions: items),
              ),
            ),
          )
        : null,
  );
}

bool _containsTextAction(Widget widget) {
  if (widget is TextButton || widget is PopupMenuButton) return true;
  if (widget is Padding) return _containsTextAction(widget.child!);
  if (widget is Center && widget.child != null) {
    return _containsTextAction(widget.child!);
  }
  return false;
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.actions});
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    ),
  );
}
