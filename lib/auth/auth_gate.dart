// import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'auth_screen.dart';
import '../profile/user_profile_provider.dart';
import '../shell/main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUid; // helps us start/stop listener only when user changes

  void _syncProfileListener(AuthProvider auth) {
    final currentUid = auth.user?.uid;

    // No user -> stop listening
    if (currentUid == null) {
      if (_lastUid != null) {
        context.read<UserProfileProvider>().stopListening();
        _lastUid = null;
      }
      return;
    }

    // Same user -> do nothing
    if (_lastUid == currentUid) return;

    // New user -> start listening (AFTER this frame)
    _lastUid = currentUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserProfileProvider>().startListeningToProfile();
    });
  }

  @override
  Widget build(BuildContext context) {

    final auth = context.watch<AuthProvider>();
    // FirebaseAuth.instance.signOut();

    // ✅ keep profile listener in sync, but not during build
    _syncProfileListener(auth);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.user == null) {
      return const AuthScreen();
    }

    return const MainShell();
  }
}
