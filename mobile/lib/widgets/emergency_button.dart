import 'package:flutter/material.dart';

import '../widgets/skeleton_widgets.dart';
import '../widgets/auth_widgets.dart';

class EmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final String label;

  const EmergencyButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Activate emergency',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAuthRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: SkeletonLoadingIndicator(size: 18),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emergency, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
