import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  final String baseUrl = 'https://dev.impact-outsourcing.com/aws.api/public';
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://dev.impact-outsourcing.com/aws.api/public'));

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      debugPrint('Login request: $username, $password');
      final response = await _dio.post(
        '/user/authenticate',
        data: FormData.fromMap({
          'username': username,
          'password': password,
        }),
      );
      debugPrint('Login response: ${response.data}');
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Login failed, status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in login: $e');
      throw Exception('Error: $e');
    }
  }

  Future<List<dynamic>> fetchForms() async {
    try {
      debugPrint('Fetching forms with published=1');
      final response = await _dio.get('/forms', queryParameters: {'published': 1});
      debugPrint('Fetch forms response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      } else {
        throw Exception('Failed to fetch forms, code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in fetchForms: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchFollowUpEntries(String regionId, String formId) async {
    try {
      debugPrint('Fetching follow-up entries with region_id: $regionId, form_id: $formId');
      final response = await _dio.get(
        '/entry/downloadable_region_entries',
        queryParameters: {'region_id': regionId, 'form_id': formId},
      );
      debugPrint('Follow-up entries response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      } else if (response.statusCode == 404) {
        debugPrint('No follow-up entries found (404), returning empty list');
        return [];
      } else {
        throw Exception('Failed to fetch follow-up entries, code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in fetchFollowUpEntries: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchCommittedBaselineEntries(String regionId, String formId) async {
    try {
      debugPrint('Fetching baseline entries with region_id: $regionId, form_id: $formId');
      final response = await _dio.get(
        '/entry/downloadable_region_entries',
        queryParameters: {
          'region_id': regionId,
          'form_id': formId,
          'entity_type': 'baseline',
        },
      );
      debugPrint('Baseline entries response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      } else if (response.statusCode == 404) {
        debugPrint('No baseline entries found (404), returning empty list');
        return [];
      } else {
        throw Exception('Failed to fetch committed baseline entries, code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in fetchCommittedBaselineEntries: $e');
      return [];
    }
  }

Future<Map<String, dynamic>> commitBaseline({
  required String responseId,
  required String formId,
  required String title,
  required String subTitle,
  required Map<String, dynamic> answers,
  required String creatorId,
}) async {
  try {
    Map<String, dynamic> submissionAnswers = jsonDecode(jsonEncode(answers));
    
    debugPrint('commitBaseline received answers:');
    submissionAnswers.forEach((key, value) {
      debugPrint('$key: $value');
    });
    
    submissionAnswers['entity_type'] = submissionAnswers['entity_type'] ?? 'baseline';
    submissionAnswers['creator_id'] = submissionAnswers['creator_id'] ?? creatorId;
    submissionAnswers['created_at'] = submissionAnswers['created_at'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    submissionAnswers['photo'] = submissionAnswers['photo'] ?? 'null';

    debugPrint('submissionAnswers before JSON encoding:');
    submissionAnswers.forEach((key, value) {
      debugPrint('$key: $value');
    });

    final responsesJson = jsonEncode(submissionAnswers);

    FormData formData = FormData.fromMap({
      'response_id': responseId,
      'form_id': formId,
      'title': title,
      'sub_title': subTitle,
      'responses': responsesJson,
    });

    debugPrint('FormData fields:');
    formData.fields.forEach((field) {
      debugPrint('${field.key}: ${field.value}');
    });

    final url = '$baseUrl/entry/add';
    debugPrint('Committing baseline to $url');
    final resp = await _dio.post(url, data: formData);
    debugPrint('Baseline commit response: ${resp.statusCode}, data: ${resp.data}');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      debugPrint('Baseline committed successfully!');
      return resp.data;
    } else {
      debugPrint('Failed to commit baseline. Code: ${resp.statusCode}');
      throw Exception('Failed to commit baseline. Code: ${resp.statusCode}');
    }
  } catch (e) {
    debugPrint('Error in commitBaseline: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> commitFollowUp({
  required String responseId,
  required String formId,
  required String title,
  required String subTitle,
  required Map<String, dynamic> answers,
  required String creatorId, // Require creator_id
}) async {
  try {
    // Create a new map to avoid modifying the input answers
    Map<String, dynamic> submissionAnswers = Map.from(answers);
    
    // Dynamically append required fields if not present
    submissionAnswers['entity_type'] = submissionAnswers['entity_type'] ?? 'followup';
    submissionAnswers['creator_id'] = submissionAnswers['creator_id'] ?? creatorId;
    submissionAnswers['created_at'] = submissionAnswers['created_at'] ?? DateTime.now().toString();

    final responsesJson = jsonEncode(submissionAnswers);
    FormData formData = FormData.fromMap({
      'response_id': responseId,
      'form_id': formId,
      'title': title,
      'sub_title': subTitle,
      'responses': responsesJson,
    });
    final url = '$baseUrl/entry/add-followup';
    debugPrint('Committing follow-up: $formData');
    final resp = await _dio.post(url, data: formData);
    debugPrint('Follow-up commit response: ${resp.statusCode}, data: ${resp.data}');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      debugPrint('Follow-up committed successfully!');
      return resp.data;
    } else {
      debugPrint('Failed to commit follow-up. Code: ${resp.statusCode}');
      throw Exception('Failed to commit follow-up. Code: ${resp.statusCode}');
    }
  } catch (e) {
    debugPrint('Error in commitFollowUp: $e');
    rethrow;
  }
}

Future<void> commitPhoto({
  required String responseId,
  required String base64Data,
  required String filename,
  required int creatorId,
}) async {
  try {
    String normalizedBase64 = base64Data.replaceAll('\n', '').trim();
    const prefix = "data:image/jpeg;base64,";
    if (normalizedBase64.startsWith(prefix)) {
      normalizedBase64 = normalizedBase64.substring(prefix.length);
    }
    debugPrint('Base64 length after normalization: ${normalizedBase64.length}');
    FormData formData = FormData.fromMap({
      'response_id': responseId,
      'photo_base64': normalizedBase64,
      'filename': filename,
      'creator_id': creatorId.toString(),
    });
    final options = Options(contentType: "multipart/form-data");
    debugPrint('Committing photo: responseId: $responseId, filename: $filename, creatorId: $creatorId');
    debugPrint('FormData fields for commitPhoto:');
    formData.fields.forEach((field) {
      debugPrint('${field.key}: ${field.value.length > 100 ? "${field.key}: [${field.value.substring(0, 100)}... (length=${field.value.length})]" : "${field.key}: ${field.value}"}');
    });
    final url = '$baseUrl/entry/add-photo';
    final resp = await _dio.post(url, data: formData, options: options);
    debugPrint('Photo commit response: ${resp.statusCode}, data: ${resp.data}');
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      debugPrint('Photo committed successfully!');
    } else {
      debugPrint('Failed to commit photo: ${resp.statusCode} - ${resp.data}');
      throw Exception('Failed to commit photo: ${resp.statusCode} - ${resp.data}');
    }
  } catch (e) {
    debugPrint('Error in commitPhoto: $e');
    rethrow;
  }
}

  Future<List<dynamic>> fetchProjects() async {
    try {
      final response = await _dio.get('/projects');
      debugPrint('Fetch projects response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to fetch projects');
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      throw Exception('Error fetching projects: $e');
    }
  }

  Future<List<dynamic>> fetchOrganisations() async {
    try {
      final response = await _dio.get('/organisations');
      debugPrint('Fetch organisations response: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to fetch organisations');
      }
    } catch (e) {
      debugPrint('Error fetching organisations: $e');
      throw Exception('Error fetching organisations: $e');
    }
  }

    Future<Map<String, dynamic>> fetchUserRegionAreas(String userId) async {
    try {
      final response = await _dio.get('/user-region-areas', queryParameters: {'user_id': userId});
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw Exception('Failed to fetch user region areas');
      }
    } catch (e) {
      debugPrint('Error fetching user region areas: $e');
      throw Exception('Error fetching user region areas: $e');
    }
  }
}