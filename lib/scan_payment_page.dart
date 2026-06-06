import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPaymentPage extends StatefulWidget {
  const ScanPaymentPage({super.key});

  @override
  State<ScanPaymentPage> createState() => _ScanPaymentPageState();
}

class _ScanPaymentPageState extends State<ScanPaymentPage>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _scanLineController;
  late final AnimationController _successController;

  bool _isSaving = false;
  String? _lastScannedValue;
  String? _statusMessage;
  Color _statusColor = const Color(0xFF20D6A1);

  CollectionReference<Map<String, dynamic>>? get _paymentsCollection {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_payments')
        .doc(teacher.uid)
        .collection('payments');
  }

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _successController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isSaving || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty || rawValue == _lastScannedValue) {
      return;
    }

    setState(() {
      _isSaving = true;
      _lastScannedValue = rawValue;
      _statusMessage = 'Checking student payment...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      final result = await _collectPayment(rawValue);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            '${result.studentName} • ${result.courseName} paid ${result.amountLabel}';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.code == 'permission-denied'
            ? 'Permission denied. Check Firestore rules.'
            : 'Firebase error: ${error.message ?? error.code}';
        _statusColor = const Color(0xFFFF526B);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            error is StateError ? error.message : 'Could not save payment.';
        _statusColor = const Color(0xFFFF526B);
      });
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<_PaymentResult> _collectPayment(String qrValue) async {
    final teacher = FirebaseAuth.instance.currentUser;
    final payments = _paymentsCollection;

    if (teacher == null || payments == null) {
      throw StateError('Teacher is not signed in.');
    }

    final payload = _parseQrPayload(qrValue);
    final studentId = payload['studentId'] ?? qrValue;
    if (studentId.trim().isEmpty) {
      throw StateError('Invalid student QR.');
    }

    final qrTeacherUid = payload['teacherUid'] ?? '';
    if (qrTeacherUid.isNotEmpty && qrTeacherUid != teacher.uid) {
      throw StateError('This QR belongs to another teacher.');
    }

    final studentSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentId)
        .get();

    if (!studentSnapshot.exists) {
      throw StateError('Student not found.');
    }

    final studentData = studentSnapshot.data() ?? <String, dynamic>{};
    final createdBy = studentData['createdBy']?.toString() ?? '';
    if (createdBy.isNotEmpty && createdBy != teacher.uid) {
      throw StateError('This student belongs to another teacher.');
    }

    final student = _PaymentStudent.fromData(
      id: studentSnapshot.id,
      data: studentData,
      payload: payload,
    );
    final courses = await _studentCourses(
      teacherUid: teacher.uid,
      studentData: studentData,
      payload: payload,
    );

    if (courses.isEmpty) {
      throw StateError('No course found for this student.');
    }

    final selectedCourse = courses.length == 1
        ? courses.first
        : await _chooseCourse(student, courses);

    if (selectedCourse == null) {
      throw StateError('Payment cancelled.');
    }

    return _savePayment(
      qrValue: qrValue,
      teacherUid: teacher.uid,
      teacherEmail: teacher.email ?? '',
      student: student,
      course: selectedCourse,
      payments: payments,
    );
  }

  Future<List<_PaymentCourse>> _studentCourses({
    required String teacherUid,
    required Map<String, dynamic> studentData,
    required Map<String, String> payload,
  }) async {
    final courses = <_PaymentCourse>[];

    void addCourse(_PaymentCourse course) {
      final key = course.id.isNotEmpty ? course.id : course.name.toLowerCase();
      if (key.isEmpty) {
        return;
      }
      if (courses.any((existing) {
        final existingKey =
            existing.id.isNotEmpty ? existing.id : existing.name.toLowerCase();
        return existingKey == key;
      })) {
        return;
      }
      courses.add(course);
    }

    for (final field in ['courses', 'enrolledCourses', 'studentCourses']) {
      final value = studentData[field];
      if (value is Iterable) {
        for (final item in value) {
          final course = _PaymentCourse.tryParse(item);
          if (course != null) {
            addCourse(course);
          }
        }
      }
    }

    final courseIds = _readStringList(studentData, 'courseIds');
    for (final courseId in courseIds) {
      final courseSnapshot = await FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacherUid)
          .collection('courses')
          .doc(courseId)
          .get();
      if (courseSnapshot.exists) {
        addCourse(_PaymentCourse.fromCourseDoc(courseSnapshot));
      }
    }

    final singleCourseId = _readString(studentData, 'courseId', '');
    if (singleCourseId.isNotEmpty) {
      final courseSnapshot = await FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacherUid)
          .collection('courses')
          .doc(singleCourseId)
          .get();
      if (courseSnapshot.exists) {
        addCourse(_PaymentCourse.fromCourseDoc(courseSnapshot));
      }
    }

    final fallbackCourse = _PaymentCourse(
      id: singleCourseId.isNotEmpty
          ? singleCourseId
          : payload['courseId'] ?? '',
      name: _readString(studentData, 'course', payload['course'] ?? 'Course'),
      grade: _readString(studentData, 'grade', payload['grade'] ?? ''),
      amount: _readDouble(studentData, 'classFee') ??
          double.tryParse(payload['classFee'] ?? '') ??
          0,
      type: _readString(studentData, 'classType', payload['classType'] ?? ''),
      location: _readString(studentData, 'location', payload['location'] ?? ''),
    );
    addCourse(fallbackCourse);

    return courses;
  }

  Future<_PaymentCourse?> _chooseCourse(
    _PaymentStudent student,
    List<_PaymentCourse> courses,
  ) async {
    _scannerController.stop();

    final selectedCourse = await showModalBottomSheet<_PaymentCourse>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                student.name,
                style: const TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'මේ student courses කිහිපයක register වෙලා. Payment එක ගන්න course එක තෝරන්න.',
                style: TextStyle(
                  color: Color(0xFF60708F),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final course in courses) ...[
                _CourseChoiceTile(
                  course: course,
                  onTap: () => Navigator.of(context).pop(course),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );

    if (mounted) {
      _scannerController.start();
    }

    return selectedCourse;
  }

  Future<_PaymentResult> _savePayment({
    required String qrValue,
    required String teacherUid,
    required String teacherEmail,
    required _PaymentStudent student,
    required _PaymentCourse course,
    required CollectionReference<Map<String, dynamic>> payments,
  }) async {
    final now = DateTime.now();
    final monthKey = _monthKey(now);
    final courseKey = _safeKey(course.id.isNotEmpty ? course.id : course.name);
    final documentId = '$monthKey-${student.id}-$courseKey';
    final studentReference =
        FirebaseFirestore.instance.collection('users').doc(student.id);
    final paymentData = {
      'id': documentId,
      'studentId': student.id,
      'studentName': student.name,
      'studentEmail': student.email,
      'grade': student.grade,
      'courseId': course.id,
      'course': course.name,
      'courseName': course.name,
      'classType': course.type,
      'location': course.location,
      'amount': course.amount,
      'monthKey': monthKey,
      'monthLabel': _monthLabel(now),
      'status': 'paid',
      'source': 'qr_scan',
      'qrValue': qrValue,
      'teacherUid': teacherUid,
      'teacherEmail': teacherEmail,
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(
          payments.doc(documentId), paymentData, SetOptions(merge: true));
      transaction.set(
          studentReference,
          {
            'status': 'paid',
            'paymentStatus': 'paid',
            'paymentMonth': monthKey,
            'lastPaidCourseId': course.id,
            'lastPaidCourse': course.name,
            'lastPaidAmount': course.amount,
            'lastPaidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'payments': {
              courseKey: {
                'courseId': course.id,
                'course': course.name,
                'amount': course.amount,
                'monthKey': monthKey,
                'status': 'paid',
              },
            },
          },
          SetOptions(merge: true));
    });

    return _PaymentResult(
      studentName: student.name,
      courseName: course.name,
      amount: course.amount,
    );
  }

  Map<String, String> _parseQrPayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      // Plain student IDs are valid QR values.
    }

    final uri = Uri.tryParse(rawValue);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final studentId =
          uri.queryParameters['studentId'] ?? uri.queryParameters['id'];
      if (studentId != null && studentId.trim().isNotEmpty) {
        return <String, String>{
          'studentId': studentId.trim(),
          if (uri.queryParameters['name'] != null)
            'name': uri.queryParameters['name']!,
          if (uri.queryParameters['courseId'] != null)
            'courseId': uri.queryParameters['courseId']!,
        };
      }
    }

    return <String, String>{'studentId': rawValue};
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _safeKey(String value) {
    final key = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return key.isEmpty ? 'course' : key;
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manual payment'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              hintText: 'Enter student ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop();
                if (value.isNotEmpty) {
                  _handleManualEntry(value);
                }
              },
              child: const Text('Collect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleManualEntry(String studentId) async {
    setState(() {
      _isSaving = true;
      _lastScannedValue = null;
      _statusMessage = 'Saving manual payment...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      final result = await _collectPayment(studentId);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            '${result.studentName} • ${result.courseName} paid ${result.amountLabel}';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            error is StateError ? error.message : 'Could not save payment.';
        _statusColor = const Color(0xFFFF526B);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1833),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _showManualEntryDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white54,
                      backgroundColor: const Color(0xFF283854),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Manual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScannerFrame(
                      controller: _scannerController,
                      onDetect: _handleDetect,
                      scanAnimation: _scanLineController,
                      successAnimation: _successController,
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isSaving
                          ? 'Collecting payment...'
                          : "Point camera at student's QR code",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    _RecentPaymentsPanel(payments: _paymentsCollection),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({
    required this.controller,
    required this.onDetect,
    required this.scanAnimation,
    required this.successAnimation,
    required this.isSaving,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final Animation<double> scanAnimation;
  final Animation<double> successAnimation;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
            Container(color: Colors.black.withOpacity(0.18)),
            _ScanLaserLine(animation: scanAnimation),
            _ScannerStatusHalo(isSaving: isSaving),
            _SuccessPulse(animation: successAnimation),
            const _ScannerCorner(alignment: Alignment.topLeft),
            const _ScannerCorner(alignment: Alignment.topRight),
            const _ScannerCorner(alignment: Alignment.bottomLeft),
            const _ScannerCorner(alignment: Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

class _ScanLaserLine extends StatelessWidget {
  const _ScanLaserLine({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final travelDistance = constraints.maxHeight - 112;
              final top = 56 + (travelDistance * animation.value);

              return Stack(
                children: [
                  Positioned(
                    left: 48,
                    right: 48,
                    top: top,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x004E7BFF),
                            Color(0xFF4E7BFF),
                            Color(0xFF20D6A1),
                            Color(0x004E7BFF),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xAA4E7BFF),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ScannerStatusHalo extends StatelessWidget {
  const _ScannerStatusHalo({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: isSaving ? 96 : 128,
        height: isSaving ? 96 : 128,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSaving
                ? const Color(0xFF20D6A1).withOpacity(0.9)
                : const Color(0xFF4E7BFF).withOpacity(0.25),
            width: isSaving ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isSaving ? const Color(0xFF20D6A1) : const Color(0xFF4E7BFF))
                      .withOpacity(isSaving ? 0.35 : 0.12),
              blurRadius: isSaving ? 32 : 18,
              spreadRadius: isSaving ? 6 : 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessPulse extends StatelessWidget {
  const _SuccessPulse({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }

        final value = Curves.easeOutCubic.transform(animation.value);
        final opacity = (1 - value).clamp(0.0, 1.0);

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.65 + (value * 1.4),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF20D6A1).withOpacity(0.22),
                  border: Border.all(
                    color: const Color(0xFF20D6A1),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA20D6A1),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: [
              Positioned(
                top: isTop ? 0 : null,
                bottom: isTop ? null : 0,
                left: isLeft ? 0 : null,
                right: isLeft ? null : 0,
                child: Container(
                  width: 28,
                  height: 2,
                  color: const Color(0xFF4E7BFF),
                ),
              ),
              Positioned(
                top: isTop ? 0 : null,
                bottom: isTop ? null : 0,
                left: isLeft ? 0 : null,
                right: isLeft ? null : 0,
                child: Container(
                  width: 2,
                  height: 28,
                  color: const Color(0xFF4E7BFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseChoiceTile extends StatelessWidget {
  const _CourseChoiceTile({
    required this.course,
    required this.onTap,
  });

  final _PaymentCourse course;
  final VoidCallback onTap;

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
              Text(
                course.amountLabel,
                style: const TextStyle(
                  color: Color(0xFF00A86B),
                  fontSize: 13,
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

class _RecentPaymentsPanel extends StatelessWidget {
  const _RecentPaymentsPanel({required this.payments});

  final CollectionReference<Map<String, dynamic>>? payments;

  @override
  Widget build(BuildContext context) {
    final paymentsCollection = payments;
    if (paymentsCollection == null) {
      return const _RecentPaymentShell(
        children: [
          _PaymentPanelMessage(message: 'Teacher login needed.'),
        ],
      );
    }

    final month = _currentMonthKey();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          paymentsCollection.where('monthKey', isEqualTo: month).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _RecentPaymentShell(
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4E7BFF)),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return const _RecentPaymentShell(
            children: [
              _PaymentPanelMessage(
                message: 'Payments load failed. Rules check කරන්න.',
              ),
            ],
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList()
          ..sort((first, second) {
            final firstPaidAt = first.data()['paidAt'];
            final secondPaidAt = second.data()['paidAt'];
            final firstDate = firstPaidAt is Timestamp
                ? firstPaidAt.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final secondDate = secondPaidAt is Timestamp
                ? secondPaidAt.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            return secondDate.compareTo(firstDate);
          });
        final recent = docs.take(5).toList();

        if (recent.isEmpty) {
          return const _RecentPaymentShell(
            children: [
              _PaymentPanelMessage(
                  message: 'No payments collected this month.'),
            ],
          );
        }

        return _RecentPaymentShell(
          children: [
            for (var index = 0; index < recent.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _RecentPaymentTile(data: recent[index].data()),
            ],
          ],
        );
      },
    );
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }
}

class _RecentPaymentShell extends StatelessWidget {
  const _RecentPaymentShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Payments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'This month',
                  style: TextStyle(
                    color: Color(0xFF316DFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _RecentPaymentTile extends StatelessWidget {
  const _RecentPaymentTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final amount = _readDouble(data, 'amount') ?? 0;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3A56),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF20D6A1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readString(data, 'studentName', 'Student'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _readString(data, 'course', 'Course'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _amountLabel(amount),
            style: const TextStyle(
              color: Color(0xFF20D6A1),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPanelMessage extends StatelessWidget {
  const _PaymentPanelMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentStudent {
  const _PaymentStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.grade,
  });

  final String id;
  final String name;
  final String email;
  final String grade;

  factory _PaymentStudent.fromData({
    required String id,
    required Map<String, dynamic> data,
    required Map<String, String> payload,
  }) {
    return _PaymentStudent(
      id: id,
      name: _readString(data, 'name', payload['name'] ?? id),
      email: _readString(data, 'email', payload['email'] ?? ''),
      grade: _readString(data, 'grade', payload['grade'] ?? ''),
    );
  }
}

class _PaymentCourse {
  const _PaymentCourse({
    required this.id,
    required this.name,
    required this.grade,
    required this.amount,
    required this.type,
    required this.location,
  });

  final String id;
  final String name;
  final String grade;
  final double amount;
  final String type;
  final String location;

  factory _PaymentCourse.fromCourseDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return _PaymentCourse(
      id: snapshot.id,
      name: _readString(data, 'name', 'Course'),
      grade: _readString(data, 'grade', ''),
      amount: _readDouble(data, 'classFee') ?? 0,
      type: _readString(data, 'type', ''),
      location: _readString(data, 'location', ''),
    );
  }

  static _PaymentCourse? tryParse(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return _PaymentCourse(
        id: '',
        name: value.trim(),
        grade: '',
        amount: 0,
        type: '',
        location: '',
      );
    }

    if (value is Map) {
      final data = value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name =
          _readString(data, 'name', _readString(data, 'course', 'Course'));
      return _PaymentCourse(
        id: _readString(data, 'courseId', _readString(data, 'id', '')),
        name: name,
        grade: _readString(data, 'grade', ''),
        amount: _readDouble(data, 'classFee') ??
            _readDouble(data, 'amount') ??
            _readDouble(data, 'fee') ??
            0,
        type: _readString(data, 'classType', _readString(data, 'type', '')),
        location: _readString(data, 'location', ''),
      );
    }

    return null;
  }

  String get title => grade.isEmpty ? name : '$name • $grade';

  String get metaLabel {
    final details = <String>[
      if (type.isNotEmpty) type,
      if (location.isNotEmpty) location,
    ];
    return details.isEmpty ? 'Class fee' : details.join(' • ');
  }

  String get amountLabel => _amountLabel(amount);
}

class _PaymentResult {
  const _PaymentResult({
    required this.studentName,
    required this.courseName,
    required this.amount,
  });

  final String studentName;
  final String courseName;
  final double amount;

  String get amountLabel => _amountLabel(amount);
}

String _amountLabel(double amount) {
  final hasCents = amount.truncateToDouble() != amount;
  return 'Rs ${amount.toStringAsFixed(hasCents ? 2 : 0)}';
}

String _readString(
  Map<String, dynamic> data,
  String key,
  String fallback,
) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
}

double? _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
