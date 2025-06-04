import 'package:hive_flutter/hive_flutter.dart';

class OfflineStorageService {
  // Box names for different data types
  static const String _formsBox = 'forms';
  static const String _followUpEntriesBox = 'followUpEntries';
  static const String _baselineEntriesBox = 'baselineEntries';
  static const String _projectsBox = 'projects';
  static const String _organisationsBox = 'organisations';
  static const String _userRegionAreasBox = 'userRegionAreas';
  // user profile data
  static const String _userProfileBox = 'profile';

  Future<Box<dynamic>>? _storageFuture;

  // init
  Future<void> init() async {
    await Hive.initFlutter();
    // Hive.registerAdapter(YourModelAdapter());
    _storageFuture = Hive.openBox<dynamic>('offline_storage');
  }

  // user  profile
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final box = await _storage;
    await box.put(_userProfileBox, profile);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final box = await _storage;
    return box.get(_userProfileBox) as Map<String, dynamic>?;
  }

  Future<Box<dynamic>> get _storage async {
    if (_storageFuture == null) {
      await Hive.initFlutter();
      _storageFuture = Hive.openBox<dynamic>('offline_storage');
    }
    return _storageFuture!;
  }

  // ================= Forms Storage =================
  Future<void> saveForms(List<dynamic> forms) async {
    final box = await _storage;
    await box.put(_formsBox, forms);
  }

  Future<List<dynamic>?> getForms() async {
    final box = await _storage;
    return box.get(_formsBox);
  }

  // ================= Follow-up Entries Storage =================
  Future<void> saveFollowUpEntries(
      String regionId, String formId, List<dynamic> entries) async {
    final box = await _storage;
    final key = _followUpKey(regionId, formId);
    await box.put(key, entries);
  }

  Future<List<dynamic>?> getFollowUpEntries(
      String regionId, String formId) async {
    final box = await _storage;
    final key = _followUpKey(regionId, formId);
    return box.get(key) as List<dynamic>?;
  }

  String _followUpKey(String regionId, String formId) =>
      '$_followUpEntriesBox|$regionId|$formId';

  // ================= Baseline Entries Storage =================
  Future<void> saveBaselineEntries(
      String regionId, String formId, List<dynamic> entries) async {
    final box = await _storage;
    final key = _baselineKey(regionId, formId);
    await box.put(key, entries);
  }

  Future<List<dynamic>?> getBaselineEntries(
      String regionId, String formId) async {
    final box = await _storage;
    final key = _baselineKey(regionId, formId);
    return box.get(key) as List<dynamic>?;
  }

  String _baselineKey(String regionId, String formId) =>
      '$_baselineEntriesBox|$regionId|$formId';

  // ================= Projects Storage =================
  Future<void> saveProjects(List<dynamic> projects) async {
    final box = await _storage;
    await box.put(_projectsBox, projects);
  }

  Future<List<dynamic>?> getProjects() async {
    final box = await _storage;
    return box.get(_projectsBox) as List<dynamic>?;
  }

  // ================= Organisations Storage =================
  Future<void> saveOrganisations(List<dynamic> organisations) async {
    final box = await _storage;
    await box.put(_organisationsBox, organisations);
  }

  Future<List<dynamic>?> getOrganisations() async {
    final box = await _storage;
    return box.get(_organisationsBox) as List<dynamic>?;
  }

  // ================= User Region Areas Storage =================
  Future<void> saveUserRegionAreas(
      String userId, Map<String, dynamic> areas) async {
    final box = await _storage;
    final key = _userRegionKey(userId);
    await box.put(key, areas);
  }

  Future<Map<String, dynamic>?> getUserRegionAreas(String userId) async {
    final box = await _storage;
    final key = _userRegionKey(userId);
    return box.get(key) as Map<String, dynamic>?;
  }

  String _userRegionKey(String userId) => '$_userRegionAreasBox|$userId';

  // ================= Utility Methods =================
  Future<void> clearAllData() async {
    final box = await _storage;
    await box.clear();
  }
}
