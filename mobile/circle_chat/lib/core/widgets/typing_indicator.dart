import 'package:flutter/material.dart';

class TypingIndicatorBubble extends StatefulWidget {
  final String? userName;

  const TypingIndicatorBubble({super.key, this.userName});

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE9E9EB);
    final dotColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.userName != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  '${widget.userName} is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final delay = index * 0.2;
                      final progress = (_controller.value - delay) % 1.0;
                      final bounce = (progress >= 0 && progress <= 0.5)
                          ? (progress < 0.25 ? progress * 4 : (0.5 - progress) * 4)
                          : 0.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 7,
                        height: 7,
                        transform: Matrix4.translationValues(0, -bounce * 4, 0),
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
