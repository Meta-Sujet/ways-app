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
    final usernameLower = _usernameController.text.trim().toLowerCase();
    if (usernameLower.isEmpty) return;

    setState(() {
      _loading = true;
      foundUser = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      // 1) usernames/{usernameLower} -> uid
      final usernameDoc = await db.collection('usernames').doc(usernameLower).get();

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

      // 2) public_profiles/{uid} -> profile
      final profileDoc = await db.collection('public_profiles').doc(uid).get();
      final data = profileDoc.data();

      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User profile missing.")),
        );
        return;
      }

      setState(() {
        foundUser = {
          'uid': uid,
          'username': (data['username'] ?? '').toString(),
          'photoUrl': data['photoUrl']?.toString(),
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

      // 0) already friends?
      final alreadyFriend = await db
          .collection('friends')
          .doc(myUid)
          .collection('list')
          .doc(otherUid)
          .get();

      if (alreadyFriend.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Already friends.")),
        );
        return;
      }

      // 1) pending request I sent?
      final pendingSent = await db
          .collection('friend_requests')
          .where('senderId', isEqualTo: myUid)
          .where('receiverId', isEqualTo: otherUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingSent.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request already sent.")),
        );
        return;
      }

      // 2) pending request they sent?
      final pendingReceived = await db
          .collection('friend_requests')
          .where('senderId', isEqualTo: otherUid)
          .where('receiverId', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingReceived.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("They already requested you. Check Requests.")),
        );
        return;
      }

      // 3) create request
      await db.collection('friend_requests').doc().set({
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
    final username = foundUser?['username']?.toString() ?? "";
    final uid = foundUser?['uid']?.toString() ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Add friend")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loading ? null : searchUser(),
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
                subtitle: Text(uid),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : sendRequest,
                  child: const Text("Send request"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
