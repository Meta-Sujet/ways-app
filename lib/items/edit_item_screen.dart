import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;

  const EditItemScreen({super.key, required this.itemId});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _folder = TextEditingController();
  final _price = TextEditingController();

  bool _isExchange = false;
  bool _loading = true;
  bool _saving = false;

  DocumentSnapshot<Map<String, dynamic>>? _snap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _folder.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ref = FirebaseFirestore.instance.collection('items').doc(widget.itemId);
      final snap = await ref.get();
      if (!snap.exists) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item not found.")),
          );
          Navigator.pop(context);
        }
        return;
      }

      final data = snap.data() ?? {};
      _snap = snap;

      _title.text = (data['title'] ?? '').toString();
      _desc.text = (data['description'] ?? '').toString();

      final folderRaw = (data['folder'] ?? 'General').toString().trim();
      _folder.text = folderRaw.isEmpty ? 'General' : folderRaw;

      _isExchange = data['isExchange'] == true;

      // price stored as num or string -> keep as string
      final price = data['price'];
      _price.text = price == null ? '' : price.toString();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load failed: $e")),
      );
    }
  }

  num? _parsePrice(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    // allow "12", "12.5"
    return num.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _title.text.trim();
    final desc = _desc.text.trim();

    final folderRaw = _folder.text.trim();
    final folder = folderRaw.isEmpty ? 'General' : folderRaw;

    final priceNum = _parsePrice(_price.text);

    // If exchange -> price is irrelevant (optional rule)
    final updates = <String, dynamic>{
      'title': title,
      'description': desc,
      'folder': folder,
      'isExchange': _isExchange,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_isExchange) {
      // remove price if you want clean data
      updates['price'] = FieldValue.delete();
    } else {
      if (priceNum == null) {
        updates['price'] = FieldValue.delete();
      } else {
        updates['price'] = priceNum;
      }
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.itemId)
          .update(updates);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit post"),
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Save"),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: "Description"),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _folder,
                  decoration: const InputDecoration(labelText: "Folder"),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  value: _isExchange,
                  onChanged: _saving ? null : (v) => setState(() => _isExchange = v),
                  title: const Text("Exchange"),
                  subtitle: const Text("If ON, price will be removed"),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _price,
                  enabled: !_isExchange && !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Price (optional)",
                    hintText: "e.g. 25 or 25.5",
                  ),
                ),

                const SizedBox(height: 18),

                FilledButton(
                  onPressed: (_saving || _loading) ? null : _save,
                  child: const Text("Save changes"),
                ),
              ],
            ),
    );
  }
}
