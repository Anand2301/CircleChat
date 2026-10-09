import 'package:flutter/material.dart';

class IosSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const IosSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Search',
    this.onClear,
  });

  @override
  State<IosSearchBar> createState() => _IosSearchBarState();
}

class _IosSearchBarState extends State<IosSearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasNow = widget.controller.text.isNotEmpty;
    if (hasNow != _hasText) {
      setState(() => _hasText = hasNow);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE9E9EB);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: iconColor,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                if (widget.onClear != null) {
                  widget.onClear!();
                } else if (widget.onChanged != null) {
                  widget.onChanged!('');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
