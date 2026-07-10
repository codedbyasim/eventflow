import 'package:flutter/material.dart';
import '../setup/event_type_screen.dart';

class HomeScreen extends StatelessWidget {
  final bool isGuest;

  const HomeScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EventFlow Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Home Screen (EF-03)\nisGuest: $isGuest', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventTypeScreen()),
                );
              },
              child: const Text('Start Event Setup'),
            ),
          ],
        ),
      ),
    );
  }
}
