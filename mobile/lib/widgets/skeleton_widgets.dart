import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kSkeletonBase = Color(0xFFE8E6DF);
const _kSkeletonHighlight = Color(0xFFF5F4F0);

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final bool enabled;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
    this.enabled = true,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(1.0 + _animation.value, 0),
              colors: const [_kSkeletonBase, _kSkeletonHighlight, _kSkeletonBase],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({super.key, required this.size, this.margin});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      borderRadius: size / 2,
      margin: margin,
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonText({
    super.key,
    required this.width,
    this.height = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: 4,
      margin: margin,
    );
  }
}

class SkeletonButton extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonButton({super.key, this.width, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width ?? double.infinity,
      height: height,
      borderRadius: 10,
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final int lines;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const SkeletonCard({
    super.key,
    this.lines = 3,
    this.height,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(lines, (i) {
          final isLast = i == lines - 1;
          return SkeletonText(
            width: isLast ? 120 : double.infinity,
            margin: EdgeInsets.only(bottom: i < lines - 1 ? 10 : 0),
          );
        }),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry? padding;
  final bool showAvatar;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(12),
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar) ...[
                const SkeletonCircle(size: 40),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(
                      width: 140 + (index % 3) * 40.0,
                      height: 14,
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    SkeletonText(
                      width: double.infinity,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 6),
                    ),
                    SkeletonText(width: 200, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const SkeletonCard(lines: 3);
      },
    );
  }
}

class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SkeletonCircle(size: 80),
          const SizedBox(height: 16),
          SkeletonText(width: 160, height: 16, margin: const EdgeInsets.only(bottom: 8)),
          SkeletonText(width: 200, height: 12),
          const SizedBox(height: 24),
          SkeletonCard(lines: 2, height: 80),
          const SizedBox(height: 12),
          SkeletonCard(lines: 3, height: 120),
        ],
      ),
    );
  }
}

class SkeletonPulse extends StatefulWidget {
  final Widget child;

  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(opacity: _animation.value, child: widget.child);
      },
    );
  }
}

class SkeletonLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const SkeletonLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _IndicatorPainter(
            color: color ?? const Color(0xFFE24B4A),
          ),
        ),
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  final Color color;

  _IndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, radius * 0.8, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
