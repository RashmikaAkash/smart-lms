import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'course_schedule_utils.dart';
import 'create_assignment_page.dart';
import 'create_course_sheet.dart';
import 'create_live_class_page.dart';
import 'create_quiz_page.dart';
import 'dashboard_reports_sheet.dart';
import 'courses_page.dart';
import 'notifications_page.dart';
import 'payment_details_page.dart';
import 'profile_page.dart';
import 'scan_attendance_page.dart';
import 'scan_payment_page.dart';
import 'students_page.dart';
import 'today_attendance_page.dart';
import 'upload_material_sheet.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  late final PageController _pageController;
  final List<int> _tabHistory = <int>[0];
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

  void _selectTab(int index, {bool addToHistory = true}) {
    if (_selectedIndex == index) {
      return;
    }

    if (addToHistory) {
      _tabHistory.remove(index);
      _tabHistory.add(index);
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

  void _goBackTab() {
    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      _selectTab(_tabHistory.last, addToHistory: false);
      return;
    }

    if (_selectedIndex != 0) {
      _selectTab(0, addToHistory: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }

        _goBackTab();
      },
      child: Scaffold(
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
                      onNotificationsPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                      onStudentsPressed: () => _selectTab(1),
                      onCoursesPressed: () => _selectTab(2),
                      onAttendancePressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TodayAttendancePage(),
                          ),
                        );
                      },
                      onPaymentsPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PaymentDetailsPage(),
                          ),
                        );
                      },
                    ),
                    const StudentsPage(
                      showBackButton: false,
                      showBottomNavigation: false,
                    ),
                    const CoursesPage(
                      showBackButton: false,
                    ),
                    const PaymentDetailsPage(showBackButton: false),
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
    required this.onNotificationsPressed,
    required this.onStudentsPressed,
    required this.onCoursesPressed,
    required this.onAttendancePressed,
    required this.onPaymentsPressed,
  });

  final String greeting;
  final String name;
  final String initials;
  final VoidCallback onProfilePressed;
  final VoidCallback onNotificationsPressed;
  final VoidCallback onStudentsPressed;
  final VoidCallback onCoursesPressed;
  final VoidCallback onAttendancePressed;
  final VoidCallback onPaymentsPressed;

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
            onNotificationsPressed: onNotificationsPressed,
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
                    onStudentsPressed: onStudentsPressed,
                    onAttendancePressed: onAttendancePressed,
                    onPaymentsPressed: onPaymentsPressed,
                    onCoursesPressed: onCoursesPressed,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.initials,
    required this.onProfilePressed,
    required this.onNotificationsPressed,
  });

  final String greeting;
  final String name;
  final String initials;
  final VoidCallback onProfilePressed;
  final VoidCallback onNotificationsPressed;

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
                onPressed: onNotificationsPressed,
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
  const _StatsGrid({
    required this.teacherUid,
    required this.onStudentsPressed,
    required this.onAttendancePressed,
    required this.onPaymentsPressed,
    required this.onCoursesPressed,
  });

  final String teacherUid;
  final VoidCallback onStudentsPressed;
  final VoidCallback onAttendancePressed;
  final VoidCallback onPaymentsPressed;
  final VoidCallback onCoursesPressed;

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty) {
      return _StatsCards(
        stats: const _DashboardStats.empty(),
        onStudentsPressed: onStudentsPressed,
        onAttendancePressed: onAttendancePressed,
        onPaymentsPressed: onPaymentsPressed,
        onCoursesPressed: onCoursesPressed,
      );
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
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('teacher_payments')
                      .doc(teacherUid)
                      .collection('payments')
                      .where('monthKey', isEqualTo: _monthKey(DateTime.now()))
                      .snapshots(),
                  builder: (context, paymentsSnapshot) {
                    final stats = _DashboardStats.fromSnapshots(
                      studentsSnapshot.data?.docs ?? [],
                      coursesSnapshot.data?.docs ?? [],
                      attendanceSnapshot.data?.docs ?? [],
                      paymentsSnapshot.data?.docs ?? [],
                    );

                    return _StatsCards(
                      stats: stats,
                      onStudentsPressed: onStudentsPressed,
                      onAttendancePressed: onAttendancePressed,
                      onPaymentsPressed: onPaymentsPressed,
                      onCoursesPressed: onCoursesPressed,
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

class _StatsCards extends StatelessWidget {
  const _StatsCards({
    required this.stats,
    required this.onStudentsPressed,
    required this.onAttendancePressed,
    required this.onPaymentsPressed,
    required this.onCoursesPressed,
  });

  final _DashboardStats stats;
  final VoidCallback onStudentsPressed;
  final VoidCallback onAttendancePressed;
  final VoidCallback onPaymentsPressed;
  final VoidCallback onCoursesPressed;

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
          onTap: onStudentsPressed,
        ),
        _StatCard(
          icon: Icons.insights_rounded,
          iconColor: const Color(0xFF0FAF75),
          iconBackground: const Color(0xFFE7F9F0),
          value: '${stats.attendancePercent}%',
          label: "Today's Attendance",
          trend:
              '${stats.presentToday}/${stats.attendanceBaseStudents} present',
          trendColor: const Color(0xFF00A86B),
          onTap: onAttendancePressed,
        ),
        _StatCard(
          icon: Icons.attach_money_rounded,
          iconColor: const Color(0xFFFF9500),
          iconBackground: const Color(0xFFFFF3E0),
          value: stats.revenueLabel,
          label: 'Monthly Revenue',
          trend: stats.revenueTrendLabel,
          trendColor: stats.pendingStudents == 0
              ? const Color(0xFF00A86B)
              : const Color(0xFFFF6B00),
          onTap: onPaymentsPressed,
        ),
        _StatCard(
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFF7048E8),
          iconBackground: const Color(0xFFF0ECFF),
          value: '${stats.activeCourses}',
          label: 'Active Courses',
          trend: '${stats.scheduledToday} today',
          trendColor: const Color(0xFF00A86B),
          onTap: onCoursesPressed,
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
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;
  final String trend;
  final Color trendColor;
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
        ),
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
          icon: Icons.quiz_rounded,
          iconColor: const Color(0xFF316DFF),
          label: 'Create Quiz',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateQuizPage(),
              ),
            );
          },
        ),
        _ActionCard(
          icon: Icons.assignment_rounded,
          iconColor: const Color(0xFFFF9500),
          label: 'Create Assignment',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateAssignmentPage(),
              ),
            );
          },
        ),
        _ActionCard(
          icon: Icons.live_tv_rounded,
          iconColor: const Color(0xFFFF3B6B),
          label: 'Share Live Class',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateLiveClassPage(),
              ),
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

