import 'package:flutter/material.dart';

class ReviewScreen extends StatelessWidget {
  final dynamic model;
  const ReviewScreen({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review (EF-07)')),
      body: const Center(child: Text('Review Screen Placeholder')),
    );
  }
}
