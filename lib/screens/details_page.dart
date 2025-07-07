import 'dart:developer';

import 'package:aws_app/models/commit_model.dart';
import 'package:aws_app/services/commit_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/draft_model.dart';
import '../services/draft_service.dart';
import '../providers/auth_provider.dart';
import 'dart:convert';

String? getAreaNameFromRegionData({
  required String
      areaType, // e.g. 'district', 'sub_county', 'parish', 'village', 'region'
  required String areaId,
  required Map<String, dynamic> regionData,
}) {
  final areaConfig = {
    'region': {
      'listKey': 'region',
      'idField': 'region_id',
      'nameField': 'name'
    },
    'district': {
      'listKey': 'app_district',
      'idField': 'district_id',
      'nameField': 'name'
    },
    'sub_county': {
      'listKey': 'app_sub_county',
      'idField': 'sub_county_id',
      'nameField': 'name'
    },
    'parish': {
      'listKey': 'app_parish',
      'idField': 'parish_id',
      'nameField': 'name'
    },
    'village': {
      'listKey': 'app_village',
      'idField': 'village_id',
      'nameField': 'name'
    },
  };
  final config = areaConfig[areaType];
  if (config == null) return null;
  final list = regionData[config['listKey']] as List<dynamic>?;
  if (list == null) return null;
  final match = list.firstWhere(
    (item) => item[config['idField']]?.toString() == areaId,
    orElse: () => {},
  );
  if (match.isEmpty) return null;
  return match[config['nameField']]?.toString();
}

class DetailsPage extends StatefulWidget {
  const DetailsPage({Key? key}) : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late DraftService _draftService;
  late CommitService _commitService;
  List<DraftModel> _drafts = [];
  List<CommitModel> _commits = [];
  List<dynamic> _committedNewEntries = [];
  bool _isLoadingEntries = false;
  String? _formId;
  String? _activityType;
  String? _formTitle;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // Bulk selection state
  Set<String> _selectedDrafts = {};
  Set<String> _selectedCommits = {};
  Set<String> _selectedEntries = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _drafts = [];
    _commits = [];
    _committedNewEntries = [];
    _isLoadingEntries = false;
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _tabController = TabController(
      length: 2,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final newActivityType = args?['activity_type']?.toString() ?? 'Baseline';
    _formId = args?['form_id']?.toString();
    _formTitle = args?['form_title']?.toString() ?? 'Untitled';

    if (_activityType != newActivityType) {
      _activityType = newActivityType;
      final newLength = _activityType == "Follow-up" ? 3 : 2;
      _tabController?.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
      );
    }

    _draftService = Provider.of<DraftService>(context, listen: false);
    _commitService = Provider.of<CommitService>(context, listen: false);

