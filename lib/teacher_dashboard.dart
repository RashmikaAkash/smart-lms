import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'scan_attendance_page.dart';
import 'students_page.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  String get _name => userData['name']?.toString().trim().isNotEmpty == true
      ? userData['name'].toString().trim()
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      greeting: _greeting,
                      name: _name,
                      initials: _initials,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _StatsGrid(),
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
                              onActionPressed: () {},
                            ),
                            const SizedBox(height: 10),
                            const _ClassList(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _BottomNavigation(),
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
  });

  final String greeting;
  final String name;
  final String initials;

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
                message: 'Logout',
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
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
            child: const Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today - Wednesday, 5 June',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Next class: Mathematics 10A - 10:00 AM',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: const [
        _StatCard(
          icon: Icons.groups_2_outlined,
          iconColor: Color(0xFF316DFF),
          iconBackground: Color(0xFFEAF0FF),
          value: '247',
          label: 'Total Students',
          trend: '+12 this month',
          trendColor: Color(0xFF00A86B),
        ),
        _StatCard(
          icon: Icons.insights_rounded,
          iconColor: Color(0xFF0FAF75),
          iconBackground: Color(0xFFE7F9F0),
          value: '89%',
          label: "Today's Attendance",
          trend: '+3% yesterday',
          trendColor: Color(0xFF00A86B),
        ),
        _StatCard(
          icon: Icons.attach_money_rounded,
          iconColor: Color(0xFFFF9500),
          iconBackground: Color(0xFFFFF3E0),
          value: 'Rs 84k',
          label: 'Monthly Revenue',
          trend: '12 pending',
          trendColor: Color(0xFFFF6B00),
        ),
        _StatCard(
          icon: Icons.menu_book_rounded,
          iconColor: Color(0xFF7048E8),
          iconBackground: Color(0xFFF0ECFF),
          value: '8',
          label: 'Active Courses',
          trend: '2 starting soon',
          trendColor: Color(0xFF00A86B),
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
        const _ActionCard(
          icon: Icons.add_rounded,
          iconColor: Color(0xFF7048E8),
          label: 'Create Course',
        ),
        const _ActionCard(
          icon: Icons.upload_rounded,
          iconColor: Color(0xFF0FAF75),
          label: 'Upload Material',
        ),
        const _ActionCard(
          icon: Icons.bar_chart_rounded,
          iconColor: Color(0xFFFF9500),
          label: 'View Reports',
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
  const _ClassList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ClassTile(
          icon: Icons.menu_book_rounded,
          iconColor: Color(0xFF316DFF),
          iconBackground: Color(0xFFEAF0FF),
          subject: 'Mathematics 10A',
          time: '10:00 AM - Room A1',
          status: 'Live',
          statusColor: Color(0xFF00A86B),
          statusBackground: Color(0xFFE7F9F0),
        ),
        SizedBox(height: 10),
        _ClassTile(
          icon: Icons.science_rounded,
          iconColor: Color(0xFF7048E8),
          iconBackground: Color(0xFFF0ECFF),
          subject: 'Physics 11',
          time: '1:00 PM - Room B2',
          status: 'Soon',
          statusColor: Color(0xFFFF9500),
          statusBackground: Color(0xFFFFF3E0),
        ),
        SizedBox(height: 10),
        _ClassTile(
          icon: Icons.biotech_rounded,
          iconColor: Color(0xFF0FAF75),
          iconBackground: Color(0xFFE7F9F0),
          subject: 'Chemistry 12',
          time: '3:30 PM - Room C3',
          status: 'Later',
          statusColor: Color(0xFF316DFF),
          statusBackground: Color(0xFFEAF0FF),
        ),
      ],
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

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

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
          const _BottomNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isActive: true,
          ),
          _BottomNavItem(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StudentsPage(),
                ),
              );
            },
          ),
          const _BottomNavItem(
            icon: Icons.menu_book_outlined,
            label: 'Courses',
            isActive: false,
          ),
          const _BottomNavItem(
            icon: Icons.credit_card_rounded,
            label: 'Payments',
            isActive: false,
          ),
          _BottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: false,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
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
