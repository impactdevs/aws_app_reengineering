import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'commit_model.g.dart';

@HiveType(typeId: 1)
class CommitModel extends HiveObject {
  @HiveField(0)
  final String formId;

  @HiveField(1)
  final Map<String, dynamic> answers;

  @HiveField(2)
  final Map<String, String> images;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String status; // 'draft', 'pending', 'submitted'

  @HiveField(5)
  final String title;

  CommitModel({
    required this.formId,
    required this.answers,
    required this.images,
    required this.timestamp,
    required this.title,
    this.status = 'draft',
  });

  factory CommitModel.fromJson(Map<String, dynamic> json) {
    return CommitModel(
      formId: json['form_id'],
      answers: Map<String, dynamic>.from(json['answers']),
      images: Map<String, String>.from(json['images'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      title: json['title'],
      status: json['status'] ?? 'draft',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'form_id': formId,
      'answers': answers,
      'images': images,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'status': status,
    };
  }

  CommitModel copyWith({
    String? formId,
    Map<String, dynamic>? answers,
    Map<String, String>? images,
    DateTime? timestamp,
    String? title,
    String? status,
  }) {
    return CommitModel(
      formId: formId ?? this.formId,
      answers: answers ?? this.answers,
      images: images ?? this.images,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}
