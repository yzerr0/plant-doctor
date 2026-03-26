import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diagnosis_model.dart';
import '../providers/auth_provider.dart';
import '../providers/diagnoses_provider.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/severity_badge.dart';
import 'auth_screen.dart';
import 'loading_screen.dart';
import 'result_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnonymous =
        ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: const Text('🌿 PlantDoctor',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        elevation: 0,
        actions: [
          if (isAnonymous)
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Sign In',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: const Column(
        children: [
          SizedBox(height: 20),
          _ScanButton(),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('RECENT DIAGNOSES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
            ),
          ),
          SizedBox(height: 8),
          Expanded(child: _DiagnosesList()),
        ],
      ),
    );
  }
}

class _ScanButton extends ConsumerWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _scanPlant(context, ref),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan a Plant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32)),
            elevation: 3,
          ),
        ),
      ),
    );
  }

  Future<void> _scanPlant(BuildContext context, WidgetRef ref) async {
    final photo = await _pickImage(context);
    if (photo == null) return;
    if (!context.mounted) return;

    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const LoadingScreen()));

    try {
      final imageUrl = await StorageService.uploadImage(File(photo.path));

      final callable =
          FirebaseFunctions.instance.httpsCallable('diagnosePlant');
      final response = await callable.call({'imageUrl': imageUrl});

      final rawDiagnosis =
          Map<String, dynamic>.from(response.data['diagnosis']);
      final diagnosis = DiagnosisResult.fromJson(
          DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl,
          rawDiagnosis);

      await FirebaseService.saveDiagnosis(diagnosis);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ResultScreen(diagnosis: diagnosis)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Analysis failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<XFile?> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.green),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.green),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 85);
  }
}

class _DiagnosesList extends ConsumerWidget {
  const _DiagnosesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDiagnoses = ref.watch(diagnosesProvider);
    return asyncDiagnoses.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
              child: Text('No plants scanned yet',
                  style: TextStyle(color: Colors.grey, fontSize: 15)));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => Dismissible(
            key: ValueKey(items[i].id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.white, size: 24),
            ),
            confirmDismiss: (_) async {
              try {
                await FirebaseService.deleteDiagnosis(items[i].id);
                return true;
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete failed. Please try again.')),
                  );
                }
                return false;
              }
            },
            child: _DiagnosisCard(
              diagnosis: items[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ResultScreen(diagnosis: items[i])),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
          child: Text('Error loading diagnoses',
              style: TextStyle(color: Colors.grey))),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final DiagnosisResult diagnosis;
  final VoidCallback onTap;
  const _DiagnosisCard({required this.diagnosis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date =
        '${diagnosis.createdAt.month}/${diagnosis.createdAt.day}';
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_florist,
                    color: AppTheme.green, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diagnosis.plantSpecies,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$date · $subtitle',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
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
