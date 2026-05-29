// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isGradient;
  final bool isOutlined;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isGradient = false,
    this.isOutlined = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidget = SizedBox(
      width: width ?? double.infinity,
      height: 90,
      child: isOutlined
          ? OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E88E5),
          ),
        ),
      )
          : ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isGradient ? null : const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          shadowColor: Colors.black26,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                (states) {
              if (isGradient) return null; // Use gradient
              return const Color(0xFF1E88E5);
            },
          ),
        ),
        child: isGradient
            ? Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A2E5C), Color(0xFF1E88E5)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return buttonWidget;
  }
}