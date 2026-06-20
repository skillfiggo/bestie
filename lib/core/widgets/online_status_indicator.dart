import 'package:flutter/material.dart';
import 'package:bestie/core/enums/online_status.dart';

/// A widget that displays an online status indicator as a colored circle
/// with smooth animated transitions between states
class OnlineStatusIndicator extends StatelessWidget {
  final OnlineStatus status;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final Duration animationDuration;

  const OnlineStatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
    this.showBorder = true,
    this.borderColor,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.color,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: size * 0.15,
              )
            : null,
      ),
    );
  }
}

/// A widget that positions a status indicator on top of another widget (typically an avatar)
class StatusBadge extends StatelessWidget {
  final Widget child;
  final OnlineStatus status;
  final double indicatorSize;
  final bool showBorder;
  final Color? borderColor;
  final AlignmentGeometry alignment;

  const StatusBadge({
    super.key,
    required this.child,
    required this.status,
    this.indicatorSize = 12,
    this.showBorder = true,
    this.borderColor,
    this.alignment = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: OnlineStatusIndicator(
              status: status,
              size: indicatorSize,
              showBorder: showBorder,
              borderColor: borderColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// A widget that displays the online status indicator with last seen text
class StatusWithText extends StatelessWidget {
  final OnlineStatus status;
  final String lastSeenText;
  final double indicatorSize;
  final TextStyle? textStyle;
  final double spacing;

  const StatusWithText({
    super.key,
    required this.status,
    required this.lastSeenText,
    this.indicatorSize = 10,
    this.textStyle,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey.shade600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnlineStatusIndicator(
          status: status,
          size: indicatorSize,
          showBorder: false,
        ),
        SizedBox(width: spacing),
        Text(
          lastSeenText,
          style: textStyle ?? defaultTextStyle,
        ),
      ],
    );
  }
}
