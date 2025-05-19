// models/form_model.dart
class FormModel {
  final String formId;
  final String title;
  final List<dynamic> questions;
  final Map<String, dynamic> titleFields;

  FormModel({
    required this.formId,
    required this.title,
    required this.questions,
    required this.titleFields,
  });

  factory FormModel.fromJson(Map<String, dynamic> json) {
    return FormModel(
      formId: json['form_id'].toString(),
      title: json['title'],
      questions: json['question_list'],
      titleFields: json['title_fields'],
    );
  }
}