class _NextClassBanner extends StatefulWidget {
  const _NextClassBanner({required this.teacherUid});

  final String teacherUid;

  @override
  State<_NextClassBanner> createState() => _NextClassBannerState();
}

class _NextClassBannerState extends State<_NextClassBanner> {
  late DateTime _now;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teacherUid.isEmpty) {
      return const _NextClassBannerRow(
        label: 'Today',
        value: 'Teacher login needed',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(widget.teacherUid)
          .collection('courses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return _NextClassBannerRow(
            label: _nextClassDateLabel(_now, _now),
            value: 'Loading next class...',
          );
        }

        final upcomingClasses = (snapshot.data?.docs ?? [])
            .map(_TodayClass.fromSnapshot)
            .where((course) => course.isActive)
            .map((course) {
              final startAt = course.nextStartAfter(_now);
              return startAt == null
                  ? null
                  : _UpcomingClass(course: course, startAt: startAt);
            })
            .whereType<_UpcomingClass>()
            .toList()
          ..sort((first, second) => first.startAt.compareTo(second.startAt));

        if (upcomingClasses.isEmpty) {
          return _NextClassBannerRow(
            label: _nextClassDateLabel(_now, _now),
            value: 'No upcoming classes scheduled',
          );
        }

        final nextClass = upcomingClasses.first;

        return _NextClassBannerRow(
          label: _nextClassDateLabel(nextClass.startAt, _now),
          value:
              'Next class: ${nextClass.course.title} - ${nextClass.course.timeLabelForDate(nextClass.startAt)}',
        );
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
    required this.attendanceBaseStudents,
    required this.activeCourses,
    required this.scheduledToday,
    required this.monthlyRevenue,
    required this.paidPayments,
  });

  const _DashboardStats.empty()
      : totalStudents = 0,
        activeStudents = 0,
        pendingStudents = 0,
        presentToday = 0,
        attendanceBaseStudents = 0,
        activeCourses = 0,
        scheduledToday = 0,
        monthlyRevenue = 0,
        paidPayments = 0;

  final int totalStudents;
  final int activeStudents;
  final int pendingStudents;
  final int presentToday;
  final int attendanceBaseStudents;
  final int activeCourses;
  final int scheduledToday;
  final double monthlyRevenue;
  final int paidPayments;

  factory _DashboardStats.fromSnapshots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> studentDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> courseDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attendanceDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs,
  ) {
    final students = studentDocs
        .where((doc) => doc.data()['role']?.toString() == 'student')
        .where(
          (doc) => doc.data()['status']?.toString().toLowerCase() != 'archived',
        )
        .toList();
    final activeStudentIds = students.map((doc) => doc.id).toSet();
    final activeStudents = students.length;
    final activePaymentDocs = paymentDocs
        .where((doc) => _isPaidDashboardPayment(doc.data()))
        .toList();
    final paidCourseKeys = activePaymentDocs
        .expand((doc) => _paymentMatchKeys(doc.data()))
        .where((key) => key.isNotEmpty)
        .toSet();
    final studentCourseFees = students
        .expand((doc) => _studentCourseFees(doc.id, doc.data()))
        .where((course) => course.amount > 0)
        .toList();
    final matchedPaidPaymentCount = studentCourseFees.where((course) {
      return course.matchKeys.any(paidCourseKeys.contains);
    }).length;
    final activeStudentPaymentCount = activePaymentDocs
        .where(
          (doc) => activeStudentIds.contains(
            _readString(doc.data(), 'studentId', ''),
          ),
        )
        .map(_paymentSlotKey)
        .where((key) => key.isNotEmpty)
        .toSet()
        .length;
    final strongestPaidCount = activeStudentPaymentCount > matchedPaidPaymentCount
        ? activeStudentPaymentCount
        : matchedPaidPaymentCount;
    final paidPaymentCount = strongestPaidCount > studentCourseFees.length
        ? studentCourseFees.length
        : strongestPaidCount;
    final pendingStudents = studentCourseFees.length - paidPaymentCount;
    final revenue = activePaymentDocs.fold<double>(0, (total, doc) {
      return total + _readDouble(doc.data(), 'amount');
    });
    final activeCourseDocs = courseDocs
        .where((doc) => doc.data()['status']?.toString() != 'archived')
        .toList();
    final activeCourses = activeCourseDocs.length;
    final todayCourses = activeCourseDocs
        .map(_TodayClass.fromSnapshot)
        .where((course) => course.isActive && course.isToday)
        .toList();
    final scheduledToday = todayCourses.length;
    final scheduledStudentIds = students
        .where((studentDoc) => _studentHasAnyCourseToday(
              studentId: studentDoc.id,
              studentData: studentDoc.data(),
              todayCourses: todayCourses,
            ))
        .map((studentDoc) => studentDoc.id)
        .toSet();
    final presentStudentIds = attendanceDocs
        .where(
          (doc) => doc.data()['status']?.toString().toLowerCase() == 'present',
        )
        .where(
          (doc) => _attendanceMatchesAnyCourseToday(
            doc.data(),
            todayCourses,
          ),
        )
        .map((doc) => doc.data()['studentId']?.toString() ?? '')
        .where(
          (studentId) =>
              activeStudentIds.contains(studentId) &&
              scheduledStudentIds.contains(studentId),
        )
        .toSet();

    return _DashboardStats(
      totalStudents: students.length,
      activeStudents: activeStudents,
      pendingStudents: pendingStudents,
      presentToday: presentStudentIds.length,
      attendanceBaseStudents: scheduledStudentIds.length,
      activeCourses: activeCourses,
      scheduledToday: scheduledToday,
      monthlyRevenue: revenue,
      paidPayments: paidPaymentCount,
    );
  }

  int get attendancePercent {
    if (attendanceBaseStudents == 0) {
      return 0;
    }
    return ((presentToday / attendanceBaseStudents) * 100)
        .clamp(0, 100)
        .round();
  }

  String get revenueLabel {
    return 'Rs ${monthlyRevenue.toStringAsFixed(0)}';
  }

  String get revenueTrendLabel {
    final totalPayments = paidPayments + pendingStudents;
    if (totalPayments == 0) {
      return 'No fees this month';
    }

    return '$paidPayments/$totalPayments paid';
  }
}

