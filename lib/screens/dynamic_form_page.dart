import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';
import '../models/draft_model.dart';
import '../services/draft_service.dart';
import '../utils/error_handler.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class DynamicFormPage extends StatefulWidget {
  const DynamicFormPage({super.key});

  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _didInit = false;
  bool _loading = false;
  late final DraftService _draftService;
  Map<String, dynamic>? _formData;
  Map<String, dynamic> _answers = {};
  final Map<String, XFile?> _images = {};
  final Map<String, TextEditingController> _controllers = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isPaused = false;
  final Map<String, dynamic> _areaData = {};
  final PageStorageKey _scrollKey = const PageStorageKey('formScrollKey');

  // Cache for form questions to avoid repeated processing
  List<dynamic>? _cachedQuestions;

  // Track the current draft being edited (if any)
  DraftModel? _currentDraft;

  // Add conditional logic support
  Map<String, dynamic>? _conditionalLogic;

  @override
  void initState() {
    super.initState();
    _draftService = Provider.of<DraftService>(context, listen: false);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _images.clear();
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isPaused = state == AppLifecycleState.paused;
    });
    if (state == AppLifecycleState.paused && !_isPaused) {
      // Only clear if not submitting
      _fadeController.stop();
      // Collect keys to remove to avoid concurrent modification
      final keysToRemove = <String>[];
      _controllers.forEach((key, controller) {
        if (!_answers.containsKey(key) || _answers[key] == null) {
          controller.dispose();
          keysToRemove.add(key);
        }
      });
      // Remove the keys after iteration
      for (var key in keysToRemove) {
        _controllers.remove(key);
      }
      // Clear temporary images to reduce memory usage
      _images.clear();
    } else if (state == AppLifecycleState.resumed) {
      if (!_fadeController.isAnimating) {
        _fadeController.forward();
      }
      _restoreDraftOnResume();
    }
  }

  Future<void> _restoreDraftOnResume() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null || !args.containsKey('form_id')) return;

    final formId = args['form_id']?.toString();
    final activityType = args['activity_type'] as String? ?? 'Baseline';
    if (formId == null) return;

    final draft = _draftService.getDraft(formId, activityType, DateTime.now());
    if (draft != null && mounted) {
      setState(() {
        _loadDraftFromModel(draft);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      // Use microtask to avoid blocking the UI thread
      Future.microtask(() => _initFetch());
    }
  }

  Future<void> _initFetch() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // Load missing data in parallel if needed
    if (user != null) {
      final futures = <Future>[];

      if (!auth.hasUserRegionData) {
        futures.add(auth.loadUserRegionData(user['user_id'].toString()));
      }
      if (!auth.hasProjects) {
        futures.add(auth.loadProjects());
      }
      if (!auth.hasOrganisations) {
        futures.add(auth.loadOrganisations());
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final formId = args['form_id']?.toString();
      if (formId != null) {
        await _loadFormFromMemory(formId);
        if (args.containsKey('draft') && args['draft'] != null) {
          _loadDraftFromModel(args['draft']);
        } else if (args.containsKey('follow_up_data') &&
            args['follow_up_data'] != null) {
          _loadFollowUpData(args['follow_up_data']);
        }
      }
    }

    // Initialize date fields efficiently
    if (_formData != null) {
      final questionList = _formData!['question_list'];
      if (questionList != null) {
        // Ensure proper type conversion for cached questions
        _cachedQuestions = List<dynamic>.from(questionList);
      } else {
        _cachedQuestions = [];
      }

      final now = DateTime.now().toIso8601String().split('T').first;

      for (var question in _cachedQuestions!) {
        if (question['answer_type']?.toString() == 'date') {
          final String questionId = question['question_id'].toString();
          final String answerKey = "qn$questionId";
          if (!_answers.containsKey(answerKey) ||
              _answers[answerKey] == null ||
              _answers[answerKey].isEmpty) {
            _answers[answerKey] = now;
          }
        }
      }
    }

    setState(() => _loading = false);
    _fadeController.forward();
  }

  void _loadDraftFromModel(DraftModel draft) {
    setState(() {
      _currentDraft = draft; // Store the current draft being edited
      _answers = Map<String, dynamic>.from(draft.answers);
      _answers.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = value.toString();
        } else {
          _controllers[key] = TextEditingController(text: value.toString());
        }
      });

      for (var entry in draft.images.entries) {
        if (entry.value.isNotEmpty) {
          final tempDir = Directory.systemTemp;
          final tempFile = File(
              '${tempDir.path}/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          final imageBytes = base64Decode(entry.value);
          tempFile.writeAsBytesSync(imageBytes);
          _images[entry.key] = XFile(tempFile.path);
          _answers[entry.key] = entry.value;
        }
      }
    });
  }

  void _loadFollowUpData(Map<String, dynamic> followUpData) {
    var responses = followUpData['responses'] is String
        ? jsonDecode(followUpData['responses'])
        : followUpData['responses'];
    if (responses is List && responses.isNotEmpty) {
      responses = responses.first;
    }
    setState(() {
      _answers = Map<String, dynamic>.from(responses);
      _answers.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = value.toString();
        } else {
          _controllers[key] = TextEditingController(text: value.toString());
        }
      });

      if (responses['photo'] != "null" && responses['photo'] != null) {
        _answers['photo'] = responses['photo'];
      }

      // Decode area fields (name -> id) for dropdown prefill
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userRegionData = auth.userRegionData;
      if (_formData != null && userRegionData != null) {
        final questionList = _formData!['question_list'] as List<dynamic>?;
        if (questionList != null) {
          for (final question in questionList) {
            if (question['answer_type'] == 'app_list') {
              final answerValues = question['answer_values'];
              final dbTable = answerValues['db_table'];
              String? areaType;
              String? idField;
              if (dbTable == 'app_district') {
                areaType = 'district';
                idField = 'district_id';
              }
              if (dbTable == 'app_sub_county') {
                areaType = 'sub_county';
                idField = 'sub_county_id';
              }
              if (dbTable == 'app_parish') {
                areaType = 'parish';
                idField = 'parish_id';
              }
              if (dbTable == 'app_village') {
                areaType = 'village';
                idField = 'village_id';
              }
              if (dbTable == 'region') {
                areaType = 'region';
                idField = 'region_id';
              }
              if (areaType != null && idField != null) {
                final qnKey = 'qn${question['question_id']}';
                final areaName = _answers[qnKey]?.toString();
                if (areaName != null && areaName.isNotEmpty) {
                  final list = userRegionData[dbTable] as List<dynamic>?;
                  if (list != null) {
                    final match = list.firstWhere(
                      (item) => (item['name']?.toString() ?? '') == areaName,
                      orElse: () => null,
                    );
                    if (match != null && match[idField] != null) {
                      _answers[qnKey] = match[idField].toString();
                    }
                  }
                }
              }
            }
          }
        }
      }
    });
  }

  Future<void> _loadFormFromMemory(String formId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final allForms = auth.forms;

    // Use more efficient search with proper type conversion
    Map<String, dynamic>? form;
    for (final f in allForms) {
      if (f['form_id'].toString() == formId) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        form = Map<String, dynamic>.from(f);
        break;
      }
    }

    if (form != null) {
      _formData = form;
      // Parse conditional logic if present
      _parseConditionalLogic();
    }
  }

  /// Parse and store conditional logic from form data
  void _parseConditionalLogic() {
    if (_formData != null && _formData!['conditional_logic'] != null) {
      _conditionalLogic =
          Map<String, dynamic>.from(_formData!['conditional_logic']);
      debugPrint('Loaded conditional logic:');
      debugPrint(jsonEncode(_conditionalLogic));
    } else {
      debugPrint('No conditional logic found in form data.');
      _conditionalLogic = null;
    }
  }

  /// Check if a question has conditional logic that should be triggered
  bool _hasConditionalLogic(String questionKey) {
    return _conditionalLogic?.containsKey(questionKey) ?? false;
  }

  /// Apply conditional logic when a trigger question value changes
  void _applyConditionalLogic(
      String triggerQuestionKey, dynamic selectedValue) {
    debugPrint('Conditional logic: ${jsonEncode(_conditionalLogic)}');
    debugPrint('Trigger: $triggerQuestionKey, Value: $selectedValue');
    if (!_hasConditionalLogic(triggerQuestionKey) || selectedValue == null) {
      debugPrint('No conditional logic for this trigger.');
      return;
    }

    // Safely convert to Map<String, dynamic>
    final rawConditionalRules = _conditionalLogic![triggerQuestionKey];
    final conditionalRules =
        (rawConditionalRules as Map).map((k, v) => MapEntry(k.toString(), v));

    final selectedValueString = selectedValue.toString();
    final rawRule = conditionalRules[selectedValueString];
    final rule = rawRule is Map
        ? rawRule.map((k, v) => MapEntry(k.toString(), v))
        : null;

    if (rule != null && rule['prefill'] != null) {
      final rawPrefillData = rule['prefill'];
      final prefillData =
          (rawPrefillData as Map).map((k, v) => MapEntry(k.toString(), v));
      debugPrint('Prefill data: ${jsonEncode(prefillData)}');
      setState(() {
        prefillData.forEach((questionKey, prefillValue) {
          // Detect if this is a checkbox question
          final question = _questions.firstWhere(
            (q) => 'qn${q['question_id']}' == questionKey,
            orElse: () => null,
          );
          if (question != null && question['answer_type'] == 'checkbox') {
            // If prefillValue is not a list, wrap it in a list
            if (prefillValue is List) {
              _answers[questionKey] = prefillValue;
            } else if (prefillValue != null &&
                prefillValue.toString().isNotEmpty) {
              _answers[questionKey] = [prefillValue];
            } else {
              _answers[questionKey] = [];
            }
          } else {
            _answers[questionKey] = prefillValue;
            if (_controllers.containsKey(questionKey)) {
              _controllers[questionKey]!.text = prefillValue.toString();
            }
          }
          debugPrint(
              'Prefilling $questionKey with value: ${_answers[questionKey]}');
        });
        debugPrint('Answers after prefill: ${jsonEncode(_answers)}');
      });
      if (mounted && prefillData.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Some fields have been automatically filled based on your selection',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blueAccent.withOpacity(0.8),
          ),
        );
      }
    } else {
      debugPrint('No prefill rule for this value.');
    }
  }

  /// Get questions that are affected by conditional logic
  List<String> _getAffectedQuestions(
      String triggerQuestionKey, dynamic selectedValue) {
    if (!_hasConditionalLogic(triggerQuestionKey) || selectedValue == null) {
      return [];
    }

    final conditionalRules =
        _conditionalLogic![triggerQuestionKey] as Map<String, dynamic>?;
    if (conditionalRules == null) return [];

    final selectedValueString = selectedValue.toString();
    final rule = conditionalRules[selectedValueString] as Map<String, dynamic>?;

    if (rule != null && rule['prefill'] != null) {
      final prefillData = rule['prefill'] as Map<String, dynamic>;
      return prefillData.keys.toList();
    }

    return [];
  }

  /// Check if a field has been auto-filled by conditional logic
  bool _isFieldAutoFilled(String questionKey) {
    // Check if this field was recently modified by conditional logic
    // You can enhance this by maintaining a separate set of auto-filled fields
    return false; // Simple implementation for now
  }

  /// Create a styled container for conditionally filled fields
  Widget _buildConditionalFieldContainer({
    required Widget child,
    required String questionKey,
    bool isAutoFilled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isAutoFilled
            ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2)
            : null,
        color: isAutoFilled ? Colors.orange.withOpacity(0.05) : null,
      ),
      child: Column(
        children: [
          if (isAutoFilled)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    size: 16,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto-filled',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }

  List<dynamic> get _questions {
    if (_cachedQuestions != null) {
      return _cachedQuestions!;
    }
    final questionList = _formData?['question_list'];
    if (questionList != null) {
      // Ensure proper type conversion for questions
      return List<dynamic>.from(questionList);
    }
    return [];
  }

  bool _validateForm() {
    if (_formData == null) return false;
    final questions = _questions;
    for (var question in questions) {
      bool required = question['required'] ?? true;
      if (!required) continue;
      final String questionId = question['question_id'].toString();
      final String answerKey = "qn$questionId";
      final answer = _answers[answerKey];
      if (answer == null ||
          (answer is String && answer.trim().isEmpty) ||
          (answer is List && answer.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveDraft() async {
    if (_formData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form data is not available.')),
      );
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final activityType = args?['activity_type'] as String? ?? 'Baseline';
    final formId = _formData!['form_id'].toString();
    final formTitle = _formData!['title'].toString();

    Map<String, String> imageMap = {};
    for (var entry in _images.entries) {
      if (entry.value != null) {
        final bytes = await File(entry.value!.path).readAsBytes();
        imageMap[entry.key] = base64Encode(bytes);
      }
    }

    //push activity type to draft into answers and call it entity_type
    _answers['entity_type'] = activityType;

    // If we're editing an existing draft, use its timestamp; otherwise create a new one
    final timestamp = _currentDraft?.timestamp ?? DateTime.now();

    final draft = DraftModel(
      formId: formId,
      title: formTitle,
      answers: Map<String, dynamic>.from(_answers),
      images: imageMap,
      timestamp: timestamp,
      status: 'draft',
    );

    // If we're editing an existing draft, update it; otherwise save as new
    if (_currentDraft != null) {
      await _draftService.updateDraft(draft, activityType);
    } else {
      await _draftService.saveDraft(draft, activityType);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentDraft != null
              ? 'Draft updated locally!'
              : 'Draft saved locally!'),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please fill all required fields before submitting.')),
        );
      }
      return;
    }
    if (_formData == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    setState(() {
      _isPaused = true;
    });

    final userId = user['user_id'].toString();
    final regionCode = auth.regionId ?? 'C';
    final formId = _formData!['form_id'].toString();
    final formTitle = _formData!['title'].toString();
    final subTitle = _answers['qn4']?.toString() ?? 'Default Subtitle';
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final activityType = args?['activity_type'] as String? ?? 'Baseline';
    String responseId;
    if (activityType == "Follow-up" &&
        args != null &&
        args['response_id'] != null) {
      responseId = args['response_id'].toString();
    } else {
      responseId = auth.generateResponseId(regionCode, int.parse(userId));
    }

    //update the responses for the keys that are in _areadData
    if (_areaData.isNotEmpty) {
      _areaData.forEach((key, value) {
        if (_answers.containsKey(key)) {
          _answers[key] = value;
        }
      });
    }

    try {
      Map<String, dynamic> submissionAnswers = jsonDecode(jsonEncode(_answers));
      submissionAnswers['entity_type'] =
          activityType.toLowerCase() == 'follow-up' ? 'followup' : 'baseline';
      submissionAnswers['creator_id'] = userId;
      submissionAnswers['created_at'] =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Set photo as filename, exclude photo_base64 and updated_at from submissionAnswers
      String? base64Photo;
      String photoFilename = "null";
      if (_images.containsKey("photo_base64")) {
        base64Photo = submissionAnswers['photo_base64'];
        photoFilename = "image_${DateTime.now().millisecondsSinceEpoch}.jpeg";
      }
      submissionAnswers['photo'] = photoFilename;
      submissionAnswers.remove('photo_base64');
      submissionAnswers.remove('updated_at'); // Remove updated_at if present

      final Map<String, dynamic> finalAnswers =
          Map<String, dynamic>.from(submissionAnswers);

      Map<String, dynamic> response;
      if (activityType == "Follow-up") {
        response = await auth.apiService.commitFollowUp(
          responseId: responseId,
          formId: formId,
          title: finalAnswers['qn65']?.toString() ?? formTitle,
          subTitle: subTitle,
          answers: finalAnswers,
          creatorId: userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Follow-up submitted successfully!')),
          );
        }
      } else {
        response = await auth.apiService.commitBaseline(
          responseId: responseId,
          formId: formId,
          title: finalAnswers['qn65']?.toString() ?? formTitle,
          subTitle: subTitle,
          answers: finalAnswers,
          creatorId: userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Baseline submitted successfully!')),
          );
        }

        if (_formData!['is_photograph'] == "1" && base64Photo != null) {
          try {
            await auth.apiService.commitPhoto(
              responseId: responseId,
              base64Data: base64Photo,
              filename: photoFilename,
              creatorId: int.parse(userId),
            );
          } catch (e) {
            // Photo commit failed
          }
        }
      }

      await _draftService.updateDraftStatus(formId, activityType, 'submitted');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final userFriendlyError = ErrorHandler.getFormSubmissionErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
      }
    }
  }

  TextEditingController _getController(String key, String initialValue) {
    if (_isPaused) {
      // Avoid creating new controllers when paused to save memory
      return TextEditingController(text: initialValue);
    }
    if (_controllers.containsKey(key)) {
      return _controllers[key]!;
    } else {
      final controller = TextEditingController(text: initialValue);
      _controllers[key] = controller;
      return controller;
    }
  }

  Widget _buildTextField(String key, String label) {
    final currentValue = _answers[key]?.toString() ?? '';
    final controller = _getController(key, currentValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            fillColor: Colors.grey[100],
            filled: true,
          ),
          onChanged: _isPaused
              ? null
              : (val) {
                  setState(() {
                    _answers[key] = val;
                  });
                  // Apply conditional logic if this text field triggers any
                  _applyConditionalLogic(key, val);
                },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNumberField(String key, String label) {
    final currentValue = _answers[key]?.toString() ?? '';
    final controller = _getController(key, currentValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            fillColor: Colors.grey[100],
            filled: true,
          ),
          onChanged: _isPaused
              ? null
              : (val) {
                  setState(() {
                    _answers[key] = val;
                  });
                  // Apply conditional logic if this number field triggers any
                  _applyConditionalLogic(key, val);
                },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRadioGroup(String key, String label, List<dynamic> optionsList) {
    final currentValue = _answers[key]?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...optionsList.map((opt) {
          return RadioListTile<String>(
            title: Text(
              opt.toString(),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            value: opt.toString(),
            groupValue: currentValue,
            activeColor: Colors.blueAccent,
            onChanged: _isPaused
                ? null
                : (val) {
                    setState(() {
                      _answers[key] = val;
                    });
                    // Apply conditional logic if this question triggers any
                    _applyConditionalLogic(key, val);
                  },
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCheckboxGroup(
      String key, String label, List<dynamic> optionsList) {
    List<dynamic> currentValues =
        _answers[key] is List ? _answers[key] : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...optionsList.map((opt) {
          return CheckboxListTile(
            title: Text(
              opt.toString(),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            value: currentValues.contains(opt),
            activeColor: Colors.blueAccent,
            onChanged: _isPaused
                ? null
                : (bool? selected) {
                    setState(() {
                      if (selected == true) {
                        currentValues.add(opt);
                      } else {
                        currentValues.remove(opt);
                      }
                      _answers[key] = currentValues;
                    });
                    // Apply conditional logic for checkbox selections
                    _applyConditionalLogic(key, currentValues);
                  },
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDatePicker(String key, String label) {
    final currentValue = _answers[key]?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        InkWell(
          onTap: _isPaused
              ? null
              : () async {
                  final DateTime initialDate = currentValue.isEmpty
                      ? DateTime.now()
                      : DateTime.parse(currentValue);
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.blueAccent,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black87,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blueAccent,
                              textStyle: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                          textTheme: TextTheme(
                            headlineSmall: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            bodyLarge: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            bodyMedium: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          dialogTheme: DialogThemeData(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _answers[key] = picked.toIso8601String().split('T').first;
                    });
                  }
                },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentValue.isEmpty ? 'Tap to select date' : currentValue,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: currentValue.isEmpty ? Colors.grey : Colors.black87,
                  ),
                ),
                const Icon(Icons.calendar_today,
                    color: Colors.blueAccent, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void updateAnswers($key, $value) {
    _answers[$key] = $value;
  }

  Widget _buildAppListDropdown(String key, String label, dynamic answerValues,
      {String? filterBy, String? parentValue}) {
    final String dbTable = answerValues?['db_table']?.toString() ?? '';
    final auth = Provider.of<AuthProvider>(context, listen: false);
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

    if (filterBy != null && parentValue != null && parentValue.isNotEmpty) {
      items = items
          .where((item) => item[filterBy]?.toString() == parentValue)
          .toList();
    }

    final Map<String, String> defaultValueFields = <String, String>{
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
        filterBy ??
        'id';
    List<DropdownMenuItem<String>> dropdownItems =
        items.map<DropdownMenuItem<String>>((e) {
      final String value = e[valueField]?.toString() ?? '';
      final String optionLabel = e['name'].toString();
      return DropdownMenuItem<String>(
        value: value,
        child: Text(
          optionLabel,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
      );
    }).toList();
    String? currentValue = _answers[key]?.toString();
    if (currentValue != null &&
        !dropdownItems.any((item) => item.value == currentValue)) {
      currentValue = null;
      _answers[key] = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey),
          ),
          child: DropdownButtonFormField<String>(
            value: currentValue,
            hint: Text(
              'Select one',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            items: dropdownItems,
            onChanged: _isPaused
                ? null
                : (val) {
                    setState(() {
                      _answers[key] = val;
                    });
                    // Apply conditional logic if this dropdown triggers any
                    _applyConditionalLogic(key, val);
                  },
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLocationPicker() {
    final currentCoordinates = _answers["coordinates"] ?? "";
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.blueAccent),
        title: Text(
          "Capture Location",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          currentCoordinates.isEmpty
              ? "No coordinates set"
              : currentCoordinates,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        onTap: _isPaused
            ? null
            : () async {
                bool serviceEnabled;
                LocationPermission permission;

                serviceEnabled = await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  // Location services are not enabled
                  return;
                }

                permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied) {
                    return;
                  }
                }

                if (permission == LocationPermission.deniedForever) {
                  // Permissions are denied forever
                  return;
                }

                final position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                );

                setState(() {
                  _answers["coordinates"] =
                      "${position.latitude},${position.longitude}";
                });
              },
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Conditionally display the image preview at the top
          if (_images.containsKey("photo_base64"))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(
                  File(_images["photo_base64"]!.path),
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            ),
          ListTile(
            leading: Icon(
              _images.containsKey("photo_base64")
                  ? Icons.edit
                  : Icons.photo_camera,
              color: Colors.blueAccent,
            ),
            title: Text(
              _images.containsKey("photo_base64")
                  ? "Retake or Pick Photo"
                  : "Capture or Pick Photo",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _images.containsKey("photo_base64")
                  ? "Tap to retake or pick a new photo"
                  : "No photo captured yet. Tap to add one.",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            onTap: _isPaused
                ? null
                : () async {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt,
                                    color: Colors.blueAccent),
                                title: const Text('Take Photo'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                  );
                                  if (image != null) {
                                    setState(() {
                                      _images["photo_base64"] = image;
                                      _answers["photo_base64"] = base64Encode(
                                        File(image.path).readAsBytesSync(),
                                      );
                                    });
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library,
                                    color: Colors.blueAccent),
                                title: const Text('Pick from Gallery'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                  );
                                  if (image != null) {
                                    setState(() {
                                      _images["photo_base64"] = image;
                                      _answers["photo_base64"] = base64Encode(
                                        File(image.path).readAsBytesSync(),
                                      );
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(dynamic question, int index, int totalQuestions) {
    final sequentialNumber = index + 1;
    final qlabel = question['question']?.toString() ?? 'No label';
    final questionId = question['question_id'].toString();
    final answerKey = "qn$questionId";
    final questionList = _questions;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Question $sequentialNumber / $totalQuestions: $qlabel",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (_) {
                final qtype = question['answer_type']?.toString() ?? 'text';
                switch (qtype) {
                  case 'radio':
                    final answerValues = question['answer_values'];
                    final options = answerValues != null
                        ? List<dynamic>.from(answerValues)
                        : [];
                    return _buildRadioGroup(answerKey, qlabel, options);
                  case 'checkbox':
                    final answerValues = question['answer_values'];
                    final options = answerValues != null
                        ? List<dynamic>.from(answerValues)
                        : [];
                    return _buildCheckboxGroup(answerKey, qlabel, options);
                  case 'number':
                    return _buildNumberField(answerKey, qlabel);
                  case 'date':
                    return _buildDatePicker(answerKey, qlabel);
                  case 'app_list':
                    final String currentDb =
                        question['answer_values']['db_table'].toString();
                    String? filterByField;
                    String? parentValue;
                    if (currentDb == 'app_sub_county') {
                      filterByField = 'district_id';
                      for (int i = index - 1; i >= 0; i--) {
                        final q = questionList[i];
                        if (q['answer_type'] == 'app_list' &&
                            q['answer_values']['db_table'] == 'app_district') {
                          parentValue = _answers["qn${q['question_id']}"];
                          var items =
                              Provider.of<AuthProvider>(context, listen: false)
                                      .userRegionData?['app_district'] ??
                                  [];

                          if (items.isNotEmpty) {
                            final item = items.firstWhere(
                              (item) =>
                                  item[filterByField]?.toString() ==
                                  parentValue,
                              orElse: () => {},
                            );
                            if (item.isNotEmpty) {
                              _areaData["qn${q['question_id']}"] =
                                  item['name']?.toString() ?? '';
                            }
                          }
                          break;
                        }
                      }
                    } else if (currentDb == 'app_parish') {
                      filterByField = 'sub_county_id';
                      for (int i = index - 1; i >= 0; i--) {
                        final q = questionList[i];
                        if (q['answer_type'] == 'app_list' &&
                            q['answer_values']['db_table'] ==
                                'app_sub_county') {
                          parentValue = _answers["qn${q['question_id']}"];

                          var items =
                              Provider.of<AuthProvider>(context, listen: false)
                                      .userRegionData?['app_sub_county'] ??
                                  [];

                          if (items.isNotEmpty) {
                            final item = items.firstWhere(
                              (item) =>
                                  item[filterByField]?.toString() ==
                                  parentValue,
                              orElse: () => {},
                            );
                            if (item.isNotEmpty) {
                              _areaData["qn${q['question_id']}"] =
                                  item['name']?.toString() ?? '';
                            }
                          }
                          break;
                        }
                      }
                    } else if (currentDb == 'app_village') {
                      filterByField = 'parish_id';
                      for (int i = index - 1; i >= 0; i--) {
                        final q = questionList[i];
                        if (q['answer_type'] == 'app_list' &&
                            q['answer_values']['db_table'] == 'app_parish') {
                          parentValue = _answers["qn${q['question_id']}"];

                          var items =
                              Provider.of<AuthProvider>(context, listen: false)
                                      .userRegionData?['app_parish'] ??
                                  [];

                          if (items.isNotEmpty) {
                            final item = items.firstWhere(
                              (item) =>
                                  item[filterByField]?.toString() ==
                                  parentValue,
                              orElse: () => {},
                            );
                            if (item.isNotEmpty) {
                              _areaData["qn${q['question_id']}"] =
                                  item['name']?.toString() ?? '';
                            }
                          }
                          break;
                        }
                      }
                    }
                    return _buildAppListDropdown(
                      answerKey,
                      qlabel,
                      question['answer_values'],
                      filterBy: filterByField,
                      parentValue: parentValue,
                    );
                  default:
                    return _buildTextField(answerKey, qlabel);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 50,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Loading Form...',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.blueAccent,
          elevation: 4,
        ),
        body: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(5, (index) => _buildShimmerCard()),
            ),
          ),
        ),
      );
    }
    if (_formData == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Form not found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    final title = _formData!['title'] ?? 'Untitled';
    final questionList = _questions;

    List<Widget> formWidgets = List.generate(questionList.length, (index) {
      final question = questionList[index];
      return _buildQuestion(question, index, questionList.length);
    });

    if (_formData!['is_geotagged'] == "1" || _formData!['is_geotagged'] == 1) {
      formWidgets.add(_buildLocationPicker());
    }

    if (_formData!['is_photograph'] == "1" ||
        _formData!['is_photograph'] == 1) {
      formWidgets.add(_buildImagePicker());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: _isPaused
          ? const SizedBox.shrink()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                key: _scrollKey,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: formWidgets,
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPaused
                  ? null
                  : () async {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.done_all),
                                  title: Text('Commit',
                                      style: GoogleFonts.poppins()),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _submitForm();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.save_alt),
                                  title: Text('Save and Commit',
                                      style: GoogleFonts.poppins()),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _saveDraft();
                                    await _submitForm();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.save),
                                  title: Text('Save as Draft',
                                      style: GoogleFonts.poppins()),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _saveDraft();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Submit',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
