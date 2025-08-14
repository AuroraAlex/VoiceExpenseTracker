import 'package:flutter/material.dart';

class CustomLogo extends StatelessWidget {
  final double size;
  final Color color;

  const CustomLogo({
    Key? key,
    this.size = 120,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: LogoPainter(color: color),
    );
  }
}

class LogoPainter extends CustomPainter {
  final Color color;

  LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    
    // 麦克风主体 - 圆角矩形
    final micRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 10),
        width: 16,
        height: 28,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(micRect, paint);

    // 麦克风底座 - 弧形
    final path = Path();
    path.moveTo(center.dx - 15, center.dy + 8);
    path.quadraticBezierTo(
      center.dx - 15, center.dy + 23,
      center.dx, center.dy + 23,
    );
    path.quadraticBezierTo(
      center.dx + 15, center.dy + 23,
      center.dx + 15, center.dy + 8,
    );
    canvas.drawPath(path, strokePaint);

    // 麦克风支架
    canvas.drawLine(
      Offset(center.dx, center.dy + 23),
      Offset(center.dx, center.dy + 33),
      strokePaint,
    );

    // 麦克风底座
    canvas.drawLine(
      Offset(center.dx - 10, center.dy + 33),
      Offset(center.dx + 10, center.dy + 33),
      strokePaint,
    );

    // 左侧声波
    final leftWave1 = Path();
    leftWave1.moveTo(center.dx - 25, center.dy + 3);
    leftWave1.quadraticBezierTo(
      center.dx - 25, center.dy - 2,
      center.dx - 20, center.dy - 2,
    );
    leftWave1.quadraticBezierTo(
      center.dx - 25, center.dy - 2,
      center.dx - 25, center.dy - 7,
    );
    canvas.drawPath(leftWave1, strokePaint);

    final leftWave2 = Path();
    leftWave2.moveTo(center.dx - 30, center.dy + 8);
    leftWave2.quadraticBezierTo(
      center.dx - 30, center.dy - 2,
      center.dx - 20, center.dy - 2,
    );
    leftWave2.quadraticBezierTo(
      center.dx - 30, center.dy - 2,
      center.dx - 30, center.dy - 12,
    );
    canvas.drawPath(leftWave2, strokePaint);

    // 右侧声波
    final rightWave1 = Path();
    rightWave1.moveTo(center.dx + 25, center.dy + 3);
    rightWave1.quadraticBezierTo(
      center.dx + 25, center.dy - 2,
      center.dx + 20, center.dy - 2,
    );
    rightWave1.quadraticBezierTo(
      center.dx + 25, center.dy - 2,
      center.dx + 25, center.dy - 7,
    );
    canvas.drawPath(rightWave1, strokePaint);

    final rightWave2 = Path();
    rightWave2.moveTo(center.dx + 30, center.dy + 8);
    rightWave2.quadraticBezierTo(
      center.dx + 30, center.dy - 2,
      center.dx + 20, center.dy - 2,
    );
    rightWave2.quadraticBezierTo(
      center.dx + 30, center.dy - 2,
      center.dx + 30, center.dy - 12,
    );
    canvas.drawPath(rightWave2, strokePaint);

    // 金钱符号装饰
    final moneyCircle = Offset(center.dx + 15, center.dy - 22);
    canvas.drawCircle(moneyCircle, 8, paint);

    // 绘制货币符号 (¥)
    final moneyPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 垂直线
    canvas.drawLine(
      Offset(moneyCircle.dx, moneyCircle.dy - 6),
      Offset(moneyCircle.dx, moneyCircle.dy + 6),
      moneyPaint,
    );

    // 上横线
    canvas.drawLine(
      Offset(moneyCircle.dx - 5, moneyCircle.dy - 2),
      Offset(moneyCircle.dx + 5, moneyCircle.dy - 2),
      moneyPaint,
    );

    // 下横线
    canvas.drawLine(
      Offset(moneyCircle.dx - 5, moneyCircle.dy + 2),
      Offset(moneyCircle.dx + 5, moneyCircle.dy + 2),
      moneyPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}