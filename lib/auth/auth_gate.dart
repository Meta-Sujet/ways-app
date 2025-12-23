import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../favorites/favorites_items_provider.dart';
import '../feed/friends_feed_provider.dart';
import '../favorites/favorites_provider.dart';

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

  String? _lastFeedUid;

  String? _lastFavUid;

  String? _lastFavItemsUid;

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

  void _syncFriendsFeedListener(AuthProvider auth) {
    final currentUid = auth.user?.uid;

    // No user -> stop
    if (currentUid == null) {
      if (_lastFeedUid != null) {
        context.read<FriendsFeedProvider>().stop();
        _lastFeedUid = null;
      }
      return;
    }

    // Same user -> do nothing
    if (_lastFeedUid == currentUid) return;

    // New user -> start (after frame)
    _lastFeedUid = currentUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FriendsFeedProvider>().start();
    });
  }

  void _syncFavoritesListener(AuthProvider auth) {
    final currentUid = auth.user?.uid;

    if (currentUid == null) {
      if (_lastFavUid != null) {
        context.read<FavoritesProvider>().stop();
        _lastFavUid = null;
      }
      return;
    }

    if (_lastFavUid == currentUid) return;

    _lastFavUid = currentUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritesProvider>().start();
    });
  }

  void _syncFavoritesItemsListener(AuthProvider auth) {
    final currentUid = auth.user?.uid;

    if (currentUid == null) {
      if (_lastFavItemsUid != null) {
        context.read<FavoritesItemsProvider>().stop();
        _lastFavItemsUid = null;
      }
      return;
    }

    if (_lastFavItemsUid == currentUid) return;

    _lastFavItemsUid = currentUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritesItemsProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // FirebaseAuth.instance.signOut();

    // ✅ keep profile listener in sync, but not during build
    _syncProfileListener(auth);
    _syncFriendsFeedListener(auth);
    _syncFavoritesListener(auth);
    _syncFavoritesItemsListener(auth);

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.user == null) {
      return const AuthScreen();
    }

    return const MainShell();
  }
}
