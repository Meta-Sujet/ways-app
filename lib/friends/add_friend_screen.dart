import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _usernameController = TextEditingController();
  bool _loading = false;

  Map<String, dynamic>? foundUser; // {uid, username, photoUrl}

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> searchUser() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final usernameLower = _usernameController.text.trim().toLowerCase();
    if (usernameLower.isEmpty) return;

    setState(() {
      _loading = true;
      foundUser = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final usernameDoc =
          await db.collection('usernames').doc(usernameLower).get();

      if (!usernameDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found.")),
        );
        return;
      }

      final uid = (usernameDoc.data()?['uid'] ?? '').toString();
      if (uid.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found.")),
        );
        return;
      }

      if (uid == myUid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That's you 🙂")),
        );
        return;
      }

      final publicDoc = await db.collection('public_profiles').doc(uid).get();
      final publicData = publicDoc.data();

      if (publicData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User profile missing (public_profiles).")),
        );
        return;
      }

      setState(() {
        foundUser = {
          'uid': uid,
          'username': (publicData['username'] ?? '').toString(),
          'photoUrl': publicData['photoUrl']?.toString(),
        };
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _pendingExists(String myUid, String otherUid) async {
    final db = FirebaseFirestore.instance;

    // check pending in both directions
    final q1 = await db
        .collection('friend_requests')
        .where('status', isEqualTo: 'pending')
        .where('senderId', isEqualTo: myUid)
        .where('receiverId', isEqualTo: otherUid)
        .limit(1)
        .get();

    if (q1.docs.isNotEmpty) return true;

    final q2 = await db
        .collection('friend_requests')
        .where('status', isEqualTo: 'pending')
        .where('senderId', isEqualTo: otherUid)
        .where('receiverId', isEqualTo: myUid)
        .limit(1)
        .get();

    return q2.docs.isNotEmpty;
  }

  Future<void> sendRequest() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || foundUser == null) return;

    final otherUid = foundUser!['uid'] as String;

    if (otherUid == myUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't add yourself.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final db = FirebaseFirestore.instance;

      // already friends?
      final friendDoc = await db
          .collection('friends')
          .doc(myUid)
          .collection('list')
          .doc(otherUid)
          .get();

      if (friendDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Already friends.")),
        );
        return;
      }

      // pending already?
      final pending = await _pendingExists(myUid, otherUid);
      if (pending) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request already pending.")),
        );
        return;
      }

      // create request in top-level collection
      await db.collection('friend_requests').add({
        'senderId': myUid,
        'receiverId': otherUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend request sent.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final username = foundUser?['username']?.toString() ?? "";
    final foundUid = foundUser?['uid']?.toString();
    final isSelf = (myUid != null && foundUid != null && myUid == foundUid);

    return Scaffold(
      appBar: AppBar(title: const Text("Add friend")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchUser(),
              decoration: InputDecoration(
                labelText: "Search by username",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : searchUser,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),

            if (foundUser != null) ...[
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  child: Text(username.isNotEmpty ? username[0].toUpperCase() : "?"),
                ),
                title: Text(username.isEmpty ? "(no username)" : username),
                subtitle: Text(foundUid ?? ""),
              ),
              const SizedBox(height: 12),
              if (!isSelf)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : sendRequest,
                    child: const Text("Send request"),
                  ),
                )
              else
                const Text("You can’t send a request to yourself."),
            ],
          ],
        ),
      ),
    );
  }
}
