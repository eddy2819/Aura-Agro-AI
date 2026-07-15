import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AuraBrandLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AuraBrandLogo({super.key, this.size = 48, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _AuraMarkPainter(),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * .18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AURA',
              style: TextStyle(
                fontSize: size * .42,
                height: .9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.primaryGreenDark,
              ),
            ),
            Text(
              'Agro AI',
              style: TextStyle(
                fontSize: size * .20,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuraMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFF08752D);
    final dark = Paint()..color = const Color(0xFF075B28);
    final gold = Paint()..color = const Color(0xFFD9A51E);
    final stroke = Paint()
      ..color = const Color(0xFF08752D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .055
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: size.width * .43),
      math.pi * .62,
      math.pi * 1.18,
      false,
      stroke,
    );

    final leaf = Path()
      ..moveTo(size.width * .54, size.height * .25)
      ..quadraticBezierTo(
        size.width * .75,
        size.height * .03,
        size.width * .88,
        size.height * .08,
      )
      ..quadraticBezierTo(
        size.width * .91,
        size.height * .31,
        size.width * .65,
        size.height * .39,
      )
      ..quadraticBezierTo(
        size.width * .58,
        size.height * .36,
        size.width * .54,
        size.height * .25,
      );
    canvas.drawPath(leaf, green);
    canvas.drawLine(
      Offset(size.width * .58, size.height * .34),
      Offset(size.width * .80, size.height * .15),
      Paint()
        ..color = Colors.white
        ..strokeWidth = size.width * .025,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .53, size.height * .55),
        width: size.width * .48,
        height: size.height * .26,
      ),
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * .29, size.height * .50),
      size.width * .10,
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * .23, size.height * .45),
      size.width * .035,
      dark,
    );
    canvas.drawCircle(
      Offset(size.width * .35, size.height * .44),
      size.width * .035,
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .39,
        size.height * .61,
        size.width * .055,
        size.height * .17,
      ),
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .66,
        size.height * .61,
        size.width * .055,
        size.height * .17,
      ),
      dark,
    );
    canvas.drawLine(
      Offset(size.width * .76, size.height * .51),
      Offset(size.width * .83, size.height * .42),
      Paint()
        ..color = dark.color
        ..strokeWidth = size.width * .035
        ..strokeCap = StrokeCap.round,
    );

    final field = Path()
      ..moveTo(size.width * .10, size.height * .75)
      ..quadraticBezierTo(
        size.width * .43,
        size.height * .63,
        size.width * .90,
        size.height * .70,
      )
      ..quadraticBezierTo(
        size.width * .62,
        size.height * .82,
        size.width * .20,
        size.height * .91,
      )
      ..close();
    canvas.drawPath(field, gold);
    canvas.drawLine(
      Offset(size.width * .28, size.height * .82),
      Offset(size.width * .73, size.height * .70),
      Paint()
        ..color = Colors.white
        ..strokeWidth = size.width * .035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
