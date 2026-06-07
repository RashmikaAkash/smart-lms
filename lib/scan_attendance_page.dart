import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'course_schedule_utils.dart';

class ScanAttendancePage extends StatefulWidget {
  const ScanAttendancePage({super.key});

  @override
  State<ScanAttendancePage> createState() => _ScanAttendancePageState();
}

class _ScanAttendancePageState extends State<ScanAttendancePage>
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

  CollectionReference<Map<String, dynamic>>? get _scanCollection {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_attendance')
        .doc(teacher.uid)
        .collection('scans');
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
      _statusMessage = 'Saving attendance...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      await _saveAttendance(rawValue);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Attendance saved';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lastScannedValue = null;
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
        _lastScannedValue = null;
        _statusMessage =
            error is StateError ? error.message : 'Could not save attendance.';
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

  Future<void> _saveAttendance(String qrValue) async {
    final teacher = FirebaseAuth.instance.currentUser;
    final scans = _scanCollection;

    if (teacher == null || scans == null) {
      throw StateError('Teacher is not signed in.');
    }

    final payload = _parseQrPayload(qrValue);
    final studentId = payload['studentId'] ?? qrValue;
    final qrTeacherUid = payload['teacherUid'] ?? '';

    if (qrTeacherUid.isNotEmpty && qrTeacherUid != teacher.uid) {
      throw StateError('This QR belongs to another teacher.');
    }

    final studentSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentId)
        .get();
    final studentData = studentSnapshot.data();
    if (!studentSnapshot.exists || studentData == null) {
      throw StateError('Student record not found.');
    }
    if (studentData['status']?.toString().toLowerCase() == 'archived') {
      throw StateError('This student was removed.');
    }

    final student = _AttendanceStudent.fromFirestore(
      id: studentSnapshot.id,
      data: studentData,
      payload: payload,
    );

    if (student.createdBy.isNotEmpty && student.createdBy != teacher.uid) {
      throw StateError('This student belongs to another teacher.');
    }

    final teacherCourseDocs = await FirebaseFirestore.instance
        .collection('teacher_courses')
        .doc(teacher.uid)
        .collection('courses')
        .get();
    final teacherCourses = teacherCourseDocs.docs
        .map(_AttendanceCourseOption.fromCourseSnapshot)
        .where((course) => course.status != 'archived')
        .toList();
    final now = DateTime.now();
    final dateKey = _dateKey(now);
    final todayCourses = _scheduledCoursesForToday(
      student.courses,
      teacherCourses,
      now,
    );
    var classScheduledToday = todayCourses.isNotEmpty;
    var scheduleOverride = false;
    _AttendanceCourseOption? selectedCourse;

    if (todayCourses.length == 1) {
      selectedCourse = todayCourses.first;
    } else if (todayCourses.length > 1) {
      selectedCourse = await _chooseAttendanceCourse(todayCourses);
      if (selectedCourse == null) {
        throw StateError('Attendance cancelled.');
      }
    } else {
      selectedCourse = student.preferredCourse(payload);
      final shouldSave = await _confirmNoClassToday(student, selectedCourse);
      if (!shouldSave) {
        await _cancelTodayAttendanceForStudent(scans, dateKey, student.id);
        throw StateError('Attendance cancelled.');
      }
      classScheduledToday = false;
      scheduleOverride = true;
    }

    final courseKey = _safeKey(
      selectedCourse.id.isNotEmpty ? selectedCourse.id : selectedCourse.name,
    );
    final documentId = '$dateKey-$studentId-$courseKey';

    await scans.doc(documentId).set({
      'studentId': student.id,
      'studentName': student.name,
      'studentEmail': student.email,
      'grade': selectedCourse.grade,
      'courseId': selectedCourse.id,
      'course': selectedCourse.name,
      'courseName': selectedCourse.name,
      'classFee': selectedCourse.classFee,
      'classType': selectedCourse.type,
      'location': selectedCourse.location,
      'classId': selectedCourse.classId,
      'dateKey': dateKey,
      'dateLabel': _dateLabel(now),
      'timeLabel': _timeLabel(now),
      'qrValue': qrValue,
      'qrTeacherUid': qrTeacherUid,
      'classScheduledToday': classScheduledToday,
      'scheduleOverride': scheduleOverride,
      'scheduleDays': selectedCourse.scheduleDays,
      'scheduleTime': selectedCourse.scheduleTime,
      'scheduleSlots':
          selectedCourse.scheduleSlots.map((slot) => slot.toMap()).toList(),
      'status': 'present',
      'teacherUid': teacher.uid,
      'scannedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<_AttendanceCourseOption> _scheduledCoursesForToday(
    List<_AttendanceCourseOption> studentCourses,
    List<_AttendanceCourseOption> teacherCourses,
    DateTime date,
  ) {
    final todayNames = {
      _shortDayName(date).toLowerCase(),
      _fullDayName(date).toLowerCase(),
    };
    final scheduledCourses = <_AttendanceCourseOption>[];

    void addScheduled(_AttendanceCourseOption course) {
      final exists = scheduledCourses.any(
        (saved) => saved.matchKeys.any(course.matchKeys.contains),
      );
      if (!exists) {
        scheduledCourses.add(course);
      }
    }

    for (final studentCourse in studentCourses) {
      for (final teacherCourse in teacherCourses) {
        final sameCourse = studentCourse.matchKeys.any(
          teacherCourse.matchKeys.contains,
        );
        if (!sameCourse || !teacherCourse.isScheduledOn(todayNames)) {
          continue;
        }

        addScheduled(studentCourse.mergeSchedule(teacherCourse));
      }
    }

    return scheduledCourses;
  }

  Future<_AttendanceCourseOption?> _chooseAttendanceCourse(
    List<_AttendanceCourseOption> courses,
  ) {
    return showDialog<_AttendanceCourseOption>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select today class'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: courses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final course = courses[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(course.title),
                  subtitle: Text(course.scheduleLabel),
                  trailing: Text(course.feeLabel),
                  onTap: () => Navigator.of(context).pop(course),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmNoClassToday(
    _AttendanceStudent student,
    _AttendanceCourseOption course,
  ) async {
    if (!mounted) {
      return false;
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('No class today'),
              content: Text(
                '${student.name}ට අද "${course.title}" class එක schedule වෙලා නැහැ.\n\nAttendance එක save කරන්නද?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Take Attendance'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _cancelTodayAttendanceForStudent(
    CollectionReference<Map<String, dynamic>> scans,
    String dateKey,
    String studentId,
  ) async {
    final snapshot = await scans.where('dateKey', isEqualTo: dateKey).get();
    final batch = FirebaseFirestore.instance.batch();
    var updateCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      if (data['studentId']?.toString() != studentId) {
        continue;
      }

      batch.update(document.reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updateCount++;
    }

    if (updateCount > 0) {
      await batch.commit();
    }
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
          if (uri.queryParameters['classId'] != null)
            'classId': uri.queryParameters['classId']!,
        };
      }
    }

    return <String, String>{'studentId': rawValue};
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manual attendance'),
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
              child: const Text('Save'),
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
      _statusMessage = 'Saving manual attendance...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      await _saveAttendance(studentId);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Manual attendance saved';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Could not save manual attendance.';
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
                      'Scan Attendance',
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
                          ? 'Saving scanned QR code...'
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
                    _RecentScansPanel(scans: _scanCollection),
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

class _AttendanceStudent {
  const _AttendanceStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.createdBy,
    required this.courses,
  });

  final String id;
  final String name;
  final String email;
  final String createdBy;
  final List<_AttendanceCourseOption> courses;

  factory _AttendanceStudent.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    required Map<String, String> payload,
  }) {
    final courses = <_AttendanceCourseOption>[];

    void addCourse(_AttendanceCourseOption course) {
      final exists = courses.any(
        (saved) => saved.matchKeys.any(course.matchKeys.contains),
      );
      if (!exists) {
        courses.add(course);
      }
    }

    void addCoursesFromField(String field) {
      final value = data[field];
      if (value is! Iterable) {
        return;
      }

      for (final item in value) {
        final course = _AttendanceCourseOption.tryParse(item);
        if (course != null) {
          addCourse(course);
        }
      }
    }

    addCoursesFromField('courses');
    addCoursesFromField('enrolledCourses');
    addCoursesFromField('studentCourses');
    addCourse(
      _AttendanceCourseOption(
        id: _readString(data, 'courseId', payload['courseId'] ?? ''),
        name: _readString(
          data,
          'course',
          payload['course'] ?? payload['classId'] ?? 'Course',
        ),
        grade: _readString(data, 'grade', payload['grade'] ?? ''),
        classId: _readString(data, 'classId', payload['classId'] ?? ''),
        classFee: _readDouble(data, 'classFee') ??
            double.tryParse(payload['classFee'] ?? '') ??
            0,
        type: _readString(data, 'classType', payload['classType'] ?? ''),
        location: _readString(data, 'location', payload['location'] ?? ''),
        scheduleDays: const [],
        scheduleTime: '',
        scheduleSlots: const [],
        status: 'active',
      ),
    );

    return _AttendanceStudent(
      id: id,
      name: _readString(data, 'name', payload['name'] ?? id),
      email: _readString(data, 'email', payload['email'] ?? ''),
      createdBy: _readString(data, 'createdBy', payload['teacherUid'] ?? ''),
      courses: List.unmodifiable(courses),
    );
  }

  _AttendanceCourseOption preferredCourse(Map<String, String> payload) {
    final payloadCourseId = payload['courseId']?.trim().toLowerCase() ?? '';
    final payloadCourseName = payload['course']?.trim().toLowerCase() ?? '';

    for (final course in courses) {
      if (payloadCourseId.isNotEmpty &&
          course.id.trim().toLowerCase() == payloadCourseId) {
        return course;
      }
      if (payloadCourseName.isNotEmpty &&
          course.name.trim().toLowerCase() == payloadCourseName) {
        return course;
      }
    }

    return courses.isEmpty
        ? _AttendanceCourseOption(
            id: payload['courseId'] ?? '',
            name: payload['course'] ?? payload['classId'] ?? 'Course',
            grade: payload['grade'] ?? '',
            classId: payload['classId'] ?? '',
            classFee: double.tryParse(payload['classFee'] ?? '') ?? 0,
            type: payload['classType'] ?? '',
            location: payload['location'] ?? '',
            scheduleDays: const [],
            scheduleTime: '',
            scheduleSlots: const [],
            status: 'active',
          )
        : courses.first;
  }
}

