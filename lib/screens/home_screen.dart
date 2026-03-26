import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diagnosis_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/severity_badge.dart';
import 'loading_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: const Text('🌿 PlantDoctor',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _ScanButton(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('RECENT DIAGNOSES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1.2)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _DiagnosesList()),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _scanPlant(context),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan a Plant',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            elevation: 3,
          ),
        ),
      ),
    );
  }

  Future<void> _scanPlant(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo == null) return;

    if (!context.mounted) return;
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const LoadingScreen()));

    try {
      final imageUrl = await StorageService.uploadImage(File(photo.path));

      final callable = FirebaseFunctions.instance.httpsCallable('diagnosePlant');
      final response = await callable.call({'imageUrl': imageUrl});

      final rawDiagnosis = Map<String, dynamic>.from(response.data['diagnosis']);
      final diagnosis = DiagnosisResult.fromJson(
          DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl,
          rawDiagnosis);

      await FirebaseService.saveDiagnosis(diagnosis);

      if (context.mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: diagnosis)));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}

class _DiagnosesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DiagnosisResult>>(
      stream: FirebaseService.diagnosesStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No plants scanned yet',
              style: TextStyle(color: Colors.grey, fontSize: 15)));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _DiagnosisCard(
            diagnosis: items[i],
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ResultScreen(diagnosis: items[i]))),
          ),
        );
      },
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final DiagnosisResult diagnosis;
  final VoidCallback onTap;
  const _DiagnosisCard({required this.diagnosis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = '${diagnosis.createdAt.month}/${diagnosis.createdAt.day}';
    final subtitle = diagnosis.issues.isEmpty
        ? 'Healthy'
        : '${diagnosis.issues.length} issue${diagnosis.issues.length > 1 ? 's' : ''} found';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_florist, color: AppTheme.green, size: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diagnosis.plantSpecies,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$date · $subtitle',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SeverityBadge(severity: diagnosis.overallSeverity),
            ],
          ),
        ),
      ),
    );
  }
}