class _StudentCourseFee {
  const _StudentCourseFee({
    required this.studentId,
    required this.courseId,
    required this.courseName,
    required this.amount,
  });

  final String studentId;
  final String courseId;
  final String courseName;
  final double amount;

  Set<String> get matchKeys => _courseFeeMatchKeys(
        studentId: studentId,
        courseId: courseId,
        courseName: courseName,
      );

  Set<String> get courseMatchKeys => _courseOnlyMatchKeys(
        courseId: courseId,
        courseName: courseName,
      );
}

List<_StudentCourseFee> _studentCourseFees(
  String studentId,
  Map<String, dynamic> data,
) {
  final fees = <_StudentCourseFee>[];

  void addFee(_StudentCourseFee fee) {
    final keys = fee.matchKeys;
    final exists = fees.any(
      (existing) => existing.matchKeys.any(keys.contains),
    );

    if (!exists) {
      fees.add(fee);
    }
  }

  void addFromCourseMap(Map<dynamic, dynamic> rawData) {
    final courseData = <String, dynamic>{};
    rawData.forEach((key, value) {
      courseData[key.toString()] = value;
    });

    addFee(
      _StudentCourseFee(
        studentId: studentId,
        courseId: _readString(
          courseData,
          'courseId',
          _readString(courseData, 'id', ''),
        ),
        courseName: _readString(
          courseData,
          'course',
          _readString(courseData, 'name', ''),
        ),
        amount: _readFeeAmount(courseData),
      ),
    );
  }

  void addFromField(String field) {
    final value = data[field];
    if (value is! Iterable) {
      return;
    }

    for (final item in value) {
      if (item is Map) {
        addFromCourseMap(item);
      }
    }
  }

  addFromField('courses');
  addFromField('enrolledCourses');
  addFromField('studentCourses');
  if (fees.isEmpty) {
    addFee(
      _StudentCourseFee(
        studentId: studentId,
        courseId: _readString(data, 'courseId', ''),
        courseName: _readString(
          data,
          'course',
          _readString(data, 'subject', ''),
        ),
        amount: _readFeeAmount(data),
      ),
    );
  }

  return fees;
}