class _AttendanceCourseOption {
  const _AttendanceCourseOption({
    required this.id,
    required this.name,
    required this.grade,
    required this.classId,
    required this.classFee,
    required this.type,
    required this.location,
    required this.scheduleDays,
    required this.scheduleTime,
    required this.scheduleSlots,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final String classId;
  final double classFee;
  final String type;
  final String location;
  final List<String> scheduleDays;
  final String scheduleTime;
  final List<CourseScheduleSlot> scheduleSlots;
  final String status;

  factory _AttendanceCourseOption.fromCourseSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final slots = courseScheduleSlotsFromData(data);
    final scheduleDays = _readStringList(data, 'scheduleDays');
    return _AttendanceCourseOption(
      id: snapshot.id,
      name: _readString(data, 'name', 'Course'),
      grade: _readString(data, 'grade', ''),
      classId: _readString(data, 'classId', ''),
      classFee: _readDouble(data, 'classFee') ?? 0,
      type: _readString(data, 'type', _readString(data, 'classType', '')),
      location: _readString(data, 'location', ''),
      scheduleDays: scheduleDays.isNotEmpty
          ? scheduleDays
          : courseScheduleDaysFromSlots(slots),
      scheduleTime: _readString(data, 'scheduleTime', ''),
      scheduleSlots: slots,
      status: _readString(data, 'status', 'active'),
    );
  }

  static _AttendanceCourseOption? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final data = <String, dynamic>{};
    value.forEach((key, value) {
      data[key.toString()] = value;
    });
    final name = _readString(data, 'name', _readString(data, 'course', ''));
    final id = _readString(data, 'courseId', _readString(data, 'id', ''));

    if (name.isEmpty && id.isEmpty) {
      return null;
    }

    final slots = courseScheduleSlotsFromData(data);
    final scheduleDays = _readStringList(data, 'scheduleDays');
    return _AttendanceCourseOption(
      id: id,
      name: name.isEmpty ? 'Course' : name,
      grade: _readString(data, 'grade', ''),
      classId: _readString(data, 'classId', ''),
      classFee: _readDouble(data, 'classFee') ??
          _readDouble(data, 'amount') ??
          _readDouble(data, 'fee') ??
          0,
      type: _readString(data, 'classType', _readString(data, 'type', '')),
      location: _readString(data, 'location', ''),
      scheduleDays: scheduleDays.isNotEmpty
          ? scheduleDays
          : courseScheduleDaysFromSlots(slots),
      scheduleTime: _readString(data, 'scheduleTime', ''),
      scheduleSlots: slots,
      status: _readString(data, 'status', 'active'),
    );
  }

