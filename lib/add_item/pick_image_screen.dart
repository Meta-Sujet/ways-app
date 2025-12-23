import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'add_item_screen.dart';

class PickImageScreen extends StatelessWidget {
  const PickImageScreen({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();

    // Pick image
    final XFile? file = await picker.pickImage(
      source: source,
      imageQuality: 85, // simple compression
    );

    if (file == null) return;

    // Go to form screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(imagePath: file.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add first item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Choose a photo to add your first item.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            //TODO გააერთიანე, ერთი იკონი იყოს : add photo, როცა დააკლიკებს იქიდან აარჩევინე ფოტოს იღებს თუ გალერიდან დებს. ----------------------------------
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _pick(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take photo"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("Choose from gallery"),
              ),
            ),

            // const SizedBox(height: 12),
            // ElevatedButton(onPressed: () {
            //   FirebaseAuth.instance.signOut();
            // }, child: Text('signOut'))
          ],
        ),
      ),
    );
  }
}
