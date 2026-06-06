import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_course_sheet.dart';
import 'dashboard_reports_sheet.dart';
import 'courses_page.dart';
import 'profile_page.dart';
import 'scan_attendance_page.dart';
import 'scan_payment_page.dart';
import 'students_page.dart';
import 'upload_material_sheet.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  late final PageController _pageController;
  int _selectedIndex = 0;

  String get _name =>
      widget.userData['name']?.toString().trim().isNotEmpty == true
          ? widget.userData['name'].toString().trim()
          : 'Teacher';

  String get _initials {
    final parts = _name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'T' : letters.toUpperCase();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  if (_selectedIndex != index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  }
                },
                children: [
                  _DashboardHome(
                    greeting: _greeting,
                    name: _name,
                    initials: _initials,
                    onProfilePressed: () => _selectTab(4),
                    onCoursesPressed: () => _selectTab(2),
                  ),
                  const StudentsPage(
                    showBackButton: false,
                    showBottomNavigation: false,
                  ),
                  const CoursesPage(
                    showBackButton: false,
                  ),
                  const _ComingSoonPage(
                    title: 'Payments',
                    message: 'Payments section coming soon.',
                    icon: Icons.credit_card_rounded,
                  ),
                  ProfilePage(userData: widget.userData),
                ],
              ),
            ),
            _BottomNavigation(
              selectedIndex: _selectedIndex,
              onItemSelected: _selectTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.greeting,
    required this.name,
    required this.initials,
    required this.onProfilePressed,
    required this.onCoursesPressed,
  });

  final String greeting;
  final String name;
  final String initials;
  final VoidCallback onProfilePressed;
  final VoidCallback onCoursesPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            greeting: greeting,
            name: name,
            initials: initials,
            onProfilePressed: onProfilePressed,
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsGrid(
                    teacherUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Quick Actions',
                    actionLabel: null,
                    onActionPressed: null,
                  ),
                  const SizedBox(height: 10),
                  const _QuickActionGrid(),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: "Today's Classes",
                    actionLabel: 'See all',
                    onActionPressed: onCoursesPressed,
                  ),
                  const SizedBox(height: 10),
                  _ClassList(
                    teacherUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF8B97AD)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF60708F),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.initials,
    required this.onProfilePressed,
  });

  final String greeting;
  final String name;
  final String initials;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D5BEA),
            Color(0xFF6843EA),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Profile',
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onProfilePressed,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: _NextClassBanner(
              teacherUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.teacherUid});

  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty) {
      return const _StatsCards(stats: _DashboardStats.empty());
    }

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
                final stats = _DashboardStats.fromSnapshots(
                  studentsSnapshot.data?.docs ?? [],
                  coursesSnapshot.data?.docs ?? [],
                  attendanceSnapshot.data?.docs ?? [],
                );

                return _StatsCards(stats: stats);
              },
            );
          },
        );
      },
    );
  }
}

class _StatsCards extends StatelessWidget {
  const _StatsCards({required this.stats});

