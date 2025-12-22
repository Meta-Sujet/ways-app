import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../storage/image_upload_service.dart';

class AddItemScreen extends StatefulWidget {
  final String imagePath;
  const AddItemScreen({super.key, required this.imagePath});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _folder = TextEditingController(text: "Garage");

  bool _isExchange = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = _title.text.trim();
    final folderRaw = _folder.text.trim();
    final folder = folderRaw.isEmpty ? 'General' : folderRaw;

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Title is required.")));
      return;
    }

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;

      // read owner info once
      final userDoc = await db.collection('users').doc(uid).get();
      final ownerName = (userDoc.data()?['username'] ?? '').toString();
      final ownerPhotoUrl = userDoc
          .data()?['photoUrl']
          ?.toString(); // may be null

      // 1) Create item in Firestore (image upload later)
      final itemRef = db.collection('items').doc();

      await itemRef.set({
        'ownerId': uid,
        'title': title,
        'description': _description.text.trim(),
        'folder': folder.isEmpty ? 'General' : folder,
        'isExchange': _isExchange,
        'price': _isExchange
            ? null
            : (_price.text.trim().isEmpty ? null : _price.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
        'ownerUsername': ownerName,
        'ownerPhotoUrl': ownerPhotoUrl,
      });

      final imageFile = File(widget.imagePath);

      final uploader = ImageUploadService();
      final imageUrl = await uploader.uploadItemImage(
        userId: uid,
        itemId: itemRef.id,
        imageFile: imageFile,
      );

      // update item with real image url
      await itemRef.update({'imageUrl': imageUrl});

      // 2) Update user profile -> unlock app
      final userRef = db.collection('users').doc(uid);
      await userRef.update({
        'setupComplete': true,
        'itemsCount': FieldValue.increment(1),
      });

      if (!mounted) return;

      // Go back to MainShell
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(widget.imagePath);

    return Scaffold(
      appBar: AppBar(title: const Text("Add item")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                imageFile,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              value: _isExchange,
              onChanged: (v) => setState(() => _isExchange = v),
              title: const Text("I want to exchange (not sell)"),
            ),

            if (!_isExchange) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Price (optional)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _folder,
              decoration: const InputDecoration(
                labelText: "Folder (e.g. Garage)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Publish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
