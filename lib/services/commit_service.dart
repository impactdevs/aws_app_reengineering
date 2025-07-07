import 'dart:developer';

import 'package:hive_flutter/hive_flutter.dart';
import '../models/commit_model.dart';

class CommitService {
  static const String _boxName = 'commits';
  late Box<CommitModel> _commitsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CommitModelAdapter());
    _commitsBox = await Hive.openBox<CommitModel>(_boxName);
  }

  String _createCommitKey(
      String formId, String activityType, DateTime timestamp) {
    return "$formId:$activityType:${timestamp.millisecondsSinceEpoch}";
  }

  Future<void> saveCommit(CommitModel commit, String activityType) async {
    final commitKey =
        _createCommitKey(commit.formId, activityType, commit.timestamp);
    await _commitsBox.put(commitKey, commit);
  }

  Future<void> updateCommit(CommitModel commit, String activityType) async {
    final commitKey =
        _createCommitKey(commit.formId, activityType, commit.timestamp);
    await _commitsBox.put(commitKey, commit);
  }

  Future<void> updateCommitStatus(
      String formId, String activityType, String status) async {
    final commitsToUpdate = _commitsBox.values
        .where(
            (commit) => commit.formId == formId && commit.status != 'submitted')
        .toList();
    for (var commit in commitsToUpdate) {
      final commitKey =
          _createCommitKey(commit.formId, activityType, commit.timestamp);
      final updatedCommit = commit.copyWith(status: status);
      await _commitsBox.put(commitKey, updatedCommit);
    }
  }

  Future<void> deleteCommit(
      String formId, String activityType, DateTime timestamp) async {
    final commitKey = _createCommitKey(formId, activityType, timestamp);
    await _commitsBox.delete(commitKey);
  }

  CommitModel? getcommit(
      String formId, String activityType, DateTime timestamp) {
    final commitKey = _createCommitKey(formId, activityType, timestamp);
    return _commitsBox.get(commitKey);
  }

  Future<List<dynamic>?> getAllCommits(String formId) async {
    return _commitsBox.values
        .where((commit) => commit.formId == formId)
        .toList();
  }

  List<CommitModel> getCommitsByStatus(
      String formId, String activityType, String status) {
    return _commitsBox.values.where((commit) {
      final entityType = commit.answers['entity_type'] as String?;

      if (activityType == 'Baseline' && entityType == 'baseline') {
        log("Checking Baseline Commits: ${commit.formId}, Status: $status, Entity Type: $entityType");

        return commit.formId == formId && commit.status == status;
      } else if (activityType == 'Follow-up' && entityType == 'followup') {
        log("Checking Follow-up commits: ${commit.formId}, Status: $status, Entity Type: $entityType");
        return commit.formId == formId && commit.status == status;
      }

      return false;
    }).toList();
  }

  Future<void> clearAllCommits() async {
    await _commitsBox.clear();
  }

  bool isCommitExists(String formId, String activityType, DateTime timestamp) {
    final commitKey = _createCommitKey(formId, activityType, timestamp);
    return _commitsBox.containsKey(commitKey);
  }
}
