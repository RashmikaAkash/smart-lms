import 'dart:convert';

String buildStudentClassId(String course) {
  final normalized = course
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return normalized.isEmpty ? 'general' : normalized;
}

String buildStudentQrPayload({
  required String studentId,
  required String name,
  required String email,
  required String grade,
  required String course,
  required String teacherUid,
}) {
  return jsonEncode({
    'type': 'smart_lms_student',
    'studentId': studentId,
    'name': name,
    'email': email,
    'grade': grade,
    'course': course,
    'classId': buildStudentClassId(course),
    'teacherUid': teacherUid,
  });
}
