import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoyaloGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const LoyaloGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.brandGradient,
        color: disabled ? AppColors.lightGray : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoyaloCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadiusGeometry borderRadius;

  const LoyaloCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTheme.isDark(context) ? 0.16 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: color ?? AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: AppTheme.borderOf(context).withValues(alpha: 0.65),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class LoyaloIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const LoyaloIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.purple,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class LoyaloNetworkImage extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  final BorderRadiusGeometry borderRadius;
  final BoxFit fit;
  final double? width;
  final double? height;

  const LoyaloNetworkImage({
    super.key,
    required this.url,
    this.fallbackIcon = Icons.storefront_outlined,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null || imageUrl.isEmpty
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: Icon(fallbackIcon, color: Colors.white, size: 28),
              )
            : Image.network(
                imageUrl,
                fit: fit,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                  ),
                  child: Icon(fallbackIcon, color: Colors.white, size: 28),
                ),
              ),
      ),
    );
  }
}

class LoyaloMerchantAvatar extends StatelessWidget {
  final String? imageUrl;
  final IconData icon;
  final double size;

  const LoyaloMerchantAvatar({
    super.key,
    required this.imageUrl,
    required this.icon,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return LoyaloNetworkImage(
      url: imageUrl,
      fallbackIcon: icon,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size * 0.28),
    );
  }
}
