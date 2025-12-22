import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class ImageUploadService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadItemImage({
    required String userId,
    required String itemId,
    required File imageFile,
  }) async {
    final fileName = p.basename(imageFile.path);

    final ref = _storage
        .ref()
        .child('item_images')
        .child(userId)
        .child(itemId)
        .child(fileName);

    await ref.putFile(imageFile);

    return await ref.getDownloadURL();
  }
}