bool _studentHasAnyCourseToday({
  required String studentId,
  required Map<String, dynamic> studentData,
  required List<_TodayClass> todayCourses,
}) {
  if (todayCourses.isEmpty) {
    return false;
  }

  final studentCourses = _studentCourseFees(studentId, studentData);
  if (studentCourses.isEmpty) {
    return false;
  }

  return studentCourses.any((studentCourse) {
    return todayCourses.any((todayCourse) {
      return studentCourse.courseMatchKeys.any(todayCourse.matchKeys.contains);
    });
  });
}

bool _attendanceMatchesAnyCourseToday(
  Map<String, dynamic> attendanceData,
  List<_TodayClass> todayCourses,
) {
  if (todayCourses.isEmpty) {
    return false;
  }

  final attendanceCourseKeys = _courseOnlyMatchKeys(
    courseId: _readString(attendanceData, 'courseId', ''),
    courseName: _readString(
      attendanceData,
      'courseName',
      _readString(attendanceData, 'course', ''),
    ),
  );

  if (attendanceCourseKeys.isEmpty) {
    return false;
  }

  return todayCourses.any((course) {
    return attendanceCourseKeys.any(course.matchKeys.contains);
  });
}

Iterable<String> _paymentMatchKeys(Map<String, dynamic> data) {
  return _courseFeeMatchKeys(
    studentId: _readString(data, 'studentId', ''),
    courseId: _readString(data, 'courseId', ''),
    courseName: _readString(
      data,
      'courseName',
      _readString(data, 'course', ''),
    ),
  );
}

bool _isPaidDashboardPayment(Map<String, dynamic> data) {
  final status = _readString(data, 'status', 'paid').toLowerCase();
  return status != 'archived' &&
      status != 'deleted' &&
      status != 'cancelled' &&
      status != 'pending';
}

String _paymentSlotKey(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final studentId = _readString(data, 'studentId', '').trim().toLowerCase();
  if (studentId.isEmpty) {
    return '';
  }

  final courseId = _readString(data, 'courseId', '').trim().toLowerCase();
  if (courseId.isNotEmpty) {
    return '$studentId|id:$courseId';
  }

  final courseName = _readString(
    data,
    'courseName',
    _readString(data, 'course', ''),
  ).trim().toLowerCase();
  if (courseName.isNotEmpty) {
    return '$studentId|name:$courseName';
  }

  return '$studentId|doc:${doc.id.toLowerCase()}';
}

Set<String> _courseFeeMatchKeys({
  required String studentId,
  required String courseId,
  required String courseName,
}) {
  final studentKey = studentId.trim().toLowerCase();
  final courseIdKey = courseId.trim().toLowerCase();
  final courseNameKey = courseName.trim().toLowerCase();
  final keys = <String>{};

  if (studentKey.isEmpty) {
    return keys;
  }

  if (courseIdKey.isNotEmpty) {
    keys.add('$studentKey|id:$courseIdKey');
  }

  if (courseNameKey.isNotEmpty) {
    keys.add('$studentKey|name:$courseNameKey');
  }

  if (keys.isEmpty) {
    keys.add('$studentKey|any');
  }

  return keys;
}

