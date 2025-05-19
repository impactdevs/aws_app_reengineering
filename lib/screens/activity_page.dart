import 'package:flutter/material.dart';

class ActivityPage extends StatelessWidget {
  ActivityPage({super.key});

  final List<Map<String, String>> activityItems = [
    {"title": "Baseline"},
    {"title": "Follow-up"},
  ];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final formId = args?['form_id'] ?? '';
    final formTitle = args?['form_title'] ?? 'Untitled Form';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(formTitle),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: activityItems.length,
        itemBuilder: (context, index) {
          final activity = activityItems[index]['title']!;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(
                activity,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(formTitle),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/details_page',
                  arguments: {
                    'form_id': formId,
                    'form_title': formTitle,
                    'activity_type': activity,
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}