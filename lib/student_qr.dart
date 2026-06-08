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
  String? courseId,
  double? classFee,
  String? classType,
  String? location,
  String? studentMobile,
  String? parentMobile,
  String? address,
  String? school,
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
    if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
    if (classFee != null) 'classFee': classFee,
    if (classType != null && classType.isNotEmpty) 'classType': classType,
    if (location != null && location.isNotEmpty) 'location': location,
    if (studentMobile != null && studentMobile.isNotEmpty)
      'studentMobile': studentMobile,
    if (parentMobile != null && parentMobile.isNotEmpty)
      'parentMobile': parentMobile,
    if (address != null && address.isNotEmpty) 'address': address,
    if (school != null && school.isNotEmpty) 'school': school,
  });
}
