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
                _pdfDetailRow('Grade', student.grade),
                _pdfDetailRow('Course', student.course),
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
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudentHeader(student: student),
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
                    _HeaderBadge(label: student.course),
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
          _DetailRow(label: 'Grade', value: student.grade),
          _DetailRow(label: 'Course', value: student.course),
          _DetailRow(label: 'Class Type', value: student.classTypeLabel),
          _DetailRow(label: 'Class Fee', value: student.feeLabel),
          _DetailRow(label: 'Location', value: student.location),
          _DetailRow(label: 'Status', value: student.status),
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
    required this.grade,
    required this.course,
    required this.courseId,
    required this.classFee,
    required this.classType,
    required this.location,
    required this.status,
    required this.createdBy,
    required this.qrPayload,
  });

  final String id;
  final String name;
  final String email;
  final String grade;
  final String course;
  final String courseId;
  final double classFee;
  final String classType;
  final String location;
  final String status;
  final String createdBy;
  final String qrPayload;

  factory _StudentDetailData.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final fallbackCourse = _readString(data, 'subject', 'General');

    return _StudentDetailData(
      id: id,
      name: _readString(data, 'name', 'Unnamed Student'),
      email: _readString(data, 'email', ''),
      grade: _readString(data, 'grade', ''),
      course: _readString(data, 'course', fallbackCourse),
      courseId: _readString(data, 'courseId', ''),
      classFee: _readDouble(data, 'classFee'),
      classType: _readString(data, 'classType', 'group'),
      location: _readString(data, 'location', ''),
      status: _readString(data, 'status', 'active'),
      createdBy: _readString(data, 'createdBy', ''),
      qrPayload: _readString(data, 'qrPayload', ''),
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
    final hasCents = classFee.truncateToDouble() != classFee;
    return 'Rs ${classFee.toStringAsFixed(hasCents ? 2 : 0)}';
  }
}
