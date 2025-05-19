import 'package:flutter/material.dart';
import '../models/draft_model.dart';
import '../services/draft_service.dart';

class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  late final DraftService _draftService;
  List<DraftModel> _drafts = [];
  bool _isLoading = true;
  String? _formId;
  String? _activityType;
  String? _formTitle;

  @override
  void initState() {
    super.initState();
    _draftService = DraftService();
    _loadDrafts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _formId = args['form_id']?.toString();
      _activityType = args['activity_type']?.toString() ?? 'Baseline';
      _formTitle = args['form_title']?.toString() ?? 'Untitled';
    }
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    await _draftService.init();
    if (_formId != null) {
      setState(() {
        _drafts = _draftService.getAllDrafts(_formId!);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDraft(String formId, String activityType) async {
    await _draftService.deleteDraft(formId, activityType, DateTime.now());
    await _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Drafts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? const Center(child: Text('No drafts found'))
              : ListView.builder(
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(draft.title),
                        subtitle: Text(
                          'Last modified: ${draft.timestamp.toString().split('.')[0]}\nStatus: ${draft.status}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/form_page',
                                  arguments: {
                                    'form_id': draft.formId,
                                    'form_title': draft.title,
                                    'activity_type': _activityType,
                                    'draft': draft,
                                  },
                                ).then((_) => _loadDrafts());
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Draft'),
                                    content: const Text(
                                        'Are you sure you want to delete this draft?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteDraft(draft.formId, _activityType!);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}