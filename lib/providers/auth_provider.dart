import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _user;
  List<dynamic> _forms = [];
  String? _regionId; // Store region_id directly
  bool _isLoadingForms = false;
  Map<String, dynamic>? _userRegionData;
  List<dynamic> _projects = [];
  List<dynamic> _organisations = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  List<dynamic> get forms => _forms;
  bool get isLoadingForms => _isLoadingForms;
  Map<String, dynamic>? get userRegionData => _userRegionData;
  List<dynamic> get projects => _projects;
  List<dynamic> get organisations => _organisations;
  ApiService get apiService => _apiService;
  String? get regionId => _userRegionData?['region']?.first['region_id']?.toString();

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
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
      _user = null;
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
      if (response['status'] == 200) {
        _user = response['data'] as Map<String, dynamic>;
        _regionId = _user?['region_id']?.toString(); // Store region_id from login response
        await _persistUser(_user!);
      } else {
        throw Exception('Invalid login response: ${response['status']}');
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      throw Exception('Login failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _forms = [];
    _userRegionData = null;
    await clearUser();
    notifyListeners();
  }

  Future<void> fetchForms() async {
    _isLoadingForms = true;
    notifyListeners();
    try {
      _forms = await _apiService.fetchForms();
      debugPrint('Fetched forms (count: ${_forms.length})');
    } catch (e) {
      debugPrint('Error fetching forms: $e');
      throw Exception('Failed to fetch forms: $e');
    } finally {
      _isLoadingForms = false;
      notifyListeners();
    }
  }

  Future<void> loadUserRegionData(String userId) async {
    try {
      _userRegionData = await _apiService.fetchUserRegionAreas(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user region data: $e');
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
    try {
      _projects = await _apiService.fetchProjects();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading projects: $e');
      throw Exception('Failed to load projects: $e');
    }
  }

  Future<void> loadOrganisations() async {
    try {
      _organisations = await _apiService.fetchOrganisations();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading organisations: $e');
      throw Exception('Failed to load organisations: $e');
    }
  }
}