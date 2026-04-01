import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/plant_loading.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing your plant...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This takes about 10 seconds',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