  _AttendanceCourseOption mergeSchedule(_AttendanceCourseOption teacherCourse) {
    return _AttendanceCourseOption(
      id: id.isNotEmpty ? id : teacherCourse.id,
      name: name.isNotEmpty ? name : teacherCourse.name,
      grade: grade.isNotEmpty ? grade : teacherCourse.grade,
      classId: classId.isNotEmpty ? classId : teacherCourse.classId,
      classFee: classFee > 0 ? classFee : teacherCourse.classFee,
      type: type.isNotEmpty ? type : teacherCourse.type,
      location: location.isNotEmpty ? location : teacherCourse.location,
      scheduleDays: teacherCourse.scheduleDays,
      scheduleTime: teacherCourse.scheduleTime,
      scheduleSlots: teacherCourse.scheduleSlots,
      status: status.isNotEmpty ? status : teacherCourse.status,
    );
  }

  bool isScheduledOn(Set<String> dayNames) {
    final slotMatches = scheduleSlots
        .map((slot) => slot.day.trim().toLowerCase())
        .any(dayNames.contains);
    return slotMatches ||
        scheduleDays
            .map((day) => day.trim().toLowerCase())
            .any(dayNames.contains);
  }

  Set<String> get matchKeys {
    final keys = <String>{};
    final idKey = id.trim().toLowerCase();
    final nameKey = name.trim().toLowerCase();

    if (idKey.isNotEmpty) {
      keys.add('id:$idKey');
    }
    if (nameKey.isNotEmpty) {
      keys.add('name:$nameKey');
    }

    return keys;
  }

