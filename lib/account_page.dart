import 'package:flutter/material.dart';

/// A simple Account page widget.
///
/// Replace the placeholder data and callbacks with real user data and logic.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: 16),
            Text('Your Name', style: theme.textTheme.titleMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('you@example.com', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: open edit profile screen
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 24),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Past Reviews'),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    onTap: () {
                      // TODO: implement logout
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Account details and settings appear here.'),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