  final _DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        _StatCard(
          icon: Icons.groups_2_outlined,
          iconColor: const Color(0xFF316DFF),
          iconBackground: const Color(0xFFEAF0FF),
          value: '${stats.totalStudents}',
          label: 'Total Students',
          trend: '${stats.activeStudents} active',
          trendColor: const Color(0xFF00A86B),
        ),
        _StatCard(
          icon: Icons.insights_rounded,
          iconColor: const Color(0xFF0FAF75),
          iconBackground: const Color(0xFFE7F9F0),
          value: '${stats.attendancePercent}%',
          label: "Today's Attendance",
          trend: '${stats.presentToday}/${stats.totalStudents} present',
          trendColor: const Color(0xFF00A86B),
        ),
        _StatCard(
          icon: Icons.attach_money_rounded,
          iconColor: const Color(0xFFFF9500),
          iconBackground: const Color(0xFFFFF3E0),
          value: stats.revenueLabel,
          label: 'Monthly Revenue',
          trend: '${stats.pendingStudents} pending',
          trendColor: const Color(0xFFFF6B00),
        ),
        _StatCard(
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFF7048E8),
          iconBackground: const Color(0xFFF0ECFF),
          value: '${stats.activeCourses}',
          label: 'Active Courses',
          trend: '${stats.scheduledToday} today',
          trendColor: const Color(0xFF00A86B),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;
  final String trend;
  final Color trendColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF071B3C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.1,
              color: Color(0xFF60708F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            trend,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: trendColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionPressed,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF081A36),
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionPressed,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.45,
      children: [
        _ActionCard(
          icon: Icons.qr_code_scanner_rounded,
          iconColor: const Color(0xFF316DFF),
          label: 'Scan Attendance',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ScanAttendancePage(),
              ),
            );
          },
        ),
        _ActionCard(
          icon: Icons.payments_rounded,
          iconColor: const Color(0xFF00A86B),
          label: 'Scan Payment',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ScanPaymentPage(),
              ),
            );
          },
        ),
        _ActionCard(
          icon: Icons.add_rounded,
          iconColor: const Color(0xFF7048E8),
          label: 'Create Course',
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const CreateCourseSheet(),
            );
          },
        ),
        _ActionCard(
          icon: Icons.upload_rounded,
          iconColor: const Color(0xFF0FAF75),
          label: 'Upload Material',
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const UploadMaterialSheet(),
            );
          },
        ),
        _ActionCard(
          icon: Icons.bar_chart_rounded,
          iconColor: const Color(0xFFFF9500),
          label: 'View Reports',
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const DashboardReportsSheet(),
            );
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE5F4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF081A36),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassList extends StatelessWidget {
  const _ClassList({required this.teacherUid});

  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty) {
      return const _EmptyDashboardMessage(message: 'Teacher login needed.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacherUid)
          .collection('courses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _EmptyDashboardMessage(message: 'Loading classes...');
        }

        final classes = (snapshot.data?.docs ?? [])
            .map(_TodayClass.fromSnapshot)
            .where((course) => course.isActive && course.isToday)
            .toList()
          ..sort((first, second) => first.sortTime.compareTo(second.sortTime));

        if (classes.isEmpty) {
          return const _EmptyDashboardMessage(
            message: 'No classes scheduled for today.',
          );
        }

        return Column(
          children: [
            for (var index = 0; index < classes.take(4).length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _ClassTile.fromTodayClass(classes[index]),
            ],
          ],
        );
      },
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.subject,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
  });

  factory _ClassTile.fromTodayClass(_TodayClass course) {
    final colors = course.statusColors;

    return _ClassTile(
      icon: Icons.menu_book_rounded,
      iconColor: course.accentColor,
      iconBackground: course.iconBackground,
      subject: course.title,
      time: course.timeAndLocation,
      status: course.status,
      statusColor: colors.$1,
      statusBackground: colors.$2,
    );
  }

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String subject;
  final String time;
  final String status;
  final Color statusColor;
  final Color statusBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF081A36),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextClassBanner extends StatelessWidget {
  const _NextClassBanner({required this.teacherUid});

  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty) {
      return const _NextClassBannerRow(
        label: 'Today',
        value: 'Teacher login needed',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacherUid)
          .collection('courses')
          .snapshots(),
      builder: (context, snapshot) {
        final todayClasses = (snapshot.data?.docs ?? [])
            .map(_TodayClass.fromSnapshot)
            .where((course) => course.isActive && course.isToday)
            .toList()
          ..sort((first, second) => first.sortTime.compareTo(second.sortTime));

        final nextClass = todayClasses.isEmpty ? null : todayClasses.first;
        final todayLabel = 'Today - ${_fullDayName(DateTime.now())}';
        final value = nextClass == null
            ? 'No classes scheduled today'
            : 'Next class: ${nextClass.title} - ${nextClass.scheduleTime}';

        return _NextClassBannerRow(label: todayLabel, value: value);
      },
    );
  }
}

