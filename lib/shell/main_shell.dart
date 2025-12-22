import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile/user_profile_provider.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';
import '../add_item/pick_image_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentTabIndex = 0;

  final pages = const [
    FeedScreen(),
    SizedBox.shrink(), // Add is an action, not a real page
    ProfileScreen(),
  ];

  void openAddFirstItemFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PickImageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>();

    // Locked until profile is loaded AND setupComplete is true
    final isLocked = profile.isProfileLoading || !profile.isSetupComplete;

    return Scaffold(
      body: Stack(
        children: [
          // Main content (tabs)
          IndexedStack(index: currentTabIndex, children: pages),

          // Lock overlay - forces first item
          if (isLocked)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Add your first item to start using WAYS",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: profile.isProfileLoading
                              ? null
                              : openAddFirstItemFlow,
                          icon: const Icon(Icons.add),
                          label: const Text("Add first item"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // Bottom navigation (locked -> only Add works)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTabIndex,
        onTap: (index) {
          // While locked: block switching tabs, allow only Add action
          if (isLocked) {
            if (index == 1) openAddFirstItemFlow();
            return;
          }

          // Add tab triggers flow, does not switch screen
          if (index == 1) {
            openAddFirstItemFlow();
            return;
          }

          setState(() => currentTabIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Feed"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "Add"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
