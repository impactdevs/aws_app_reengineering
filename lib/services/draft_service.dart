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
    final drafts = _draftsBox.values.where((draft) {
      return draft.formId == formId &&
          draft.answers['entity_type'] == activityType &&
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
