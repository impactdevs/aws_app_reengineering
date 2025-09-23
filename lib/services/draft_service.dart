import 'package:hive_flutter/hive_flutter.dart';
import '../models/draft_model.dart';

class DraftService {
  static const String _boxName = 'drafts';
  late Box<DraftModel> _draftsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DraftModelAdapter());
    _draftsBox = await Hive.openBox<DraftModel>(_boxName);
  }

  String _createDraftKey(
      String formId, String activityType, DateTime timestamp) {
    return "$formId:$activityType:${timestamp.millisecondsSinceEpoch}";
  }

  Future<void> saveDraft(DraftModel draft, String activityType) async {
    final draftKey =
        _createDraftKey(draft.formId, activityType, draft.timestamp);
    await _draftsBox.put(draftKey, draft);
  }

  Future<void> updateDraft(DraftModel draft, String activityType) async {
    final draftKey =
        _createDraftKey(draft.formId, activityType, draft.timestamp);
    await _draftsBox.put(draftKey, draft);
  }

  Future<void> updateDraftStatus(
      String formId, String activityType, String status) async {
    final draftsToUpdate = _draftsBox.values
        .where((draft) => draft.formId == formId && draft.status != 'submitted')
        .toList();
    for (var draft in draftsToUpdate) {
      final draftKey =
          _createDraftKey(draft.formId, activityType, draft.timestamp);
      final updatedDraft = draft.copyWith(status: status);
      await _draftsBox.put(draftKey, updatedDraft);
    }
  }

  Future<void> updateSpecificDraftStatus(
      String formId, String activityType, DateTime timestamp, String status) async {
    final draftKey = _createDraftKey(formId, activityType, timestamp);
    final existingDraft = _draftsBox.get(draftKey);
    if (existingDraft != null) {
      final updatedDraft = existingDraft.copyWith(status: status);
      await _draftsBox.put(draftKey, updatedDraft);
    }
  }

  Future<void> deleteDraft(
      String formId, String activityType, DateTime timestamp) async {
    final draftKey = _createDraftKey(formId, activityType, timestamp);
    await _draftsBox.delete(draftKey);
  }

  DraftModel? getDraft(String formId, String activityType, DateTime timestamp) {
    final draftKey = _createDraftKey(formId, activityType, timestamp);
    return _draftsBox.get(draftKey);
  }

  List<DraftModel> getAllDrafts(String formId) {
    return _draftsBox.values.where((draft) => draft.formId == formId).toList();
  }

  List<DraftModel> getDraftsByStatus(
      String formId, String activityType, String status) {
    // Map activity type to entity type for proper filtering
    String expectedEntityType = activityType.toLowerCase() == 'follow-up' ? 'followup' : 'baseline';

    final drafts = _draftsBox.values.where((draft) {
      final entityType = draft.answers['entity_type'] as String?;
      return draft.formId == formId &&
          entityType == expectedEntityType &&
          draft.status == status;
    }).toList();
    return drafts;
  }

  Future<void> clearAllDrafts() async {
    await _draftsBox.clear();
  }

  bool isDraftExists(String formId, String activityType, DateTime timestamp) {
    final draftKey = _createDraftKey(formId, activityType, timestamp);
    return _draftsBox.containsKey(draftKey);
  }
}
