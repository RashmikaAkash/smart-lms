import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'student_qr.dart';

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  bool _isExporting = false;
  bool _isRemoving = false;

  Future<void> _savePdf(_StudentDetailData student, String qrPayload) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final saved = await Printing.layoutPdf(
        name: '${_safeFileName(student.name)}_qr.pdf',
        onLayout: (_) => _buildPdf(student, qrPayload),
      );

      if (!mounted) {
        return;
      }

      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF save/print was cancelled.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open PDF saver. Use Share PDF instead.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _sharePdf(_StudentDetailData student, String qrPayload) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final bytes = await _buildPdf(student, qrPayload);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_safeFileName(student.name)}_qr.pdf',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create PDF. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<Uint8List> _buildPdf(
    _StudentDetailData student,
    String qrPayload,
  ) async {
    final regularFont = await PdfGoogleFonts.notoSerifSinhalaRegular();
    final boldFont = await PdfGoogleFonts.notoSerifSinhalaBold();
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(22),
              border: pw.Border.all(color: PdfColors.blueGrey200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Smart LMS Student QR',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Scan this QR code for attendance and student services.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.blueGrey600,
                  ),
                ),
                pw.SizedBox(height: 28),
                pw.Container(
                  width: 220,
                  height: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(18),
                    border: pw.Border.all(color: PdfColors.blueGrey100),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrPayload,
                  ),
                ),
                pw.SizedBox(height: 24),
                _pdfDetailRow('Name', student.name),
                _pdfDetailRow('Email', student.email),
                _pdfDetailRow('Student Mobile', student.studentMobile),
                _pdfDetailRow('Parent Mobile', student.parentMobile),
                _pdfDetailRow('Address', student.address),
                _pdfDetailRow('School', student.school),
                _pdfDetailRow('Grade', student.grade),
                _pdfDetailRow('Courses', student.courseSummary),
                _pdfDetailRow('Class Type', student.classTypeLabel),
                _pdfDetailRow('Class Fee', student.feeLabel),
                _pdfDetailRow('Location', student.location),
                _pdfDetailRow('Student ID', student.id),
                pw.Spacer(),
                pw.Text(
                  'Do not share the teacher password or account password with this QR.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.red600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 86,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '-' : value,
              style: const pw.TextStyle(color: PdfColors.blueGrey900),
            ),
          ),
        ],
      ),
    );
  }

  String _safeFileName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return normalized.isEmpty ? 'student' : normalized;
  }

  Future<void> _openAddCourseSheet(_StudentDetailData student) async {
    final teacherUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (teacherUid.isEmpty) {
      _showSnack('Teacher login needed.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddCourseSheet(
          teacherUid: teacherUid,
          student: student,
          onCourseSelected: (course) => _addCourseToStudent(student, course),
        );
      },
    );
  }

  Future<bool> _addCourseToStudent(
    _StudentDetailData student,
    _TeacherCourseOption course,
  ) async {
    try {
      final courseData = course.toStudentCourseMap();
      final updatedCourses = _dedupeStudentCourseMaps([
        for (final existingCourse in student.courses)
          existingCourse.toStudentCourseMap(),
        courseData,
      ]);

      await FirebaseFirestore.instance.collection('users').doc(student.id).set({
        'courseIds': _courseIdsFromStudentCourseMaps(updatedCourses),
        'courses': updatedCourses,
        'enrolledCourses': updatedCourses,
        'totalClassFee': _totalClassFeeFromStudentCourseMaps(updatedCourses),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return true;
      }

      _showSnack('${course.title} added to ${student.name}.');
      return true;
    } on FirebaseException catch (error) {
      if (!mounted) {
        return false;
      }

      _showSnack(
        error.code == 'permission-denied'
            ? 'Permission denied. Firestore users update rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}',
      );
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      _showSnack('Course add කරන්න බැරි වුණා.');
      return false;
    }
  }

  bool _canManageStudent(_StudentDetailData student) {
    final teacherUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return teacherUid.isNotEmpty &&
        (student.createdBy.isEmpty || student.createdBy == teacherUid);
  }

  Future<void> _openEditStudentSheet(_StudentDetailData student) async {
    if (!_canManageStudent(student)) {
      _showSnack('මේ student edit කරන්න permission නැහැ.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditStudentSheet(
          student: student,
          onSave: ({
            required String name,
            required String email,
            required String studentMobile,
            required String parentMobile,
            required String address,
            required String school,
            required _TeacherCourseOption course,
            required String status,
          }) =>
              _updateStudentProfile(
            student,
            name: name,
            email: email,
            studentMobile: studentMobile,
            parentMobile: parentMobile,
            address: address,
            school: school,
            course: course,
            status: status,
          ),
        );
      },
    );
  }

  Future<bool> _updateStudentProfile(
    _StudentDetailData student, {
    required String name,
    required String email,
    required String studentMobile,
    required String parentMobile,
    required String address,
    required String school,
    required _TeacherCourseOption course,
    required String status,
  }) async {
    if (!_canManageStudent(student)) {
      _showSnack('මේ student update කරන්න permission නැහැ.');
      return false;
    }

    try {
      final teacherUid = student.createdBy.isNotEmpty
          ? student.createdBy
          : FirebaseAuth.instance.currentUser?.uid ?? '';
      final updatedCourses = _dedupeStudentCourseMaps(
        _replacePrimaryCourse(student, course),
      );
      final updatedCourseIds = updatedCourses
          .map((courseData) => courseData['courseId']?.toString() ?? '')
          .where((courseId) => courseId.isNotEmpty)
          .toSet()
          .toList();
      final qrPayload = buildStudentQrPayload(
        studentId: student.id,
        name: name,
        email: email,
        grade: course.grade,
        course: course.name,
        teacherUid: teacherUid,
        courseId: course.id,
        classFee: course.classFee,
        classType: course.type,
        location: course.location,
        studentMobile: studentMobile,
        parentMobile: parentMobile,
        address: address,
        school: school,
      );

      await FirebaseFirestore.instance.collection('users').doc(student.id).set({
        'name': name,
        'email': email,
        'studentMobile': studentMobile,
        'studentPhone': studentMobile,
        'parentMobile': parentMobile,
        'parentPhone': parentMobile,
        'address': address,
        'school': school,
        'grade': course.grade,
        'courseId': course.id,
        'course': course.name,
        'subject': course.name,
        'classId': buildStudentClassId(course.name),
        'classFee': course.classFee,
        'totalClassFee': _totalClassFeeFromStudentCourseMaps(updatedCourses),
        'classType': course.type,
        'location': course.location,
        'courseIds': updatedCourseIds,
        'courses': updatedCourses,
        'enrolledCourses': updatedCourses,
        'status': status,
        'qrPayload': qrPayload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return true;
      }

      _showSnack('Student details updated.');
      return true;
    } on FirebaseException catch (error) {
      if (!mounted) {
        return false;
      }

      _showSnack(
        error.code == 'permission-denied'
            ? 'Permission denied. Firestore users update rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}',
      );
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      _showSnack('Student update කරන්න බැරි වුණා.');
      return false;
    }
  }

  List<Map<String, dynamic>> _replacePrimaryCourse(
    _StudentDetailData student,
    _TeacherCourseOption replacementCourse,
  ) {
    final replacement = replacementCourse.toStudentCourseMap();
    final replacementKeys = replacementCourse.matchKeys;
    final primaryKeys = _StudentCourseData.buildMatchKeys(
      id: student.courseId,
      name: student.course,
      grade: student.grade,
    );
    final courses = <Map<String, dynamic>>[];
    var insertedReplacement = false;

    for (final existingCourse in student.courses) {
      final existingKeys = existingCourse.matchKeys;
      final isPrimaryCourse =
          primaryKeys.isNotEmpty && existingKeys.any(primaryKeys.contains);
      final isReplacementCourse = replacementKeys.isNotEmpty &&
          existingKeys.any(replacementKeys.contains);

      if (isPrimaryCourse || isReplacementCourse) {
        if (!insertedReplacement) {
          courses.add(replacement);
          insertedReplacement = true;
        }
        continue;
      }

      courses.add(existingCourse.toStudentCourseMap());
    }

    if (!insertedReplacement) {
      courses.insert(0, replacement);
    }

    return courses;
  }

  List<Map<String, dynamic>> _dedupeStudentCourseMaps(
    List<Map<String, dynamic>> courses,
  ) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final courseMap in courses) {
      final id = _readCourseString(
        courseMap,
        'courseId',
        _readCourseString(courseMap, 'id', ''),
      );
      final name = _readCourseString(
        courseMap,
        'name',
        _readCourseString(courseMap, 'course', ''),
      );
      final grade = _readCourseString(courseMap, 'grade', '');
      final key = id.isNotEmpty
          ? 'id:${id.toLowerCase()}'
          : 'name:${name.toLowerCase()}|${grade.toLowerCase()}';

      if (key == 'name:|' || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      deduped.add(courseMap);
    }

    return deduped;
  }

  List<String> _courseIdsFromStudentCourseMaps(
    List<Map<String, dynamic>> courses,
  ) {
    return courses
        .map(
          (courseMap) => _readCourseString(
            courseMap,
            'courseId',
            _readCourseString(courseMap, 'id', ''),
          ),
        )
        .where((courseId) => courseId.isNotEmpty)
        .toSet()
        .toList();
  }

  double _totalClassFeeFromStudentCourseMaps(
    List<Map<String, dynamic>> courses,
  ) {
    return courses.fold<double>(0, (total, courseMap) {
      return total +
          _readCourseDouble(
            courseMap,
            'classFee',
            _readCourseDouble(courseMap, 'fee'),
          );
    });
  }

  String _readCourseString(
    Map<String, dynamic> data,
    String key, [
    String fallback = '',
  ]) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  double _readCourseDouble(
    Map<String, dynamic> data,
    String key, [
    double fallback = 0,
  ]) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _confirmRemoveStudent(_StudentDetailData student) async {
    if (!_canManageStudent(student)) {
      _showSnack('මේ student remove කරන්න permission නැහැ.');
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove student?'),
          content: Text(
            '${student.name} students list එකෙන් remove වෙනවා. මේක Firebase Auth account එක delete කරන්නේ නැහැ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF526B),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      await _removeStudent(student);
    }
  }

  Future<void> _removeStudent(_StudentDetailData student) async {
    setState(() {
      _isRemoving = true;
    });

    try {
      final teacher = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(student.id).set({
        'status': 'archived',
        'removedAt': FieldValue.serverTimestamp(),
        'removedBy': teacher?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      _showSnack('${student.name} removed.');
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnack(
        error.code == 'permission-denied'
            ? 'Permission denied. Firestore users update rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnack('Student remove කරන්න බැරි වුණා.');
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Student Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _DetailMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Could not load student',
              message: 'Firestore rules read permission check කරන්න.',
            );
          }

          final document = snapshot.data;
          final data = document?.data();
          if (document == null || !document.exists || data == null) {
            return const _DetailMessage(
              icon: Icons.person_off_outlined,
              title: 'Student not found',
              message: 'මේ student record එක Firestore එකේ නැහැ.',
            );
          }

          final student = _StudentDetailData.fromMap(document.id, data);
          final teacherUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final isTeacherOwner = student.createdBy.isEmpty ||
              (teacherUid.isNotEmpty && student.createdBy == teacherUid);

          if (!isTeacherOwner) {
            return const _DetailMessage(
              icon: Icons.lock_person_outlined,
              title: 'Access denied',
              message: 'මේ student වෙන teacher කෙනෙක් register කරලා තියෙන්නේ.',
            );
          }

          final qrPayload = student.qrPayload.isNotEmpty
              ? student.qrPayload
              : buildStudentQrPayload(
                  studentId: student.id,
                  name: student.name,
                  email: student.email,
                  grade: student.grade,
                  course: student.course,
                  teacherUid: student.createdBy.isNotEmpty
                      ? student.createdBy
                      : teacherUid,
                  courseId: student.courseId,
                  classFee: student.classFee,
                  classType: student.classType,
                  location: student.location,
                  studentMobile: student.studentMobile,
                  parentMobile: student.parentMobile,
                  address: student.address,
                  school: student.school,
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudentHeader(student: student),
                const SizedBox(height: 16),
                _StudentActionButtons(
                  isRemoving: _isRemoving,
                  onEditPressed: () => _openEditStudentSheet(student),
                  onRemovePressed: () => _confirmRemoveStudent(student),
                ),
                const SizedBox(height: 16),
                _QrCard(qrPayload: qrPayload),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _isExporting ? null : () => _savePdf(student, qrPayload),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    _isExporting ? 'Opening PDF...' : 'Save / Print PDF',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      _isExporting ? null : () => _sharePdf(student, qrPayload),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF316DFF),
                    side: const BorderSide(color: Color(0xFFB7C9FF)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DetailsCard(student: student),
                const SizedBox(height: 16),
                _StudentCoursesWithPayments(
                  student: student,
                  teacherUid: teacherUid,
                  onAddPressed: () => _openAddCourseSheet(student),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.student});

  final _StudentDetailData student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D5BEA),
            Color(0xFF6843EA),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
            child: Text(
              student.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  student.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderBadge(label: student.grade),
                    _HeaderBadge(label: student.courseBadgeLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? '-' : label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StudentActionButtons extends StatelessWidget {
  const _StudentActionButtons({
    required this.isRemoving,
    required this.onEditPressed,
    required this.onRemovePressed,
  });

  final bool isRemoving;
  final VoidCallback onEditPressed;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isRemoving ? null : onEditPressed,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit Student'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF316DFF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isRemoving ? null : onRemovePressed,
            icon: isRemoving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(isRemoving ? 'Removing...' : 'Remove'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF526B),
              side: const BorderSide(color: Color(0xFFFFB8C3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditStudentSheet extends StatefulWidget {
  const _EditStudentSheet({
    required this.student,
    required this.onSave,
  });

  final _StudentDetailData student;
  final Future<bool> Function({
    required String name,
    required String email,
    required String studentMobile,
    required String parentMobile,
    required String address,
    required String school,
    required _TeacherCourseOption course,
    required String status,
  }) onSave;

  @override
  State<_EditStudentSheet> createState() => _EditStudentSheetState();
}

class _EditStudentSheetState extends State<_EditStudentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _studentMobileController;
  late final TextEditingController _parentMobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _schoolController;
  _TeacherCourseOption? _selectedCourse;
  late String? _selectedCourseId;
  late String _selectedStatus;
  List<_TeacherCourseOption> _availableCourses = const [];
  bool _isSaving = false;

  static const _statusOptions = <String, String>{
    'active': 'Active',
    'registered': 'Registered',
    'paid': 'Paid',
    'due': 'Due',
    'overdue': 'Overdue',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _emailController = TextEditingController(text: widget.student.email);
    _studentMobileController =
        TextEditingController(text: widget.student.studentMobile);
    _parentMobileController =
        TextEditingController(text: widget.student.parentMobile);
    _addressController = TextEditingController(text: widget.student.address);
    _schoolController = TextEditingController(text: widget.student.school);
    _selectedCourseId = widget.student.courseId.isNotEmpty
        ? widget.student.courseId
        : widget.student.course;
    final currentStatus = widget.student.status.trim().toLowerCase();
    _selectedStatus =
        _statusOptions.containsKey(currentStatus) ? currentStatus : 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentMobileController.dispose();
    _parentMobileController.dispose();
    _addressController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final course = _selectedCourse ??
        _courseFromAvailableOptions() ??
        _TeacherCourseOption.fromStudent(widget.student);

    final saved = await widget.onSave(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      studentMobile: _studentMobileController.text.trim(),
      parentMobile: _parentMobileController.text.trim(),
      address: _addressController.text.trim(),
      school: _schoolController.text.trim(),
      course: course,
      status: _selectedStatus,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (saved) {
      Navigator.of(context).pop();
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) {
      return 'Student name එක දාන්න.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Valid email එකක් දාන්න.';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final mobile = value?.trim() ?? '';
    final digits = mobile.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 9) {
      return 'Valid mobile number එකක් දාන්න.';
    }
    return null;
  }

  String? _validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label එක දාන්න.';
    }
    return null;
  }

  _TeacherCourseOption? _courseFromAvailableOptions() {
    final selectedCourseId = _selectedCourseId?.trim().toLowerCase() ?? '';
    if (selectedCourseId.isEmpty) {
      return null;
    }

    for (final course in _availableCourses) {
      if (course.id.toLowerCase() == selectedCourseId ||
          course.name.toLowerCase() == selectedCourseId) {
        return course;
      }
    }

    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _teacherCoursesStream {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_courses')
        .doc(teacher.uid)
        .collection('courses')
        .snapshots();
  }

  Widget _buildCourseDropdown() {
    final stream = _teacherCoursesStream;
    if (stream == null) {
      return DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        decoration: _inputDecoration(
          label: 'Course',
          icon: Icons.menu_book_outlined,
        ),
        hint: const Text('Teacher login needed'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return TextFormField(
            enabled: false,
            decoration: _inputDecoration(
              label: 'Loading courses...',
              icon: Icons.menu_book_outlined,
            ),
          );
        }

        final courses = (snapshot.data?.docs ?? [])
            .map(_TeacherCourseOption.fromSnapshot)
            .where((course) => course.status != 'archived')
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name));
        _availableCourses = courses;
        final selectedValue = courses.any(
          (course) =>
              course.id == _selectedCourseId ||
              course.name.toLowerCase() == _selectedCourseId?.toLowerCase(),
        )
            ? courses
                .firstWhere(
                  (course) =>
                      course.id == _selectedCourseId ||
                      course.name.toLowerCase() ==
                          _selectedCourseId?.toLowerCase(),
                )
                .id
            : null;

        if (courses.isEmpty) {
          return DropdownButtonFormField<String>(
            items: const [],
            onChanged: null,
            decoration: _inputDecoration(
              label: 'Course',
              icon: Icons.menu_book_outlined,
            ),
            hint: const Text('Create a course first'),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          decoration: _inputDecoration(
            label: 'Course',
            icon: Icons.menu_book_outlined,
          ),
          hint: const Text('Select course'),
          items: courses.map((course) {
            return DropdownMenuItem<String>(
              value: course.id,
              child: Text(
                course.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (courseId) {
            if (courseId == null) {
              return;
            }

            final selectedCourse = courses.firstWhere(
              (course) => course.id == courseId,
            );

            setState(() {
              _selectedCourse = selectedCourse;
              _selectedCourseId = selectedCourse.id;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DFEC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Edit Student',
                  style: TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Name, contact email, mobile numbers, address, school and status update කරන්න. Login email වෙනස් කරන්න Firebase Auth admin access ඕන.',
                  style: TextStyle(
                    color: Color(0xFF6C7892),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: _inputDecoration(
                    label: 'Student name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: _inputDecoration(
                    label: 'Contact email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentMobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _validateMobile,
                  decoration: _inputDecoration(
                    label: 'Student mobile number',
                    icon: Icons.phone_android_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _parentMobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _validateMobile,
                  decoration: _inputDecoration(
                    label: 'Parent mobile number',
                    icon: Icons.phone_in_talk_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _validateRequired(value, 'Address'),
                  decoration: _inputDecoration(
                    label: 'Student address',
                    icon: Icons.home_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _schoolController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _validateRequired(value, 'School'),
                  decoration: _inputDecoration(
                    label: 'School',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCourseDropdown(),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Status',
                    icon: Icons.verified_user_outlined,
                  ),
                  items: _statusOptions.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    disabledBackgroundColor: const Color(0xFF9BB6FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6F7E9A)),
      filled: true,
      fillColor: const Color(0xFFF6F8FC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF316DFF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF526B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF526B), width: 1.4),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.qrPayload});

  final String qrPayload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        children: [
          const Text(
            'Student QR Code',
            style: TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Attendance scanner එකෙන් මේ QR එක scan කරන්න පුළුවන්.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF66748F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EAF4)),
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 230,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.student});

  final _StudentDetailData student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Student ID', value: student.id),
          _DetailRow(label: 'Name', value: student.name),
          _DetailRow(label: 'Email', value: student.email),
          _DetailRow(label: 'Student Mobile', value: student.studentMobile),
          _DetailRow(label: 'Parent Mobile', value: student.parentMobile),
          _DetailRow(label: 'Address', value: student.address),
          _DetailRow(label: 'School', value: student.school),
          _DetailRow(label: 'Grade', value: student.grade),
          _DetailRow(label: 'Courses', value: student.courseSummary),
          _DetailRow(label: 'Class Type', value: student.classTypeLabel),
          _DetailRow(label: 'Class Fee', value: student.feeLabel),
          _DetailRow(label: 'Location', value: student.location),
          _DetailRow(label: 'Status', value: student.status),
        ],
      ),
    );
  }
}

class _StudentCoursesWithPayments extends StatelessWidget {
  const _StudentCoursesWithPayments({
    required this.student,
    required this.teacherUid,
    required this.onAddPressed,
  });

  final _StudentDetailData student;
  final String teacherUid;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty) {
      return _StudentCoursesCard(
        student: student,
        payments: const [],
        paymentsLoading: false,
        onAddPressed: onAddPressed,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_payments')
          .doc(teacherUid)
          .collection('payments')
          .where('monthKey', isEqualTo: _monthKey(DateTime.now()))
          .snapshots(),
      builder: (context, snapshot) {
        final payments = (snapshot.data?.docs ?? [])
            .map(_StudentCoursePayment.fromSnapshot)
            .where(
              (payment) => payment.isActive && payment.studentId == student.id,
            )
            .toList();

        return _StudentCoursesCard(
          student: student,
          payments: payments,
          paymentsLoading: snapshot.connectionState == ConnectionState.waiting,
          onAddPressed: onAddPressed,
        );
      },
    );
  }
}

String _monthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

class _StudentCoursesCard extends StatelessWidget {
  const _StudentCoursesCard({
    required this.student,
    required this.payments,
    required this.paymentsLoading,
    required this.onAddPressed,
  });

  final _StudentDetailData student;
  final List<_StudentCoursePayment> payments;
  final bool paymentsLoading;
  final VoidCallback onAddPressed;

  _StudentCoursePayment? _paymentFor(_StudentCourseData course) {
    for (final payment in payments) {
      if (payment.matchesCourse(course)) {
        return payment;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Courses',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'මෙම student register වෙලා තියෙන courses.',
                      style: TextStyle(
                        color: Color(0xFF66748F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF316DFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < student.courses.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _StudentCourseTile(
              course: student.courses[index],
              payment: _paymentFor(student.courses[index]),
              paymentsLoading: paymentsLoading,
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentCourseTile extends StatelessWidget {
  const _StudentCourseTile({
    required this.course,
    required this.payment,
    required this.paymentsLoading,
  });

  final _StudentCourseData course;
  final _StudentCoursePayment? payment;
  final bool paymentsLoading;

  @override
  Widget build(BuildContext context) {
    final isPaid = payment != null;
    final chipColor = paymentsLoading
        ? const Color(0xFF64748B)
        : isPaid
            ? const Color(0xFF00A86B)
            : const Color(0xFFE08A00);
    final chipBackground = paymentsLoading
        ? const Color(0xFFEFF4FA)
        : isPaid
            ? const Color(0xFFE8FFF5)
            : const Color(0xFFFFF5DE);
    final chipText = paymentsLoading
        ? 'Checking'
        : isPaid
            ? 'Paid this month'
            : 'Pending';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF316DFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  course.metaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF66748F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment?.amountLabel ?? course.feeLabel,
                style: TextStyle(
                  color: isPaid
                      ? const Color(0xFF00A86B)
                      : const Color(0xFF071B3C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentCoursePayment {
  const _StudentCoursePayment({
    required this.studentId,
    required this.courseId,
    required this.courseName,
    required this.amount,
    required this.status,
  });

  final String studentId;
  final String courseId;
  final String courseName;
  final double amount;
  final String status;

  factory _StudentCoursePayment.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _StudentCoursePayment(
      studentId: _readString(data, 'studentId'),
      courseId: _readString(data, 'courseId'),
      courseName: _readString(
        data,
        'courseName',
        _readString(data, 'course'),
      ),
      amount: _readDouble(data, 'amount'),
      status: _readString(data, 'status', 'paid').toLowerCase(),
    );
  }

  bool get isActive => status == 'paid';

  String get amountLabel {
    if (amount <= 0) {
      return 'Paid';
    }

    final hasCents = amount.truncateToDouble() != amount;
    return 'Rs ${amount.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  bool matchesCourse(_StudentCourseData course) {
    final keys = _StudentCourseData.buildMatchKeys(
      id: courseId,
      name: courseName,
      grade: '',
    );

    return course.matchKeys.any(keys.contains);
  }

  static String _readString(
    Map<String, dynamic> data,
    String key, [
    String fallback = '',
  ]) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  static double _readDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet({
    required this.teacherUid,
    required this.student,
    required this.onCourseSelected,
  });

  final String teacherUid;
  final _StudentDetailData student;
  final Future<bool> Function(_TeacherCourseOption course) onCourseSelected;

  @override
  State<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<_AddCourseSheet> {
  String? _savingCourseId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD8DFEC),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Add Course to ${widget.student.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Already registered courses hide කරලා ඉතුරු courses පෙන්වනවා.',
            style: TextStyle(
              color: Color(0xFF60708F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_courses')
                  .doc(widget.teacherUid)
                  .collection('courses')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _AddCourseMessage(
                    icon: Icons.lock_outline_rounded,
                    message: 'Courses load කරන්න බැහැ. Rules check කරන්න.',
                  );
                }

                final existingKeys = widget.student.courses
                    .expand((course) => course.matchKeys)
                    .where((key) => key.isNotEmpty)
                    .toSet();
                final courses = (snapshot.data?.docs ?? [])
                    .map(_TeacherCourseOption.fromSnapshot)
                    .where((course) => course.status != 'archived')
                    .where(
                      (course) => !course.matchKeys.any(existingKeys.contains),
                    )
                    .toList()
                  ..sort((first, second) => first.name.compareTo(second.name));

                if (courses.isEmpty) {
                  return const _AddCourseMessage(
                    icon: Icons.done_all_rounded,
                    message:
                        'මේ student available courses සියල්ලටම register වෙලා.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    final isSaving = _savingCourseId == course.id;
                    return _TeacherCourseTile(
                      course: course,
                      isSaving: isSaving,
                      onTap: _savingCourseId == null
                          ? () => _selectCourse(course)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCourse(_TeacherCourseOption course) async {
    setState(() {
      _savingCourseId = course.id;
    });

    final saved = await widget.onCourseSelected(course);

    if (mounted) {
      setState(() {
        _savingCourseId = null;
      });

      if (saved) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _TeacherCourseTile extends StatelessWidget {
  const _TeacherCourseTile({
    required this.course,
    required this.isSaving,
    required this.onTap,
  });

  final _TeacherCourseOption course;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF316DFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60708F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Text(
                  course.feeLabel,
                  style: const TextStyle(
                    color: Color(0xFF00A86B),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCourseMessage extends StatelessWidget {
  const _AddCourseMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8C98AF), size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF60708F),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF66748F),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF8C98AF), size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6C7892),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDetailData {
  const _StudentDetailData({
    required this.id,
    required this.name,
    required this.email,
    required this.studentMobile,
    required this.parentMobile,
    required this.address,
    required this.school,
    required this.grade,
    required this.course,
    required this.courseId,
    required this.classFee,
    required this.totalClassFee,
    required this.classType,
    required this.location,
    required this.status,
    required this.createdBy,
    required this.qrPayload,
    required this.courses,
  });

  final String id;
  final String name;
  final String email;
  final String studentMobile;
  final String parentMobile;
  final String address;
  final String school;
  final String grade;
  final String course;
  final String courseId;
  final double classFee;
  final double totalClassFee;
  final String classType;
  final String location;
  final String status;
  final String createdBy;
  final String qrPayload;
  final List<_StudentCourseData> courses;

  factory _StudentDetailData.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final fallbackCourse = _readString(data, 'subject', 'General');
    final primaryCourse = _readString(data, 'course', fallbackCourse);
    final primaryCourseId = _readString(data, 'courseId', '');
    final primaryGrade = _readString(data, 'grade', '');
    final primaryClassFee = _readDouble(data, 'classFee');
    final primaryClassType = _readString(data, 'classType', 'group');
    final primaryLocation = _readString(data, 'location', '');
    final primaryStatus = _readString(data, 'status', 'active');
    final courses = <_StudentCourseData>[];

    void addCourse(_StudentCourseData? course) {
      if (course == null) {
        return;
      }

      final keys = course.matchKeys;
      final alreadyAdded = courses.any(
        (existing) => existing.matchKeys.any(keys.contains),
      );

      if (!alreadyAdded) {
        courses.add(course);
      }
    }

    void addCoursesFromField(String field) {
      final value = data[field];
      if (value is Iterable) {
        for (final item in value) {
          addCourse(_StudentCourseData.tryParse(item));
        }
      }
    }

    addCoursesFromField('courses');
    addCoursesFromField('enrolledCourses');
    addCoursesFromField('studentCourses');
    addCourse(
      _StudentCourseData(
        id: primaryCourseId,
        name: primaryCourse,
        grade: primaryGrade,
        classFee: primaryClassFee,
        type: primaryClassType,
        location: primaryLocation,
        status: primaryStatus,
      ),
    );

    final firstCourse = courses.isNotEmpty ? courses.first : null;
    final calculatedTotalClassFee = courses.fold<double>(
      0,
      (total, course) => total + course.classFee,
    );
    final savedTotalClassFee = _readDouble(data, 'totalClassFee');
    final displayTotalClassFee = savedTotalClassFee > 0
        ? savedTotalClassFee
        : calculatedTotalClassFee > 0
            ? calculatedTotalClassFee
            : primaryClassFee;

    return _StudentDetailData(
      id: id,
      name: _readString(data, 'name', 'Unnamed Student'),
      email: _readString(data, 'email', ''),
      studentMobile: _readString(
        data,
        'studentMobile',
        _readString(data, 'studentPhone', ''),
      ),
      parentMobile: _readString(
        data,
        'parentMobile',
        _readString(data, 'parentPhone', ''),
      ),
      address: _readString(data, 'address', ''),
      school: _readString(data, 'school', ''),
      grade: primaryGrade.isNotEmpty ? primaryGrade : firstCourse?.grade ?? '',
      course:
          primaryCourse.isNotEmpty ? primaryCourse : firstCourse?.name ?? '',
      courseId:
          primaryCourseId.isNotEmpty ? primaryCourseId : firstCourse?.id ?? '',
      classFee:
          primaryClassFee > 0 ? primaryClassFee : firstCourse?.classFee ?? 0,
      totalClassFee: displayTotalClassFee,
      classType: primaryClassType.isNotEmpty
          ? primaryClassType
          : firstCourse?.type ?? 'group',
      location: primaryLocation.isNotEmpty
          ? primaryLocation
          : firstCourse?.location ?? '',
      status: primaryStatus,
      createdBy: _readString(data, 'createdBy', ''),
      qrPayload: _readString(data, 'qrPayload', ''),
      courses: List.unmodifiable(courses),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  static double _readDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  String get classTypeLabel =>
      classType == 'individual' ? 'Individual' : 'Group';

  String get feeLabel {
    final fee = totalClassFee > 0 ? totalClassFee : classFee;
    final hasCents = fee.truncateToDouble() != fee;
    return 'Rs ${fee.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  int get courseCount => courses.length;

  String get courseBadgeLabel =>
      courseCount > 1 ? '$courseCount Courses' : course;

  String get courseSummary {
    if (courses.isEmpty) {
      return course;
    }

    return courses.map((course) => course.title).join(', ');
  }
}

class _TeacherCourseOption {
  const _TeacherCourseOption({
    required this.id,
    required this.name,
    required this.grade,
    required this.classFee,
    required this.type,
    required this.location,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final double classFee;
  final String type;
  final String location;
  final String status;

  factory _TeacherCourseOption.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _TeacherCourseOption(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      classFee: _readDouble(data, 'classFee'),
      type: _readString(data, 'type', 'group'),
      location: _readString(data, 'location', ''),
      status: _readString(data, 'status', 'active'),
    );
  }

  factory _TeacherCourseOption.fromStudent(_StudentDetailData student) {
    return _TeacherCourseOption(
      id: student.courseId,
      name: student.course,
      grade: student.grade,
      classFee: student.classFee,
      type: student.classType,
      location: student.location,
      status: student.status,
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  static double _readDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get title {
    if (grade.isEmpty) {
      return name;
    }

    return '$name - $grade';
  }

  String get typeLabel => type == 'individual' ? 'Individual' : 'Group';

  String get feeLabel {
    if (classFee <= 0) {
      return 'No fee';
    }

    final hasCents = classFee.truncateToDouble() != classFee;
    return 'Rs ${classFee.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  String get metaLabel {
    final parts = <String>[
      typeLabel,
      feeLabel,
      if (location.isNotEmpty) location,
    ];

    return parts.join(' • ');
  }

  Set<String> get matchKeys => _StudentCourseData.buildMatchKeys(
        id: id,
        name: name,
        grade: grade,
      );

  String get key => matchKeys.isEmpty ? '' : matchKeys.first;

  Map<String, dynamic> toStudentCourseMap() {
    return {
      'id': id,
      'courseId': id,
      'name': name,
      'course': name,
      'grade': grade,
      'classId': buildStudentClassId(name),
      'classFee': classFee,
      'type': type,
      'classType': type,
      'location': location,
      'status': 'active',
    };
  }
}

class _StudentCourseData {
  const _StudentCourseData({
    required this.id,
    required this.name,
    required this.grade,
    required this.classFee,
    required this.type,
    required this.location,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final double classFee;
  final String type;
  final String location;
  final String status;

  static _StudentCourseData? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final data = <String, dynamic>{};
    value.forEach((key, value) {
      data[key.toString()] = value;
    });

    final id = _readString(
      data,
      'id',
      _readString(data, 'courseId', ''),
    );
    final name = _readString(
      data,
      'name',
      _readString(data, 'course', ''),
    );

    if (id.isEmpty && name.isEmpty) {
      return null;
    }

    return _StudentCourseData(
      id: id,
      name: name,
      grade: _readString(data, 'grade', ''),
      classFee: _readDouble(
        data,
        'classFee',
        _readDouble(data, 'fee'),
      ),
      type: _readString(
        data,
        'type',
        _readString(data, 'classType', 'group'),
      ),
      location: _readString(data, 'location', ''),
      status: _readString(data, 'status', 'active'),
    );
  }

  static String _readString(
    Map<String, dynamic> data,
    String key, [
    String fallback = '',
  ]) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  static double _readDouble(
    Map<String, dynamic> data,
    String key, [
    double fallback = 0,
  ]) {
    final value = data[key];
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Set<String> buildMatchKeys({
    required String id,
    required String name,
    required String grade,
  }) {
    final keys = <String>{};
    final idKey = id.trim().toLowerCase();
    final nameKey = name.trim().toLowerCase();
    final gradeKey = grade.trim().toLowerCase();

    if (idKey.isNotEmpty) {
      keys.add('id:$idKey');
    }

    if (nameKey.isNotEmpty) {
      keys.add('name:$nameKey|$gradeKey');
      keys.add('name:$nameKey');
    }

    return keys;
  }

  String get title {
    if (grade.isEmpty) {
      return name.isEmpty ? 'Unnamed Course' : name;
    }

    return '${name.isEmpty ? 'Unnamed Course' : name} - $grade';
  }

  String get typeLabel => type == 'individual' ? 'Individual' : 'Group';

  String get feeLabel {
    if (classFee <= 0) {
      return 'No fee';
    }

    final hasCents = classFee.truncateToDouble() != classFee;
    return 'Rs ${classFee.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  String get metaLabel {
    final parts = <String>[
      typeLabel,
      if (location.isNotEmpty) location,
    ];

    return parts.join(' • ');
  }

  Set<String> get matchKeys => buildMatchKeys(
        id: id,
        name: name,
        grade: grade,
      );

  String get key => matchKeys.isEmpty ? '' : matchKeys.first;

  Map<String, dynamic> toStudentCourseMap() {
    return {
      'id': id,
      'courseId': id,
      'name': name,
      'course': name,
      'grade': grade,
      'classId': buildStudentClassId(name),
      'classFee': classFee,
      'type': type,
      'classType': type,
      'location': location,
      'status': status,
    };
  }
}