Set<String> _courseOnlyMatchKeys({
  required String courseId,
  required String courseName,
}) {
  final courseIdKey = courseId.trim().toLowerCase();
  final courseNameKey = courseName.trim().toLowerCase();
  final keys = <String>{};

  if (courseIdKey.isNotEmpty) {
    keys.add('id:$courseIdKey');
  }

  if (courseNameKey.isNotEmpty) {
    keys.add('name:$courseNameKey');
  }

  return keys;
}

double _readFeeAmount(Map<String, dynamic> data) {
  final classFee = _readDouble(data, 'classFee');
  if (classFee > 0) {
    return classFee;
  }

  final amount = _readDouble(data, 'amount');
  if (amount > 0) {
    return amount;
  }

  return _readDouble(data, 'fee');
}

class _TodayClass {
  const _TodayClass({
    required this.id,
    required this.name,
    required this.grade,
    required this.location,
    required this.scheduleDays,
    required this.scheduleTime,
    required this.scheduleSlots,
    required this.statusValue,
  });

  final String id;
  final String name;
  final String grade;
  final String location;
  final List<String> scheduleDays;
  final String scheduleTime;
  final List<CourseScheduleSlot> scheduleSlots;
  final String statusValue;

  factory _TodayClass.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final slots = courseScheduleSlotsFromData(data);
    final scheduleDays = _readStringList(data, 'scheduleDays');
    return _TodayClass(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      location: _readString(data, 'location', ''),
      scheduleDays: scheduleDays.isNotEmpty
          ? scheduleDays
          : courseScheduleDaysFromSlots(slots),
      scheduleTime: _readString(data, 'scheduleTime', ''),
      scheduleSlots: slots,
      statusValue: _readString(data, 'status', 'active'),
    );
  }

  bool get isActive => statusValue != 'archived';

  bool get isToday => _slotForDate(DateTime.now()) != null;

  int get sortTime => _slotForDate(DateTime.now())?.range.startMinutes ?? 9999;

  DateTime? nextStartAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (var dayOffset = 0; dayOffset < 8; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final slot = _slotForDate(date);
      if (slot == null) {
        continue;
      }

      final startAt = DateTime(
        date.year,
        date.month,
        date.day,
        slot.range.startMinutes ~/ 60,
        slot.range.startMinutes % 60,
      );

      if (startAt.isAfter(now)) {
        return startAt;
      }
    }

    return null;
  }

  CourseScheduleSlot? _slotForDate(DateTime date) {
    return courseScheduleSlotForDate(
      scheduleSlots: scheduleSlots,
      scheduleDays: scheduleDays,
      scheduleTime: scheduleTime,
      date: date,
    );
  }

  String timeLabelForDate(DateTime date) {
    return _slotForDate(date)?.range.label ??
        (scheduleTime.isNotEmpty ? scheduleTime : 'Schedule time not set');
  }

  String get title => grade.isEmpty ? name : '$name $grade';

  Set<String> get matchKeys {
    return _courseOnlyMatchKeys(courseId: id, courseName: name);
  }

  String get timeAndLocation {
    final todaySlot = _slotForDate(DateTime.now());
    final parts = <String>[
      if (todaySlot != null)
        todaySlot.range.label
      else if (scheduleTime.isNotEmpty)
        scheduleTime,
      if (location.isNotEmpty) location,
    ];
    return parts.isEmpty ? 'Schedule time not set' : parts.join(' • ');
  }

  String get status {
    final todaySlot = _slotForDate(DateTime.now());
    if (todaySlot == null) {
      return 'Later';
    }

    final now = DateTime.now();
    final currentMinutes = (now.hour * 60) + now.minute;

    if (currentMinutes >= todaySlot.range.startMinutes &&
        currentMinutes <= todaySlot.range.endMinutes) {
      return 'Live';
    }
    if (currentMinutes < todaySlot.range.startMinutes) {
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

class _UpcomingClass {
  const _UpcomingClass({
    required this.course,
    required this.startAt,
  });

  final _TodayClass course;
  final DateTime startAt;
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

String _monthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
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

String _nextClassDateLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final dayDifference = target.difference(today).inDays;
  final prefix = switch (dayDifference) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => _dateKey(date),
  };

  return '$prefix - ${_fullDayName(date)}';
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