  String get title {
    if (grade.isEmpty) {
      return name;
    }

    return '$name • $grade';
  }

  String get feeLabel {
    if (classFee <= 0) {
      return 'No fee';
    }

    final hasCents = classFee.truncateToDouble() != classFee;
    return 'Rs ${classFee.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  String get scheduleLabel {
    return courseScheduleLabel(
      scheduleDays: scheduleDays,
      scheduleTime: scheduleTime,
      scheduleSlots: scheduleSlots,
    );
  }
}

String _safeKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return normalized.isEmpty ? 'course' : normalized;
}

String _shortDayName(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

String _fullDayName(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[date.weekday - 1];
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
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
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 46,
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

class _RecentScansPanel extends StatelessWidget {
  const _RecentScansPanel({required this.scans});

  final CollectionReference<Map<String, dynamic>>? scans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2944),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Scans',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TodayCountBadge(scans: scans),
            ],
          ),
          const SizedBox(height: 12),
          if (scans == null)
            const _EmptyRecentScans(message: 'Sign in to save scans.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: scans!
                  .orderBy('scannedAt', descending: true)
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _EmptyRecentScans(message: 'Loading scans...');
                }

                if (snapshot.hasError) {
                  return const _EmptyRecentScans(
                    message: 'Could not load recent scans.',
                  );
                }

                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) => _isPresentScanData(doc.data()))
                    .toList();
                if (docs.isEmpty) {
                  return const _EmptyRecentScans(message: 'No scans yet.');
                }

                return Column(
                  children: [
                    for (var index = 0; index < docs.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _RecentScanTile(data: docs[index].data()),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TodayCountBadge extends StatelessWidget {
  const _TodayCountBadge({required this.scans});

  final CollectionReference<Map<String, dynamic>>? scans;

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (scans == null) {
      return const _CountBadge(label: 'Today: 0');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scans!
          .where('dateKey', isEqualTo: _dateKey(DateTime.now()))
          .snapshots(),
      builder: (context, snapshot) {
        final count = (snapshot.data?.docs ?? [])
            .where((doc) => _isPresentScanData(doc.data()))
            .length;
        return _CountBadge(label: 'Today: $count');
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2B5FFF),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

bool _isPresentScanData(Map<String, dynamic> data) {
  return data['status']?.toString().toLowerCase() == 'present';
}

class _EmptyRecentScans extends StatelessWidget {
  const _EmptyRecentScans({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3954),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFB8C4D8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['studentName']?.toString() ??
        data['studentId']?.toString() ??
        'Unknown student';
    final scannedAt = data['scannedAt'];
    final trailing = scannedAt is Timestamp
        ? _elapsedLabel(scannedAt.toDate())
        : data['status']?.toString() ?? 'Saved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3954),
        borderRadius: BorderRadius.circular(10),
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
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFFB8C4D8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _elapsedLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) {
      return 'now';
    }
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes}m ago';
    }
    if (elapsed.inDays < 1) {
      return '${elapsed.inHours}h ago';
    }
    return '${elapsed.inDays}d ago';
  }
}
