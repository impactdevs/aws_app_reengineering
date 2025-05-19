import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';
import '../models/draft_model.dart';
import '../services/draft_service.dart';
import 'package:intl/intl.dart';



class ImagePickerCard extends StatefulWidget {
  final Function(String, XFile) onImagePicked;
  final bool isPaused; // Controls whether image picking updates state

  const ImagePickerCard({
    super.key,
    required this.onImagePicked,
    required this.isPaused,
  });

  @override
  State<ImagePickerCard> createState() => _ImagePickerCardState();
}

class _ImagePickerCardState extends State<ImagePickerCard> with WidgetsBindingObserver {
  bool _isProcessingImage = false;
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appLifecycleState = state;
    });
    debugPrint('ImagePickerCard AppLifecycleState changed to: $state');
  }

  static Future<Map<String, dynamic>> _processImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      return {'path': path, 'base64Image': base64Image};
    } catch (e) {
      return {'error': 'Error processing image: $e'};
    }
  }

  Future<XFile?> _pickImage(ImageSource source, {int maxRetries = 2, int retryDelayMs = 500}) async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      debugPrint('Device Info: Model=${androidInfo.model}, Manufacturer=${androidInfo.manufacturer}, SDK=${androidInfo.version.sdkInt}');
      debugPrint('Available Memory: ${androidInfo.isPhysicalDevice ? "Physical Device" : "Emulator"}');
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        debugPrint('Attempt ${attempt + 1} to launch ${source == ImageSource.camera ? "camera" : "gallery"}...');
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 30,
          maxWidth: 800,
          maxHeight: 800,
        );
        return picked;
      } catch (e) {
        attempt++;
        debugPrint('${source == ImageSource.camera ? "Camera" : "Gallery"} launch attempt $attempt failed: $e');
        if (attempt >= maxRetries) {
          throw Exception('Failed to pick image from ${source == ImageSource.camera ? "camera" : "gallery"}: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelayMs));
      }
    }
    return null;
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Image Source',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                title: Text(
                  'Camera',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: Text(
                  'Gallery',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleImagePick(ImageSource source) async {
    // Request permissions based on the source
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to take photos.')),
          );
        }
        debugPrint('Camera permission denied');
        return;
      }
      if (cameraStatus.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Camera permission is permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        debugPrint('Camera permission permanently denied');
        return;
      }
    } else {
      // For gallery, request photos permission on Android 13+
      final photosStatus = await Permission.photos.request();
      if (photosStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photos permission is required to access the gallery.')),
          );
        }
        debugPrint('Photos permission denied');
        return;
      }
      if (photosStatus.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photos permission is permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        debugPrint('Photos permission permanently denied');
        return;
      }
    }

    bool storagePermissionRequired = false;
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt ?? 0;
      storagePermissionRequired = sdkVersion <= 29;
    }

    if (storagePermissionRequired) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to save photos.')),
          );
        }
        debugPrint('Storage permission denied');
        return;
      }
      if (storageStatus.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Storage permission is permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        debugPrint('Storage permission permanently denied');
        return;
      }
    } else {
      debugPrint('Storage permission not required (Android 11 or higher)');
    }

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final picked = await _pickImage(source);

      debugPrint('${source == ImageSource.camera ? "Camera" : "Gallery"} activity returned, picked: ${picked != null}');
      if (picked == null) {
        debugPrint('No image picked');
        if (mounted) {
          setState(() {
            _isProcessingImage = false;
          });
        }
        return;
      }

      debugPrint('Image picked, path: ${picked.path}');

      final result = await compute(_processImage, picked.path);

      debugPrint('Image processing result: $result');
      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      final base64Image = result['base64Image'];

      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted && !widget.isPaused) {
        setState(() {
          _image = picked;
          _isProcessingImage = false;
        });
        widget.onImagePicked(base64Image, picked);
        debugPrint('Image processed and state updated');
      } else {
        debugPrint('Activity not mounted or paused, skipping state update');
      }
    } catch (e) {
      debugPrint('Error during image capture: $e');
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImagePreview(BuildContext context) {
    if (_image == null || _appLifecycleState != AppLifecycleState.resumed || !mounted) {
      debugPrint('Cannot show preview: No image, not resumed, or widget not mounted');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.file(
                  File(_image!.path),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _image = null;
                        });
                      },
                      child: Text(
                        'Retake',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
            title: Text(
              "Capture Photo",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _isProcessingImage
                ? const CircularProgressIndicator(color: Colors.blueAccent)
                : ElevatedButton.icon(
                    onPressed: widget.isPaused ? null : _showImageSourceDialog,
                    icon: const Icon(Icons.image, color: Colors.white),
                    label: Text(
                      "Pick Image",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
          ),
          if (_image != null && !_isProcessingImage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  _showImagePreview(context);
                },
                icon: const Icon(Icons.preview, color: Colors.white),
                label: Text(
                  "Preview Photo",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
    debugPrint('DynamicFormPage AppLifecycleState changed to: $state');
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

    final draft =
        await _draftService.getDraft(formId, activityType, DateTime.now());
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
      _initFetch();
    }
  }

  Future<void> _initFetch() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    if (user != null) {
      if (auth.userRegionData == null) {
        await auth.loadUserRegionData(user['user_id'].toString());
      }
      if (auth.projects.isEmpty) {
        await auth.loadProjects();
      }
      if (auth.organisations.isEmpty) {
        await auth.loadOrganisations();
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

    if (_formData != null) {
      final List<dynamic> questions = _formData!['question_list'] ?? [];
      for (var question in questions) {
        if (question['answer_type']?.toString() == 'date') {
          final String questionId = question['question_id'].toString();
          final String answerKey = "qn$questionId";
          if (!_answers.containsKey(answerKey) ||
              _answers[answerKey] == null ||
              _answers[answerKey].isEmpty) {
            _answers[answerKey] =
                DateTime.now().toIso8601String().split('T').first;
          }
        }
      }
    }

    setState(() => _loading = false);
    _fadeController.forward();
  }

  void _loadDraftFromModel(DraftModel draft) {
    setState(() {
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
    final responses = followUpData['responses'] is String
        ? jsonDecode(followUpData['responses'])
        : followUpData['responses'];
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
    });
  }

  Future<void> _loadFormFromMemory(String formId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final allForms = auth.forms;
    final form = allForms.firstWhere(
      (f) => f['form_id'].toString() == formId,
      orElse: () => null,
    );

    if (form != null) {
      _formData = form;
    } else {
      debugPrint('Form with id $formId not found in memory');
    }
    setState(() => _loading = false);
  }

  bool _validateForm() {
    if (_formData == null) return false;
    final List<dynamic> questions = _formData!['question_list'] ?? [];
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

    final draft = DraftModel(
      formId: formId,
      title: formTitle,
      answers: Map<String, dynamic>.from(_answers),
      images: imageMap,
      timestamp: DateTime.now(),
      status: 'draft',
    );

    await _draftService.saveDraft(draft, activityType);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved locally!')),
      );
      Navigator.pop(context);
    }
  }

Future<void> _submitForm() async {
  if (!_validateForm()) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields before submitting.')),
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
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  final activityType = args?['activity_type'] as String? ?? 'Baseline';
  final responseId = auth.generateResponseId(regionCode, int.parse(userId));

  try {
    Map<String, dynamic> submissionAnswers = jsonDecode(jsonEncode(_answers));
    submissionAnswers['entity_type'] = activityType.toLowerCase() == 'follow-up' ? 'followup' : 'baseline';
    submissionAnswers['creator_id'] = userId;
    submissionAnswers['created_at'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

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

    debugPrint('submissionAnswers in _submitForm after adding fields:');
    submissionAnswers.forEach((key, value) {
      debugPrint('$key: $value');
    });

    final Map<String, dynamic> finalAnswers = Map<String, dynamic>.from(submissionAnswers);

    debugPrint('finalAnswers before API call:');
    finalAnswers.forEach((key, value) {
      debugPrint('$key: $value');
    });

    Map<String, dynamic> response;
    if (activityType == "Follow-up") {
      debugPrint('Submitting follow-up with finalAnswers: [logged above]');
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
      debugPrint('Submitting baseline with finalAnswers: [logged above]');
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
        Future.delayed(const Duration(minutes: 5), () async {
          try {
            await auth.apiService.commitPhoto(
              responseId: responseId,
              base64Data: base64Photo!,
              filename: photoFilename,
              creatorId: int.parse(userId),
            );
            debugPrint('Photo committed successfully after 5-minute delay for responseId: $responseId');
          } catch (e) {
            debugPrint('Error committing photo after delay: $e');
          }
        });
      }
    }

    await _draftService.updateDraftStatus(formId, activityType, 'submitted');
    if (mounted) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    debugPrint('Error submitting form: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting form: $e')),
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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
                  },
          );
        }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCheckboxGroup(
      String key, String label, List<dynamic> optionsList) {
    List<dynamic> currentValues = _answers[key] is List ? _answers[key] : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
                  },
          );
        }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDatePicker(String key, String label) {
    final currentValue = _answers[key]?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
                          dialogBackgroundColor: Colors.white,
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
                          dialogTheme: DialogTheme(
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

  Widget _buildAppListDropdown(String key, String label, dynamic answerValues,
      {String? filterBy, String? parentValue}) {
    final dbTable = answerValues?['db_table']?.toString() ?? '';
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
        filterBy ??
        'id';

    List<DropdownMenuItem<String>> dropdownItems = items.map((e) {
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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
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
            : () {
                setState(() {
                  _answers["coordinates"] = "0.3554125,32.6164299";
                });
              },
      ),
    );
  }

// In DynamicFormPage
  Widget _buildImagePicker() {
    return ImagePickerCard(
      onImagePicked: (base64Image, picked) {
        if (!_isPaused) {
          setState(() {
            _images["photo_base64"] = picked;
            _answers["photo_base64"] = base64Image;
          });
        }
      },
      isPaused: _isPaused,
    );
  }

  Widget _buildQuestion(dynamic question, int index, int totalQuestions) {
    final sequentialNumber = index + 1;
    final qlabel = question['question']?.toString() ?? 'No label';
    final questionId = question['question_id'].toString();
    final answerKey = "qn$questionId";
    final questionList = _formData!['question_list'] as List<dynamic>? ?? [];

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
                    final options =
                        question['answer_values'] as List<dynamic>? ?? [];
                    return _buildRadioGroup(answerKey, qlabel, options);
                  case 'checkbox':
                    final options =
                        question['answer_values'] as List<dynamic>? ?? [];
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
    final questionList = _formData!['question_list'] as List<dynamic>? ?? [];

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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: formWidgets,
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPaused ? null : _saveDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Save Draft',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPaused ? null : _submitForm,
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
            ],
          ),
        ),
      ),
    );
  }
}
