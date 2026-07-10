import 'package:flutter/material.dart';

class AgentThreadScreen extends StatelessWidget {
  final String vendorName;
  const AgentThreadScreen({super.key, required this.vendorName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agent Thread: $vendorName (EF-08)')),
      body: Center(child: Text('Agent negotiation logs for $vendorName')),
    );
  }
}