class _NextClassBannerRow extends StatelessWidget {
  const _NextClassBannerRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.access_time_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDashboardMessage extends StatelessWidget {
  const _EmptyDashboardMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF60708F),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.pendingStudents,
    required this.presentToday,
    required this.activeCourses,
    required this.scheduledToday,
    required this.monthlyRevenue,
  });

  const _DashboardStats.empty()
      : totalStudents = 0,
        activeStudents = 0,
        pendingStudents = 0,
        presentToday = 0,
        activeCourses = 0,
        scheduledToday = 0,
        monthlyRevenue = 0;

  final int totalStudents;
  final int activeStudents;
  final int pendingStudents;
  final int presentToday;
  final int activeCourses;
  final int scheduledToday;
  final double monthlyRevenue;

  factory _DashboardStats.fromSnapshots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> studentDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courseDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs,
  ) {
    final students = studentDocs
        .where((doc) => doc.data()['role']?.toString() == 'student')
        .toList();
    final pendingStatuses = {'due', 'overdue', 'pending'};
    final activeStudents = students
        .where((doc) => doc.data()['status']?.toString() != 'archived')
        .length;
    final pendingStudents = students.where((doc) {
      return pendingStatuses.contains(
        (doc.data()['paymentStatus'] ?? doc.data()['status'] ?? '')
            .toString()
            .toLowerCase(),
      );
    }).length;
    final revenue = students.fold<double>(0, (total, doc) {
      return total + _readDouble(doc.data(), 'classFee');
    });
    final activeCourses = courseDocs
        .where((doc) => doc.data()['status']?.toString() != 'archived')
        .length;
    final scheduledToday = courseDocs
        .map(_TodayClass.fromSnapshot)
        .where((course) => course.isActive && course.isToday)
        .length;
    final presentStudentIds = attendanceDocs
        .map((doc) => doc.data()['studentId']?.toString() ?? '')
        .where((studentId) => studentId.isNotEmpty)
        .toSet();

    return _DashboardStats(
      totalStudents: students.length,
      activeStudents: activeStudents,
      pendingStudents: pendingStudents,
      presentToday: presentStudentIds.length,
      activeCourses: activeCourses,
      scheduledToday: scheduledToday,
      monthlyRevenue: revenue,
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

class _TodayClass {
  const _TodayClass({
    required this.id,
    required this.name,
    required this.grade,
    required this.location,
    required this.scheduleDays,
    required this.scheduleTime,
    required this.statusValue,
  });

  final String id;
  final String name;
  final String grade;
  final String location;
  final List<String> scheduleDays;
  final String scheduleTime;
  final String statusValue;

  factory _TodayClass.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _TodayClass(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      location: _readString(data, 'location', ''),
      scheduleDays: _readStringList(data, 'scheduleDays'),
      scheduleTime: _readString(data, 'scheduleTime', ''),
      statusValue: _readString(data, 'status', 'active'),
    );
  }

  bool get isActive => statusValue != 'archived';

  bool get isToday => scheduleDays.contains(_shortDayName(DateTime.now()));

  int get sortTime => _minutesFromTime(scheduleTime) ?? 9999;

  String get title => grade.isEmpty ? name : '$name $grade';

  String get timeAndLocation {
    final parts = <String>[
      if (scheduleTime.isNotEmpty) scheduleTime,
      if (location.isNotEmpty) location,
    ];
    return parts.isEmpty ? 'Schedule time not set' : parts.join(' • ');
  }

  String get status {
    final minutes = _minutesFromTime(scheduleTime);
    if (minutes == null) {
      return 'Later';
    }

    final now = DateTime.now();
    final currentMinutes = (now.hour * 60) + now.minute;

    if (currentMinutes >= minutes && currentMinutes <= minutes + 90) {
      return 'Live';
    }
    if (currentMinutes < minutes) {
      return 'Soon';
    }
    return 'Done';
  }

  Color get accentColor {
    final colors = [
      const Color(0xFF316DFF),
      const Color(0xFF7048E8),
      const Color(0xFF0FAF75),
      const Color(0xFFFF9500),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  Color get iconBackground => accentColor.withOpacity(0.12);

  (Color, Color) get statusColors {
    switch (status) {
      case 'Live':
        return (const Color(0xFF00A86B), const Color(0xFFE7F9F0));
      case 'Soon':
        return (const Color(0xFFFF9500), const Color(0xFFFFF3E0));
      case 'Done':
        return (const Color(0xFF8B97AD), const Color(0xFFEFF2F7));
      default:
        return (const Color(0xFF316DFF), const Color(0xFFEAF0FF));
    }
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F4)),
        ),
      ),
      child: Row(
        children: [
          _BottomNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isActive: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _BottomNavItem(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            isActive: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _BottomNavItem(
            icon: Icons.menu_book_outlined,
            label: 'Courses',
            isActive: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _BottomNavItem(
            icon: Icons.credit_card_rounded,
            label: 'Payments',
            isActive: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
          _BottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: selectedIndex == 4,
            onTap: () => onItemSelected(4),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF316DFF) : const Color(0xFF8B97AD);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEAF0FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isActive ? 1.08 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

String _readString(
  Map<String, dynamic> data,
  String key,
  String fallback,
) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
}

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
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

int? _minutesFromTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(trimmed);

  if (match == null) {
    return null;
  }

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final period = match.group(3)?.toUpperCase();

  if (hour == null || minute < 0 || minute > 59) {
    return null;
  }

  if (period == 'PM' && hour < 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  if (hour < 0 || hour > 23) {
    return null;
  }

  return (hour * 60) + minute;
}