    _ensureRegionDataLoaded();
    _loadDrafts();
    _loadCommits();
    _loadEntries();
    _fadeController.forward();
  }

  Future<void> _ensureRegionDataLoaded() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasUserRegionData && auth.user != null) {
      try {
        await auth.loadUserRegionData(auth.user!['user_id']);
        if (mounted) setState(() {});
      } catch (e) {
        print('Failed to load region data: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadDrafts() {
    if (_formId != null && _activityType != null) {
      setState(() {
        _drafts =
            _draftService.getDraftsByStatus(_formId!, _activityType!, 'draft');
      });
    }
  }

  void _loadCommits() {
    if (_formId != null && _activityType != null) {
      setState(() {
        _commits = _commitService.getCommitsByStatus(
            _formId!, _activityType!, 'draft');
      });
    }
  }

  Future<void> _loadEntries() async {
    if (_formId == null || _activityType == null) return;
    setState(() => _isLoadingEntries = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final regionId = auth.regionId ?? '1';
      if (_activityType == "Baseline") {
        _committedNewEntries = await auth.apiService
            .fetchCommittedBaselineEntries(regionId, _formId!);
      } else {
        _committedNewEntries =
            await auth.apiService.fetchFollowUpEntries(regionId, _formId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load entries: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingEntries = false);
    }
  }

  Widget _buildShimmerTable() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  // Helper method to get draft title using form configuration
  String _getDraftTitle(DraftModel draft) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final allForms = auth.forms;
    Map<String, dynamic>? formData;

    for (final form in allForms) {
      if (form['form_id'].toString() == draft.formId) {
        formData = Map<String, dynamic>.from(form);
        break;
      }
    }

    // Default to draft.title
    String title = draft.title;

    if (formData != null && formData['title_fields'] != null) {
      final titleFields = formData['title_fields'];
      if (titleFields['entry_title'] != null &&
          titleFields['entry_title'] is List &&
          titleFields['entry_title'].isNotEmpty) {
        final titleQuestionId = titleFields['entry_title'][0];
        final titleAnswer = draft.answers['qn$titleQuestionId']?.toString();
        if (titleAnswer != null && titleAnswer.isNotEmpty) {
          title = titleAnswer;
        }
      }
    }

    return title;
  }

  // Helper method to get area name
  String _getAreaName(String questionId, String answerValue,
      Map<String, dynamic> formData, AuthProvider auth) {
    final questions = formData['question_list'] as List<dynamic>? ?? [];
    for (final question in questions) {
      if (question['question_id'].toString() == questionId) {
        final answerType = question['answer_type']?.toString();
        if (answerType == 'app_list') {
          final answerValues = question['answer_values'];
          if (answerValues != null && answerValues['db_table'] != null) {
            final dbTable = answerValues['db_table'].toString();
            List<dynamic> items = [];
            if (dbTable == 'app_district') {
              items = auth.userRegionData?['app_district'] ?? [];
            } else if (dbTable == 'app_sub_county') {
              items = auth.userRegionData?['app_sub_county'] ?? [];
            } else if (dbTable == 'app_parish') {
              items = auth.userRegionData?['app_parish'] ?? [];
            } else if (dbTable == 'app_village') {
              items = auth.userRegionData?['app_village'] ?? [];
            } else if (dbTable == 'app_project') {
              items = auth.projects;
            } else if (dbTable == 'app_organisation') {
              items = auth.organisations;
            } else if (auth.userRegionData != null && dbTable.isNotEmpty) {
              items = auth.userRegionData![dbTable] ?? [];
            }

            final Map<String, String> defaultValueFields = {
              'app_district': 'district_id',
              'app_sub_county': 'sub_county_id',
              'app_parish': 'parish_id',
              'app_village': 'village_id',
              'app_project': 'project_id',
              'app_organisation': 'organisation_id',
              'region': 'region_id',
            };

            final String valueField = answerValues['value_field'] ??
                defaultValueFields[dbTable] ??
                'id';

            for (final item in items) {
              final String itemValue = item[valueField]?.toString() ?? '';
              if (itemValue == answerValue) {
                return item['name']?.toString() ?? answerValue;
              }
            }
          }
        }
        break;
      }
    }
    return answerValue;
  }

  String _getAreaForDraft(DraftModel draft) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final allForms = auth.forms;
    Map<String, dynamic>? formData;

    for (final form in allForms) {
      if (form['form_id'].toString() == draft.formId) {
        formData = Map<String, dynamic>.from(form);
        break;
      }
    }

    if (formData != null && formData['title_fields'] != null) {
      final titleFields = formData['title_fields'];
      if (titleFields['entry_sub_title'] != null &&
          titleFields['entry_sub_title'] is List &&
          titleFields['entry_sub_title'].isNotEmpty) {
        final subtitleQuestionId = titleFields['entry_sub_title'][0];
        final subtitleAnswer =
            draft.answers['qn$subtitleQuestionId']?.toString();
        if (subtitleAnswer != null && subtitleAnswer.isNotEmpty) {
          return _getAreaName(
              subtitleQuestionId, subtitleAnswer, formData, auth);
        }
      }
    }
    return '';
  }

  // Bulk selection helper methods
  String _getDraftKey(DraftModel draft) {
    return '${draft.formId}_${draft.timestamp.millisecondsSinceEpoch}';
  }

  String _getCommitKey(CommitModel commit) {
    return '${commit.formId}_${commit.timestamp.millisecondsSinceEpoch}';
  }

  String _getEntryKey(Map<String, dynamic> entry) {
    return entry['id']?.toString() ?? entry['entry_id']?.toString() ?? '';
  }

  void _toggleDraftSelection(DraftModel draft) {
    setState(() {
      final key = _getDraftKey(draft);
      if (_selectedDrafts.contains(key)) {
        _selectedDrafts.remove(key);
      } else {
        _selectedDrafts.add(key);
      }
      _updateSelectionMode();
    });
  }

  void _toggleCommitSelection(CommitModel commit) {
    setState(() {
      final key = _getCommitKey(commit);
      if (_selectedCommits.contains(key)) {
        _selectedCommits.remove(key);
      } else {
        _selectedCommits.add(key);
      }
      _updateSelectionMode();
    });
  }

  void _toggleEntrySelection(Map<String, dynamic> entry) {
    setState(() {
      final key = _getEntryKey(entry);
      if (_selectedEntries.contains(key)) {
        _selectedEntries.remove(key);
      } else {
        _selectedEntries.add(key);
      }
      _updateSelectionMode();
    });
  }

  void _updateSelectionMode() {
    final hasSelections = _selectedDrafts.isNotEmpty ||
        _selectedCommits.isNotEmpty ||
        _selectedEntries.isNotEmpty;
    if (_isSelectionMode != hasSelections) {
      setState(() {
        _isSelectionMode = hasSelections;
      });
    }
  }

  void _selectAllDrafts() {
    setState(() {
      _selectedDrafts.clear();
      for (final draft in _drafts) {
        _selectedDrafts.add(_getDraftKey(draft));
      }
      _updateSelectionMode();
    });
  }

  void _selectAllCommits() {
    setState(() {
      _selectedCommits.clear();
      for (final commit in _commits) {
        _selectedCommits.add(_getCommitKey(commit));
      }
      _updateSelectionMode();
    });
  }

  void _selectAllEntries() {
    setState(() {
      _selectedEntries.clear();
      for (final entry in _committedNewEntries) {
        _selectedEntries.add(_getEntryKey(entry));
      }
      _updateSelectionMode();
    });
  }

  void _clearAllSelections() {
    setState(() {
      _selectedDrafts.clear();
      _selectedCommits.clear();
      _selectedEntries.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _bulkDeleteDrafts() async {
    final selectedDrafts = _drafts
        .where((draft) => _selectedDrafts.contains(_getDraftKey(draft)))
        .toList();

    if (selectedDrafts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Drafts', style: GoogleFonts.poppins()),
        content: Text(
            'Are you sure you want to delete ${selectedDrafts.length} selected draft(s)?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final draft in selectedDrafts) {
        if (_formId != null && _activityType != null) {
          _draftService.deleteDraft(
              draft.formId, _activityType!, draft.timestamp);
        }
      }
      _clearAllSelections();
      _loadDrafts();
    }
  }

  Future<void> _bulkDeleteCommits() async {
    final selectedCommits = _commits
        .where((commit) => _selectedCommits.contains(_getCommitKey(commit)))
        .toList();

    if (selectedCommits.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Commits', style: GoogleFonts.poppins()),
        content: Text(
            'Are you sure you want to delete ${selectedCommits.length} selected commit(s)?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final commit in selectedCommits) {
        if (_formId != null && _activityType != null) {
          _commitService.deleteCommit(
              commit.formId, _activityType!, commit.timestamp);
        }
      }
      _clearAllSelections();
      _loadCommits();
    }
  }

  Future<void> _bulkSubmitDrafts() async {
    final selectedDrafts = _drafts
        .where((draft) => _selectedDrafts.contains(_getDraftKey(draft)))
        .toList();

    if (selectedDrafts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit Selected Drafts', style: GoogleFonts.poppins()),
        content: Text(
            'Are you sure you want to submit ${selectedDrafts.length} selected draft(s)?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text('Submit', style: GoogleFonts.poppins(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitDraftsOneByOne(selectedDrafts);
    }
  }

  // Submits a single draft using the same logic as _submitForm in dynamic_form_page.dart
  Future<void> _submitSingleDraftMatchingForm(
      DraftModel draft, BuildContext context) async {
    log("submitting single draft");
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final userId = user['user_id'].toString();
    final regionCode = auth.regionId ?? 'C';
    final formId = draft.formId;
    final formTitle = draft.title;
    final subTitle = draft.answers['qn4']?.toString() ?? 'Default Subtitle';
    final activityType = draft.answers['entity_type']?.toString() ?? 'Baseline';
    final responseId = auth.generateResponseId(regionCode, int.parse(userId));

    debugPrint("regionData: ${auth.userRegionData}");

    // Convert area keys to actual area values if present
    Map<String, dynamic> answers = Map<String, dynamic>.from(draft.answers);
    if (auth.userRegionData != null &&
        auth.userRegionData is Map<String, dynamic>) {
      final areaData = auth.userRegionData as Map<String, dynamic>;
      final areaMappings = [
        {'key': 'region_id', 'areaType': 'region'},
        {'key': 'district_id', 'areaType': 'district'},
        {'key': 'sub_county_id', 'areaType': 'sub_county'},
        {'key': 'parish_id', 'areaType': 'parish'},
        {'key': 'village_id', 'areaType': 'village'},
      ];
      for (final mapping in areaMappings) {
        final answerKey = mapping['key']!;
        final areaType = mapping['areaType']!;
        if (answers.containsKey(answerKey)) {
          final areaId = answers[answerKey]?.toString();
          final areaName = getAreaNameFromRegionData(
            areaType: areaType,
            areaId: areaId ?? '',
            regionData: areaData,
          );
          if (areaName != null) {
            answers[answerKey] = areaName;
          }
        }
      }
      // Handle projects and organisations if not in userRegionData
      if (answers.containsKey('project_id') && auth.projects.isNotEmpty) {
        final areaId = answers['project_id']?.toString();
        final match = auth.projects.firstWhere(
          (item) => item['project_id']?.toString() == areaId,
          orElse: () => {},
        );
        if (match.isNotEmpty && match['name'] != null) {
          answers['project_id'] = match['name'];
        }
      }
      if (answers.containsKey('organisation_id') &&
          auth.organisations.isNotEmpty) {
        final areaId = answers['organisation_id']?.toString();
        final match = auth.organisations.firstWhere(
          (item) => item['organisation_id']?.toString() == areaId,
          orElse: () => {},
        );
        if (match.isNotEmpty && match['name'] != null) {
          answers['organisation_id'] = match['name'];
        }
      }
      // New logic: replace qnX keys for area questions with area names
      // Get form config for this draft
      final allForms = auth.forms;
      Map<String, dynamic>? formData;
      for (final form in allForms) {
        if (form['form_id'].toString() == draft.formId) {
          formData = Map<String, dynamic>.from(form);
          break;
        }
      }
      if (formData != null && formData is Map<String, dynamic>) {
        final questionList = formData['question_list'] as List<dynamic>?;
        if (questionList != null) {
          for (final question in questionList) {
            if (question['answer_type'] == 'app_list') {
              final dbTable = question['answer_values']['db_table'];
              final qnKey = 'qn${question['question_id']}';
              if (answers.containsKey(qnKey)) {
                final areaId = answers[qnKey]?.toString();
                String? areaType;
                if (dbTable == 'app_district') areaType = 'district';
                if (dbTable == 'app_sub_county') areaType = 'sub_county';
                if (dbTable == 'app_parish') areaType = 'parish';
                if (dbTable == 'app_village') areaType = 'village';
                if (dbTable == 'region') areaType = 'region';
                if (areaType != null) {
                  final areaName = getAreaNameFromRegionData(
                    areaType: areaType,
                    areaId: areaId ?? '',
                    regionData: areaData,
                  );
                  if (areaName != null) {
                    answers[qnKey] = areaName;
                  }
                }
              }
            }
          }
        }
      }
    }

    debugPrint("answers: $answers");

    try {
      Map<String, dynamic> submissionAnswers = jsonDecode(jsonEncode(answers));
      log("submissionAnswers: $submissionAnswers");
      submissionAnswers['entity_type'] =
          activityType.toLowerCase() == 'follow-up' ? 'followup' : 'baseline';
      submissionAnswers['creator_id'] = userId;
      submissionAnswers['created_at'] =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      String? base64Photo;
      String photoFilename = "null";
      if (draft.images.containsKey("photo_base64")) {
        base64Photo = submissionAnswers['photo_base64'];
        photoFilename = "image_${DateTime.now().millisecondsSinceEpoch}.jpeg";
      }
      submissionAnswers['photo'] = photoFilename;
      submissionAnswers.remove('photo_base64');
      submissionAnswers.remove('updated_at');

      final Map<String, dynamic> finalAnswers =
          Map<String, dynamic>.from(submissionAnswers);

      log("finalAnswers: $finalAnswers");

      if (activityType.toLowerCase() == "follow-up") {
        await auth.apiService.commitFollowUp(
          responseId: responseId,
          formId: formId,
          title: finalAnswers['qn65']?.toString() ?? formTitle,
          subTitle: subTitle,
          answers: finalAnswers,
          creatorId: userId,
        );
      } else {
        log("submitting baseline");
        log("finalAnswers: $finalAnswers");

        await auth.apiService.commitBaseline(
          responseId: responseId,
          formId: formId,
          title: finalAnswers['qn65']?.toString() ?? formTitle,
          subTitle: subTitle,
          answers: finalAnswers,
          creatorId: userId,
        );
        if (base64Photo != null) {
          try {
            await auth.apiService.commitPhoto(
              responseId: responseId,
              base64Data: base64Photo,
              filename: photoFilename,
              creatorId: int.parse(userId),
            );
          } catch (e) {
            // Photo commit failed, but continue
          }
        }
      }
      await _draftService.updateDraftStatus(formId, activityType, 'submitted');
    } catch (e) {
      // Optionally handle error
      rethrow;
    }
  }

  Future<void> _submitDraftsOneByOne(List<DraftModel> drafts) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedDrafts = [];

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Submitting Drafts', style: GoogleFonts.poppins()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: (successCount + failureCount) / drafts.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                ),
                const SizedBox(height: 16),
                Text(
                  'Submitted: $successCount / ${drafts.length}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                if (failureCount > 0)
                  Text(
                    'Failed: $failureCount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    try {
      for (int i = 0; i < drafts.length; i++) {
        final draft = drafts[i];
        try {
          await _submitSingleDraftMatchingForm(draft, context);
          successCount++;
        } catch (e) {
          failureCount++;
          failedDrafts.add('${draft.title}: ${e.toString()}');
        }
        if (mounted) {
          setState(() {});
        }
        if (i < drafts.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    if (mounted) {
      _showSubmissionResults(successCount, failureCount, failedDrafts);
    }
    _clearAllSelections();
    _loadDrafts();
    _loadCommits();
  }

  void _showSubmissionResults(
      int successCount, int failureCount, List<String> failedDrafts) {
    String message;
    Color backgroundColor;
    Duration duration;

    if (failureCount == 0) {
      message = 'All $successCount draft(s) submitted successfully!';
      backgroundColor = Colors.green;
      duration = const Duration(seconds: 3);
    } else if (successCount == 0) {
      message = 'All $failureCount draft(s) failed to submit.';
      backgroundColor = Colors.red;
      duration = const Duration(seconds: 6);
    } else {
      message =
          '$successCount draft(s) submitted successfully, $failureCount failed.';
      backgroundColor = Colors.orange;
      duration = const Duration(seconds: 6);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  DataRow _buildDraftRow(DraftModel draft) {
    final area = _getAreaForDraft(draft);
    final title = _getDraftTitle(draft);
    final isSelected = _selectedDrafts.contains(_getDraftKey(draft));

    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleDraftSelection(draft),
                    activeColor: Colors.blue[700],
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              area,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSelectionMode) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => _editDraft(draft),
                      tooltip: 'Edit',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _deleteDraft(draft),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildCommitRow(CommitModel commit) {
    final isSelected = _selectedCommits.contains(_getCommitKey(commit));

    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleCommitSelection(commit),
                    activeColor: Colors.blue[700],
                  ),
                Expanded(
                  child: Text(
                    commit.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(commit.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                commit.status,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isSelectionMode) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => _editCommit(commit),
                      tooltip: 'Edit',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _deleteCommit(commit),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildCommittedRow(Map<String, dynamic> entry) {
    final title = entry['title']?.toString() ?? "N/A";
    final subTitle = entry['sub_title']?.toString() ?? "N/A";
    final parish = entry['parish']?.toString() ?? "N/A";
    final isSelected = _selectedEntries.contains(_getEntryKey(entry));

    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleEntrySelection(entry),
                    activeColor: Colors.blue[700],
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              subTitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              parish,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _activityType == "Follow-up" && !_isSelectionMode
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => _editCommittedEntry(entry),
                      tooltip: 'Edit',
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return Colors.green;
      case 'pending':
      case 'draft':
        return Colors.orange;
      case 'failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _editDraft(DraftModel draft) {
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
  }

  void _deleteDraft(DraftModel draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Draft', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this draft?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              if (_formId != null && _activityType != null) {
                _draftService.deleteDraft(
                    draft.formId, _activityType!, draft.timestamp);
                Navigator.pop(context);
                _loadDrafts();
              }
            },
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editCommit(CommitModel commit) {
    Navigator.pushNamed(
      context,
      '/form_page',
      arguments: {
        'form_id': commit.formId,
        'form_title': commit.title,
        'activity_type': _activityType,
        'draft': commit,
      },
    ).then((_) => _loadDrafts());
  }

  void _deleteCommit(CommitModel commit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Commit', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this commit?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              if (_formId != null && _activityType != null) {
                _commitService.deleteCommit(
                    commit.formId, _activityType!, commit.timestamp);
                Navigator.pop(context);
                _loadCommits();
              }
            },
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editCommittedEntry(Map<String, dynamic> entry) {
    Navigator.pushNamed(
      context,
      '/form_page',
      arguments: {
        'form_id': _formId,
        'form_title': entry['title'] ?? 'Untitled',
        'activity_type': _activityType,
        'follow_up_data': entry,
      },
    ).then((_) => _loadEntries());
  }

  Widget _buildDataTable({required List<dynamic> data, required String type}) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No $type Available',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Items will appear here once created',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    List<DataRow> rows = [];
    List<DataColumn> columns = [];

    switch (type) {
      case 'Drafts':
        columns = [
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Title',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Subtitle',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Actions',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
        ];
        rows = _drafts.map((draft) => _buildDraftRow(draft)).toList();
        break;

      case 'Commits':
        columns = [
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Title',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Status',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Actions',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
        ];
        rows = _commits.map((commit) => _buildCommitRow(commit)).toList();
        break;

      case 'Committed Entries':
        columns = [
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Title',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Sub Title',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Parish',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
          DataColumn(
              label: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text('Actions',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                )),
          )),
        ];
        rows = _committedNewEntries
            .map((entry) => _buildCommittedRow(entry))
            .toList();
        break;
    }

    return Column(
      children: [
        // Bulk action controls
        if (_isSelectionMode) _buildBulkActionBar(type),
        // Data table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DataTable(
                columnSpacing: 0,
                dataRowHeight: 70,
                headingRowHeight: 60,
                columns: columns,
                rows: rows,
                border: TableBorder.all(
                  color: Colors.grey[300]!,
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                headingRowColor: MaterialStateProperty.all(Colors.blue[700]),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.blue[50];
                    }
                    return null;
                  },
                ),
                dataTextStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkActionBar(String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              '${_getSelectedCount(type)} item(s) selected',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => _selectAll(type),
              icon: const Icon(Icons.select_all, size: 16),
              label: Text('Select All', style: GoogleFonts.poppins()),
            ),
            const SizedBox(width: 8),
            if (type == 'Drafts') ...[
              ElevatedButton.icon(
                onPressed:
                    _selectedDrafts.isNotEmpty ? _bulkSubmitDrafts : null,
                icon: const Icon(Icons.send, size: 16),
                label: Text('Submit', style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              onPressed:
                  _getSelectedCount(type) > 0 ? () => _bulkDelete(type) : null,
              icon: const Icon(Icons.delete, size: 16),
              label: Text('Delete', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _clearAllSelections,
              icon: const Icon(Icons.close, size: 16),
              label: Text('Cancel', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAll(String type) {
    switch (type) {
      case 'Drafts':
        _selectAllDrafts();
        break;
      case 'Commits':
        _selectAllCommits();
        break;
      case 'Committed Entries':
        _selectAllEntries();
        break;
    }
  }

  int _getSelectedCount(String type) {
    switch (type) {
      case 'Drafts':
        return _selectedDrafts.length;
      case 'Commits':
        return _selectedCommits.length;
      case 'Committed Entries':
        return _selectedEntries.length;
      default:
        return 0;
    }
  }

  void _bulkDelete(String type) {
    switch (type) {
      case 'Drafts':
        _bulkDeleteDrafts();
        break;
      case 'Commits':
        _bulkDeleteCommits();
        break;
      // Add other cases as needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _formTitle ?? 'Form Details',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.checklist,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_isSelectionMode) {
                  _clearAllSelections();
                } else {
                  _isSelectionMode = true;
                }
              });
            },
          ),
        ],
        bottom: _activityType == "Follow-up"
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                    labelColor: const Color.fromARGB(255, 87, 92, 100),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    tabs: const [
                      Tab(text: 'NEW'),
                      Tab(text: 'DRAFTS'),
                      Tab(text: 'COMMITTED'),
                    ],
                  ),
                ),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    tabs: const [
                      Tab(text: 'DRAFTS'),
                      Tab(text: 'COMMITTED'),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async {
          _loadDrafts();
          await _loadEntries();
        },
        color: Colors.blueAccent,
        child: TabBarView(
          controller: _tabController,
          children: _activityType == "Follow-up"
              ? [
                  _isLoadingEntries
                      ? _buildShimmerTable()
                      : _buildDataTable(
                          data: _committedNewEntries,
                          type: 'Committed Entries'),
                  _buildDataTable(data: _drafts, type: 'Drafts'),
                  _buildDataTable(data: _commits, type: 'Commits'),
                ]
              : [
                  _buildDataTable(data: _drafts, type: 'Drafts'),
                  _buildDataTable(data: _commits, type: 'Commits'),
                ],
        ),
      ),
      floatingActionButton: _activityType == "Baseline"
          ? FloatingActionButton(
              tooltip: 'Add New Entry',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/form_page',
                  arguments: {
                    'form_id': _formId,
                    'form_title': _formTitle,
                    'activity_type': _activityType,
                    'draft': null,
                  },
                ).then((_) => _loadDrafts());
              },
            )
          : FloatingActionButton(
              tooltip: 'Follow Up',
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final regionId = auth.regionId ?? '1';
                await auth.apiService
                    .fetchFollowUpEntriesFromApi(regionId, _formId!);
                setState(() {
                  _isLoadingEntries = true;
                  _loadEntries().then((_) => _isLoadingEntries = false);
                });
              }),
    );
  }
}
