import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static Future<String> uploadImage(File imageFile) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref()
        .child('diagnoses/$uid/$timestamp.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }
}
