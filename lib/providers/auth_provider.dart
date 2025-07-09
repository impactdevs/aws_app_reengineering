import 'dart:convert';
import 'package:aws_app/services/offline_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/commit_service.dart';
import '../utils/error_handler.dart';
import 'package:dio/dio.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService(); // TODO: remove this
  bool _isLoading = false;
  Map<String, dynamic>? _user;
  List<dynamic> _forms = [];
  String? _regionId; // Store region_id directly
  bool _isLoadingForms = false;
  Map<String, dynamic>? _userRegionData;
  List<dynamic> _projects = [];
  List<dynamic> _organisations = [];

  // Cache flags to avoid reloading data
  bool _userRegionDataLoaded = false;
  bool _projectsLoaded = false;
  bool _organisationsLoaded = false;

  void setCommitService(CommitService commitService) {
    _apiService.setCommitService(commitService);
  }

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  List<dynamic> get forms => _forms;
  bool get isLoadingForms => _isLoadingForms;
  Map<String, dynamic>? get userRegionData => _userRegionData;
  List<dynamic> get projects => _projects;
  List<dynamic> get organisations => _organisations;
  ApiService get apiService => _apiService;
  String? get regionId =>
      _userRegionData?['region']?.first['region_id']?.toString();

  // Efficient data availability checks
  bool get hasUserRegionData =>
      _userRegionDataLoaded && _userRegionData != null;
  bool get hasProjects => _projectsLoaded && _projects.isNotEmpty;
  bool get hasOrganisations =>
      _organisationsLoaded && _organisations.isNotEmpty;

  Future<void> _persistUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  Future<void> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null) {
        _user = jsonDecode(userString);
        _regionId = prefs.getString('region_id'); // Load region ID
        notifyListeners();
        return;
      }
      // If not in SharedPreferences, check Hive
      final hiveProfile = await OfflineStorageService().getUserProfile();
      if (hiveProfile != null) {
        _user = hiveProfile;
        notifyListeners();
        return;
      }
      // If neither, ensure _user is null
      _user = null;
      notifyListeners();
    } catch (e) {
      _user = null;
      _regionId = null;
      notifyListeners();
    }
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password);

      // Handle response based on status code
      if (response['status'] == 200) {
        _user = response['data'] as Map<String, dynamic>;
        _regionId = _user?['region_id']?.toString();
        await _persistUser(_user!); // Persist only user data

        // Preload forms without blocking
        fetchForms().catchError((e) => debugPrint("Forms fetch error: $e"));
      } else {
        // Extract error message properly
        String message = response['messages']?['error'] ??
            response['message'] ??
            'Login failed';

        throw Exception(message);
      }
    } catch (e) {
      // Return original error for proper handling
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _forms = [];
    _userRegionData = null;
    _projects = [];
    _organisations = [];
    _userRegionDataLoaded = false;
    _projectsLoaded = false;
    _organisationsLoaded = false;
    await clearUser();
    //clear all hive data
    await OfflineStorageService().clearAllData();

    // clear shared preferences too
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> fetchForms() async {
    _isLoadingForms = true;
    notifyListeners();
    try {
      _forms = await _apiService.fetchForms();
    } catch (e) {
      throw Exception('Failed to fetch forms: $e');
    } finally {
      _isLoadingForms = false;
      notifyListeners();
    }
  }

  Future<void> loadUserRegionData(String userId) async {
    if (_userRegionDataLoaded && _userRegionData != null) {
      return; // Already loaded
    }

    try {
      _userRegionData = await _apiService.fetchUserRegionAreas(userId);
      _userRegionDataLoaded = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load user region data: $e');
    }
  }

  String generateResponseId(String regionCode, int userId) {
    const prefix = "AWS-";
    final userIdPadded = userId.toString().padLeft(4, '0');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "$prefix$regionCode-U$userIdPadded$timestamp";
  }

  Future<void> loadProjects() async {
    if (_projectsLoaded && _projects.isNotEmpty) {
      return; // Already loaded
    }

    try {
      _projects = await _apiService.fetchProjects();
      _projectsLoaded = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load projects: $e');
    }
  }

  Future<void> loadOrganisations() async {
    if (_organisationsLoaded && _organisations.isNotEmpty) {
      return; // Already loaded
    }

    try {
      _organisations = await _apiService.fetchOrganisations();
      _organisationsLoaded = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load organisations: $e');
    }
  }
}
