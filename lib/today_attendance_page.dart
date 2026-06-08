import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TodayAttendancePage extends StatelessWidget {
  const TodayAttendancePage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;
    final today = DateTime.now();
    final dateKey = _dateKey(today);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: showBackButton,
        title: const Text(
          "Today's Attendance",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: teacher == null
          ? const _AttendanceMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Teacher login needed',
              message:
                  'Attendance details බලන්න teacher account එකෙන් login වෙන්න.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('createdBy', isEqualTo: teacher.uid)
                  .snapshots(),
              builder: (context, studentsSnapshot) {
                if (studentsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    studentsSnapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (studentsSnapshot.hasError) {
                  return const _AttendanceMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Could not load students',
                    message: 'Firestore rules check ?????.',
                  );
                }

                final activeStudentIds = (studentsSnapshot.data?.docs ?? [])
                    .where((doc) => doc.data()['role']?.toString() == 'student')
                    .where(
                      (doc) =>
                          doc.data()['status']?.toString().toLowerCase() !=
                          'archived',
                    )
                    .map((doc) => doc.id)
                    .toSet();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('teacher_attendance')
                      .doc(teacher.uid)
                      .collection('scans')
                      .where('dateKey', isEqualTo: dateKey)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const _AttendanceMessage(
                        icon: Icons.lock_outline_rounded,
                        title: 'Could not load attendance',
                        message: 'Firestore rules check ?????.',
                      );
                    }

                    final scans = (snapshot.data?.docs ?? [])
                        .map(
                          (doc) => _AttendanceScan.fromMap(doc.id, doc.data()),
                        )
                        .where(
                          (scan) =>
                              scan.isPresent &&
                              activeStudentIds.contains(scan.studentId),
                        )
                        .toList()
                      ..sort((first, second) {
                        final firstDate = first.scannedAt ?? DateTime(0);
                        final secondDate = second.scannedAt ?? DateTime(0);
                        return secondDate.compareTo(firstDate);
                      });
                    final overrides =
                        scans.where((scan) => scan.scheduleOverride).length;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        _AttendanceSummaryCard(
                          date: today,
                          total: scans.length,
                          overrides: overrides,
                        ),
                        const SizedBox(height: 16),
                        if (scans.isEmpty)
                          const _AttendanceMessage(
                            icon: Icons.fact_check_outlined,
                            title: 'No attendance yet',
                            message: '?? attendance scan ???? ????.',
                          )
                        else
                          for (final scan in scans) ...[
                            _AttendanceTile(scan: scan),
                            const SizedBox(height: 10),
                          ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({
    required this.date,
    required this.total,
    required this.overrides,
  });

  final DateTime date;
  final int total;
  final int overrides;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D5BEA), Color(0xFF6843EA)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateLabel(date),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total students present',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  overrides == 0
                      ? 'Only scheduled classes counted'
                      : '$overrides manual override${overrides == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.scan});

  final _AttendanceScan scan;

  @override
  Widget build(BuildContext context) {
    final isOverride = scan.scheduleOverride || !scan.classScheduledToday;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOverride
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFE7F9F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverride ? Icons.warning_amber_rounded : Icons.check_rounded,
              color: isOverride
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF00A86B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scan.courseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MiniMeta(
                        icon: Icons.calendar_month, label: scan.dateLabel),
                    _MiniMeta(
                        icon: Icons.schedule_rounded, label: scan.timeLabel),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: isOverride ? 'Override' : 'Scheduled',
            color:
                isOverride ? const Color(0xFFFF9500) : const Color(0xFF00A86B),
          ),
        ],
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8B97AD)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B97AD),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AttendanceMessage extends StatelessWidget {
  const _AttendanceMessage({
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
            Icon(icon, color: const Color(0xFF8C98AF), size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 17,
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

class _AttendanceScan {
  const _AttendanceScan({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.course,
    required this.grade,
    required this.dateKey,
    required this.scannedAt,
    required this.classScheduledToday,
    required this.scheduleOverride,
    required this.status,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String course;
  final String grade;
  final String dateKey;
  final DateTime? scannedAt;
  final bool classScheduledToday;
  final bool scheduleOverride;
  final String status;

  factory _AttendanceScan.fromMap(String id, Map<String, dynamic> data) {
    final scannedAt = data['scannedAt'];

    return _AttendanceScan(
      id: id,
      studentId: _readString(data, 'studentId', ''),
      studentName: _readString(data, 'studentName', 'Student'),
      course: _readString(
        data,
        'courseName',
        _readString(data, 'course', 'Course'),
      ),
      grade: _readString(data, 'grade', ''),
      dateKey: _readString(data, 'dateKey', ''),
      scannedAt: scannedAt is Timestamp ? scannedAt.toDate() : null,
      classScheduledToday: data['classScheduledToday'] != false,
      scheduleOverride: data['scheduleOverride'] == true,
      status: _readString(data, 'status', ''),
    );
  }

  bool get isPresent => status.toLowerCase() == 'present';

  String get courseLabel {
    if (grade.isEmpty) {
      return course;
    }

    return '$course • $grade';
  }

  String get dateLabel {
    final date = scannedAt;
    if (date != null) {
      return _dateLabel(date);
    }

    return dateKey.isEmpty ? '-' : dateKey;
  }

  String get timeLabel {
    final date = scannedAt;
    if (date == null) {
      return '-';
    }

    return _timeLabel(date);
  }
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
