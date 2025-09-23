import 'dart:convert';
import 'package:aws_app/services/commit_service.dart';
import 'package:aws_app/models/commit_model.dart';

import 'offline_service.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class ApiService {
  final String baseUrl = 'https://dev.impact-outsourcing.com/aws.api/public';
  final Dio _dio = Dio(BaseOptions(
      baseUrl: 'https://dev.impact-outsourcing.com/aws.api/public'));
  final OfflineStorageService offlineStorage = OfflineStorageService();
  CommitService? _commitService;

  void setCommitService(CommitService commitService) {
    _commitService = commitService;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/user/authenticate',
        data: FormData.fromMap({
          'username': username,
          'password': password,
        }),
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final profile = response.data;

        // Validate response structure
        if (profile == null || profile['data'] == null) {
          throw Exception('Invalid response format from server');
        }

        await offlineStorage.saveUserProfile(profile);

        // Fetch all data in parallel for better performance
        final userId = profile['data']['user_id'].toString();
        final regionId = profile['data']['region_id'].toString();

        // Fetch forms, projects, organizations, and user region areas in parallel
        await Future.wait([
          fetchFormsFromApi(),
          fetchProjectsFromApi(),
          fetchOrganisationsFromApi(),
          fetchUserRegionAreasFromApi(userId),
        ]);

        // Fetch form-specific data in parallel
        final forms = await fetchForms();

        if (forms.isNotEmpty) {
          final formDataFutures = forms.map((form) async {
            final formId = form['form_id'].toString();
            await Future.wait([
              fetchFollowUpEntriesFromApi(regionId, formId),
              fetchCommittedBaselineEntries(regionId, formId),
            ]);
          }).toList();

          await Future.wait(formDataFutures);
        }

        return response.data;
      } else {
        // Handle non-200 status codes
        final statusCode = response.statusCode;
        final responseData = response.data;
        String errorMessage = 'Login failed';

        if (responseData is Map<String, dynamic>) {
          errorMessage =
              responseData['message'] ?? responseData['error'] ?? errorMessage;
        }

        switch (statusCode) {
          case 401:
            throw Exception(
                'Invalid credentials. Please check your email and password.');
          case 403:
            throw Exception(
                'Access denied. Your account may be disabled or you don\'t have permission to access this application.');
          case 404:
            throw Exception(
                'User account not found. Please check your email address.');
          case 500:
            throw Exception(
                'Server error. Please try again later or contact support if the problem persists.');
          default:
            throw Exception('Login failed: $errorMessage');
        }
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception(
              'Connection timeout. Please check your internet connection and try again.');
        case DioExceptionType.connectionError:
          throw Exception(
              'Unable to connect to server. Please check your internet connection.');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final responseData = e.response?.data;
          String errorMessage = 'Login failed';

          if (responseData is Map<String, dynamic>) {
            errorMessage = responseData['message'] ??
                responseData['error'] ??
                errorMessage;
          }

          switch (statusCode) {
            case 401:
              throw Exception(
                  'Invalid credentials. Please check your email and password.');
            case 403:
              throw Exception(
                  'Access denied. Your account may be disabled or you don\'t have permission to access this application.');
            case 404:
              throw Exception(
                  'User account not found. Please check your email address.');
            case 500:
              throw Exception(
                  'Server error. Please try again later or contact support if the problem persists.');
            default:
              throw Exception('Login failed: $errorMessage');
          }
        case DioExceptionType.cancel:
          throw Exception('Login request was cancelled.');
        default:
          throw Exception(
              'Network error. Please check your internet connection and try again.');
      }
    } catch (e) {
      // Handle other exceptions
      if (e.toString().contains('SocketException')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      } else if (e.toString().contains('timeout')) {
        throw Exception(
            'Connection timeout. Please check your internet connection and try again.');
      } else {
        throw Exception('Login failed: ${e.toString()}');
      }
    }
  }

  Future<List<dynamic>> fetchFormsFromApi() async {
    try {
      final response =
          await _dio.get('/forms', queryParameters: {'published': 1});
      if (response.statusCode == 200 && response.data['data'] != null) {
        final forms = response.data['data'];
        await offlineStorage.saveForms(forms);
        return forms;
      } else {
        throw Exception('Failed to fetch forms, code: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  //offline forms
  Future<List<dynamic>> fetchForms() async {
    try {
      final forms = await offlineStorage.getForms();
      
      if (forms != null) {
        return forms;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchFollowUpEntriesFromApi(
      String regionId, String formId) async {
    try {
      final response = await _dio.get(
        '/entry/downloadable_region_entries',
        queryParameters: {'region_id': regionId, 'form_id': formId},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        final entries = response.data['data'];
        await offlineStorage.saveFollowUpEntries(regionId, formId, entries);
        return entries;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
            'Failed to fetch follow-up entries, code: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }

  //fetch followup entries offline
  Future<List<dynamic>> fetchFollowUpEntries(
      String regionId, String formId) async {
    try {
      final entries = await offlineStorage.getFollowUpEntries(regionId, formId);
      if (entries != null) {
        return entries;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchCommittedBaselineEntriesFromApi(
      String regionId, String formId) async {
    try {
      final response = await _dio.get(
        '/entry/committed_baseline_entries',
        queryParameters: {'region_id': regionId, 'form_id': formId},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        final entries = response.data['data'];
        await offlineStorage.saveCommittedBaselineEntries(regionId, formId, entries);
        return entries;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
            'Failed to fetch committed baseline entries, code: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchCommittedBaselineEntries(
      String regionId, String formId) async {
    try {
      List<dynamic> allEntries = [];

      print('DEBUG: Fetching committed baseline entries for formId: $formId');

      // Get entries from offline storage (from API refresh)
      final offlineEntries = await offlineStorage.getCommittedBaselineEntries(regionId, formId);
      if (offlineEntries != null && offlineEntries.isNotEmpty) {
        print('DEBUG: Found ${offlineEntries.length} offline entries');
        allEntries.addAll(offlineEntries);
      } else {
        print('DEBUG: No offline entries found');
      }

      // Get local commits (from user commits) and add them too
      if (_commitService != null) {
        final localCommits = await _commitService!.getAllCommits(formId);
        print('DEBUG: Found ${localCommits?.length ?? 0} total local commits');

        if (localCommits != null && localCommits.isNotEmpty) {
          // Filter only baseline commits that are submitted
          final baselineCommits = localCommits.where((commit) {
            if (commit is Map<String, dynamic>) {
              return commit['answers']?['entity_type'] == 'baseline';
            }
            // Handle CommitModel objects
            final isBaseline = commit.answers['entity_type'] == 'baseline';
            print('DEBUG: Commit entity_type: ${commit.answers['entity_type']}, isBaseline: $isBaseline');
            return isBaseline;
          }).toList();

          print('DEBUG: Found ${baselineCommits.length} baseline commits');

          // Transform CommitModel objects to match the expected format
          for (final commit in baselineCommits) {
            if (commit is CommitModel) {
              // Transform CommitModel to match API response format
              final transformedCommit = {
                'title': commit.title,
                'sub_title': commit.answers['qn9']?.toString() ?? 'Unknown Area', // Assuming qn9 is village/area
                'parish': commit.answers['qn8']?.toString() ?? 'Unknown Parish', // Assuming qn8 is parish
                'district': commit.answers['qn4']?.toString() ?? 'Unknown District',
                'sub_county': commit.answers['qn7']?.toString() ?? 'Unknown Sub County',
                'village': commit.answers['qn9']?.toString() ?? 'Unknown Village',
                'creator_id': commit.answers['creator_id']?.toString() ?? 'Unknown',
                'response_id': 'local_${commit.timestamp.millisecondsSinceEpoch}', // Generate a unique ID
                'form_id': commit.formId,
                'created_at': commit.timestamp.toIso8601String(),
                'updated_at': commit.timestamp.toIso8601String(),
                'responses': [commit.answers], // Wrap answers in responses array to match API format
              };
              allEntries.add(transformedCommit);
              print('DEBUG: Transformed local CommitModel to API format: ${transformedCommit['title']}');
            } else {
              // Already in the right format (Map)
              allEntries.add(commit);
            }
          }
        }
      } else {
        print('DEBUG: CommitService is null when fetching');
      }

      print('DEBUG: Total entries to return: ${allEntries.length}');
      return allEntries;
    } catch (e) {
      print('DEBUG: Error fetching committed baseline entries: $e');
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

      submissionAnswers['entity_type'] =
          submissionAnswers['entity_type'] ?? 'baseline';
      submissionAnswers['creator_id'] =
          submissionAnswers['creator_id'] ?? creatorId;
      submissionAnswers['created_at'] = submissionAnswers['created_at'] ??
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      submissionAnswers['photo'] = submissionAnswers['photo'] ?? 'null';

      final responsesJson = jsonEncode(submissionAnswers);

      FormData formData = FormData.fromMap({
        'response_id': responseId,
        'form_id': formId,
        'title': title,
        'sub_title': subTitle,
        'responses': responsesJson,
        'created_at': submissionAnswers['created_at'] ??
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
      });

      final url = '$baseUrl/entry/add';
      final resp = await _dio.post(url, data: formData);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // After successful server commit, also save locally for immediate availability
        if (_commitService != null) {
          try {
            print('DEBUG: Saving baseline commit locally for formId: $formId');

            // Save to local commit service so it appears immediately in Follow-up tab
            await _commitService!.saveCommit(
              CommitModel(
                formId: formId,
                title: title,
                answers: submissionAnswers,
                images: {}, // Empty images map for now
                timestamp: DateTime.now(),
                status: 'submitted'
              ),
              'Baseline'
            );

            print('DEBUG: Successfully saved baseline commit locally');
          } catch (e) {
            print('DEBUG: Failed to save baseline commit locally: $e');
            // Local save failed, but server commit succeeded - this is acceptable
          }
        } else {
          print('DEBUG: CommitService is null, cannot save locally');
        }
        return resp.data;
      } else {
        throw Exception('Failed to commit baseline. Code: ${resp.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> commitFollowUp({
    required String responseId,
    required String formId,
    required String title,
    required String subTitle,
    required Map<String, dynamic> answers,
    required String creatorId,
  }) async {
    try {
      Map<String, dynamic> submissionAnswers = Map.from(answers);

      submissionAnswers['entity_type'] =
          submissionAnswers['entity_type'] ?? 'followup';
      submissionAnswers['creator_id'] =
          submissionAnswers['creator_id'] ?? creatorId;
      submissionAnswers['created_at'] = submissionAnswers['created_at'] ??
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final responsesJson = jsonEncode(submissionAnswers);
      FormData formData = FormData.fromMap({
        'response_id': responseId,
        'form_id': formId,
        'title': title,
        'sub_title': subTitle,
        'responses': responsesJson,
      });
      final url = '$baseUrl/entry/add-followup';
      final resp = await _dio.post(url, data: formData);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return resp.data;
      } else {
        throw Exception('Failed to commit follow-up. Code: ${resp.statusCode}');
      }
    } catch (e) {
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
      FormData formData = FormData.fromMap({
        'response_id': responseId,
        'photo_base64': normalizedBase64,
        'filename': filename,
        'creator_id': creatorId.toString(),
      });
      final options = Options(contentType: "multipart/form-data");
      final url = '$baseUrl/entry/add-photo';
      final resp = await _dio.post(url, data: formData, options: options);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Photo committed successfully
      } else {
        throw Exception(
            'Failed to commit photo: ${resp.statusCode} - ${resp.data}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> fetchProjectsFromApi() async {
    try {
      final response = await _dio.get('/projects');
      if (response.statusCode == 201 || response.statusCode == 200) {
        final projects = response.data['data'];
        await offlineStorage.saveProjects(projects);
        return projects;
      } else {
        throw Exception('Failed to fetch projects');
      }
    } catch (e) {
      throw Exception('Error fetching projects: $e');
    }
  }

  //offline
  Future<List<dynamic>> fetchProjects() async {
    try {
      final projects = await offlineStorage.getProjects();
      if (projects != null) {
        return projects;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchOrganisationsFromApi() async {
    try {
      final response = await _dio.get('/organisations');
      if (response.statusCode == 201 || response.statusCode == 200) {
        final organisations = response.data['data'];
        await offlineStorage.saveOrganisations(organisations);
        return organisations;
      } else {
        throw Exception('Failed to fetch organisations');
      }
    } catch (e) {
      throw Exception('Error fetching organisations: $e');
    }
  }

  //offline
  Future<List<dynamic>> fetchOrganisations() async {
    try {
      final organisations = await offlineStorage.getOrganisations();
      if (organisations != null) {
        return organisations;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchUserRegionAreasFromApi(
      String userId) async {
    try {
      final response = await _dio
          .get('/user-region-areas', queryParameters: {'user_id': userId});
      if (response.statusCode == 200) {
        final areas = response.data['data'];
        await offlineStorage.saveUserRegionAreas(userId, areas);
        return areas;
      } else {
        throw Exception('Failed to fetch user region areas');
      }
    } catch (e) {
      throw Exception('Error fetching user region areas: $e');
    }
  }

  //fetch offline user region areas
  Future<Map<String, dynamic>> fetchUserRegionAreas(String userId) async {
    try {
      final areas = await offlineStorage.getUserRegionAreas(userId);
      if (areas != null) {
        return areas;
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }
}
