import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardReportsSheet extends StatelessWidget {
  const DashboardReportsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: teacher == null
          ? const _ReportMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Teacher login needed',
              message: 'Reports බලන්න teacher account එකෙන් login වෙන්න.',
            )
          : _LiveReports(teacherUid: teacher.uid),
    );
  }
}

class _LiveReports extends StatelessWidget {
  const _LiveReports({required this.teacherUid});

  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('createdBy', isEqualTo: teacherUid)
          .snapshots(),
      builder: (context, studentsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('teacher_courses')
              .doc(teacherUid)
              .collection('courses')
              .snapshots(),
          builder: (context, coursesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_attendance')
                  .doc(teacherUid)
                  .collection('scans')
                  .where('dateKey', isEqualTo: _dateKey(DateTime.now()))
                  .snapshots(),
              builder: (context, attendanceSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('teacher_materials')
                      .doc(teacherUid)
                      .collection('materials')
                      .snapshots(),
                  builder: (context, materialsSnapshot) {
                    final snapshots = [
                      studentsSnapshot,
                      coursesSnapshot,
                      attendanceSnapshot,
                      materialsSnapshot,
                    ];
                    Object? error;
                    for (final snapshot in snapshots) {
                      if (snapshot.error != null) {
                        error = snapshot.error;
                        break;
                      }
                    }
                    final isLoading = snapshots.any((snapshot) {
                      return snapshot.connectionState ==
                              ConnectionState.waiting &&
                          snapshot.data == null;
                    });

                    if (error != null) {
                      return _ReportMessage(
                        icon: Icons.warning_amber_rounded,
                        title: 'Reports load failed',
                        message: _errorMessage(error),
                      );
                    }

                    final report = _DashboardReport.fromSnapshots(
                      studentsSnapshot.data?.docs ?? [],
                      coursesSnapshot.data?.docs ?? [],
                      attendanceSnapshot.data?.docs ?? [],
                      materialsSnapshot.data?.docs ?? [],
                    );

                    return _ReportsBody(
                      report: report,
                      isLoading: isLoading,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({
    required this.report,
    required this.isLoading,
  });

  final _DashboardReport report;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Reports',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Today live Firestore summary.',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF316DFF),
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              color: Color(0xFF316DFF),
              backgroundColor: Color(0xFFEAF0FF),
            ),
          ],
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _ReportCard(
                icon: Icons.groups_2_outlined,
                iconColor: const Color(0xFF316DFF),
                value: '${report.totalStudents}',
                label: 'Students',
                detail: '${report.activeStudents} active',
              ),
              _ReportCard(
                icon: Icons.fact_check_outlined,
                iconColor: const Color(0xFF0FAF75),
                value: '${report.attendancePercent}%',
                label: 'Attendance',
                detail: '${report.presentToday} present today',
              ),
              _ReportCard(
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFF7048E8),
                value: '${report.activeCourses}',
                label: 'Courses',
                detail: '${report.scheduledToday} scheduled today',
              ),
              _ReportCard(
                icon: Icons.attach_money_rounded,
                iconColor: const Color(0xFFFF9500),
                value: report.revenueLabel,
                label: 'Revenue',
                detail: '${report.pendingStudents} pending',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ReportSummaryRow(
            icon: Icons.upload_file_rounded,
            label: 'Uploaded materials',
            value: '${report.materialCount}',
          ),
          _ReportSummaryRow(
            icon: Icons.today_rounded,
            label: 'Report date',
            value: _dateKey(DateTime.now()),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60708F),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: iconColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryRow extends StatelessWidget {
  const _ReportSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF316DFF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF60708F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
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
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardReport {
  const _DashboardReport({
    required this.totalStudents,
    required this.activeStudents,
    required this.pendingStudents,
    required this.presentToday,
    required this.activeCourses,
    required this.scheduledToday,
    required this.materialCount,
    required this.monthlyRevenue,
  });

  final int totalStudents;
  final int activeStudents;
  final int pendingStudents;
  final int presentToday;
  final int activeCourses;
  final int scheduledToday;
  final int materialCount;
  final double monthlyRevenue;

  factory _DashboardReport.fromSnapshots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> studentDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courseDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> materialDocs,
  ) {
    final students = studentDocs
        .where((doc) => doc.data()['role']?.toString() == 'student')
        .where(
          (doc) => doc.data()['status']?.toString().toLowerCase() != 'archived',
        )
        .toList();
    final pendingStatuses = {'due', 'overdue', 'pending'};
    final activeStudents = students.length;
    final pendingStudents = students.where((doc) {
      return pendingStatuses.contains(
        (doc.data()['paymentStatus'] ?? doc.data()['status'] ?? '')
            .toString()
            .toLowerCase(),
      );
    }).length;
    final presentToday = attendanceDocs
        .map((doc) => doc.data()['studentId']?.toString() ?? '')
        .where((studentId) => studentId.isNotEmpty)
        .toSet()
        .length;
    final activeCourses = courseDocs
        .where((doc) => doc.data()['status']?.toString() != 'archived')
        .length;
    final scheduledToday = courseDocs.where((doc) {
      final data = doc.data();
      final isActive = data['status']?.toString() != 'archived';
      final days = _readStringList(data, 'scheduleDays');
      return isActive && days.contains(_shortDayName(DateTime.now()));
    }).length;
    final monthlyRevenue = students.fold<double>(0, (total, doc) {
      return total + _readDouble(doc.data(), 'classFee');
    });

    return _DashboardReport(
      totalStudents: students.length,
      activeStudents: activeStudents,
      pendingStudents: pendingStudents,
      presentToday: presentToday,
      activeCourses: activeCourses,
      scheduledToday: scheduledToday,
      materialCount: materialDocs.length,
      monthlyRevenue: monthlyRevenue,
    );
  }

  int get attendancePercent {
    if (totalStudents == 0) {
      return 0;
    }
    return ((presentToday / totalStudents) * 100).clamp(0, 100).round();
  }

  String get revenueLabel {
    if (monthlyRevenue >= 1000) {
      final value = monthlyRevenue / 1000;
      final text = value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return 'Rs ${text}k';
    }
    return 'Rs ${monthlyRevenue.toStringAsFixed(0)}';
  }
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _shortDayName(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
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

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _errorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firestore permission denied. Report rules check කරන්න.';
  }
  if (error is FirebaseException) {
    return 'Firebase error: ${error.message ?? error.code}';
  }
  return 'Reports load කරන්න බැරි වුණා.';
}
