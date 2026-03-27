import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  // Exposed for testing
  static String imagePath(String uid, int timestamp) =>
      'users/$uid/diagnoses/$timestamp.jpg';

  static Future<String> uploadImage(File imageFile) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child(imagePath(uid, timestamp));
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }
}
