import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'student_assignment_page.dart';
import 'student_quiz_page.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key, this.userData = const {}});

  final Map<String, dynamic> userData;

  @override
  Widget build(BuildContext context) {
    final profile = _StudentDashboardProfile.fromMap(userData);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Hello ${profile.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _StudentHeroCard(profile: profile),
          const SizedBox(height: 18),
          const Text(
            'Live Classes',
            style: TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _StudentLiveClassList(profile: profile),
          const SizedBox(height: 18),
          const Text(
            'Available Quizzes',
            style: TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _StudentQuizList(profile: profile),
          const SizedBox(height: 18),
          const Text(
            'Available Assignments',
            style: TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _StudentAssignmentList(profile: profile),
        ],
      ),
    );
  }
}

class _StudentHeroCard extends StatelessWidget {
  const _StudentHeroCard({required this.profile});

  final _StudentDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D5BEA), Color(0xFF7048E8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
            child: Text(
              profile.initials,
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
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profile.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _StudentLiveClassList extends StatelessWidget {
  const _StudentLiveClassList({required this.profile});

  final _StudentDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.teacherUid.isEmpty) {
      return const _StudentMessage(
        icon: Icons.live_tv_outlined,
        title: 'No teacher linked',
        message: 'Login with a student account registered by a teacher.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_live_classes')
          .doc(profile.teacherUid)
          .collection('classes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _StudentMessage(
            icon: Icons.lock_outline_rounded,
            title: 'Could not load live classes',
            message: 'Firestore live class read rules check කරන්න.',
          );
        }

        final now = DateTime.now();
        final liveClasses = (snapshot.data?.docs ?? [])
            .map((doc) => _StudentLiveClassSummary.fromSnapshot(doc))
            .where((liveClass) => liveClass.status == 'active')
            .where(profile.matchesLiveClass)
            .where((liveClass) {
          final endAt = liveClass.endAt;
          return endAt == null ||
              endAt.isAfter(now.subtract(const Duration(minutes: 10)));
        }).toList()
          ..sort((first, second) {
            final firstDate = first.startAt ?? DateTime(9999);
            final secondDate = second.startAt ?? DateTime(9999);
            return firstDate.compareTo(secondDate);
          });

        if (liveClasses.isEmpty) {
          return const _StudentMessage(
            icon: Icons.live_tv_outlined,
            title: 'No live classes yet',
            message: 'Your course live class links will appear here.',
          );
        }

        return Column(
          children: [
            for (final liveClass in liveClasses) ...[
              _StudentLiveClassCard(liveClass: liveClass),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _StudentLiveClassCard extends StatelessWidget {
  const _StudentLiveClassCard({required this.liveClass});

  final _StudentLiveClassSummary liveClass;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = liveClass.startAt != null &&
        liveClass.endAt != null &&
        now.isAfter(liveClass.startAt!) &&
        now.isBefore(liveClass.endAt!);
    final statusLabel = isLive
        ? 'Live now'
        : liveClass.startAt != null && now.isBefore(liveClass.startAt!)
            ? 'Upcoming'
            : 'Shared';
    final statusColor = isLive
        ? const Color(0xFF00A86B)
        : statusLabel == 'Upcoming'
            ? const Color(0xFFFF9500)
            : const Color(0xFF316DFF);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFFFF3B6B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            liveClass.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF071B3C),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      liveClass.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60708F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _QuizMiniMeta(
                icon: Icons.play_circle_outline_rounded,
                label: liveClass.startLabel,
              ),
              _QuizMiniMeta(
                icon: Icons.stop_circle_outlined,
                label: liveClass.endLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  liveClass.meetingLink,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: liveClass.meetingLink),
                  );

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Live class link copied.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B6B),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentQuizList extends StatelessWidget {
  const _StudentQuizList({required this.profile});

  final _StudentDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.teacherUid.isEmpty) {
      return const _StudentMessage(
        icon: Icons.quiz_outlined,
        title: 'No teacher linked',
        message: 'Teacher register කරපු student account එකකින් login වෙන්න.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_quizzes')
          .doc(profile.teacherUid)
          .collection('quizzes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _StudentMessage(
            icon: Icons.lock_outline_rounded,
            title: 'Could not load quizzes',
            message: 'Firestore quiz read rules check කරන්න.',
          );
        }

        final quizzes = (snapshot.data?.docs ?? [])
            .map((doc) => _StudentQuizSummary.fromSnapshot(doc))
            .where((quiz) => quiz.status == 'active')
            .where(profile.matchesQuiz)
            .toList()
          ..sort((first, second) {
            final firstDate = first.createdAt ?? DateTime(0);
            final secondDate = second.createdAt ?? DateTime(0);
            return secondDate.compareTo(firstDate);
          });

        if (quizzes.isEmpty) {
          return const _StudentMessage(
            icon: Icons.quiz_outlined,
            title: 'No quizzes yet',
            message: 'ඔබගේ courses වලට active quizzes නැහැ.',
          );
        }

        return Column(
          children: [
            for (final quiz in quizzes) ...[
              _StudentQuizCard(
                quiz: quiz,
                teacherUid: profile.teacherUid,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _StudentQuizCard extends StatelessWidget {
  const _StudentQuizCard({
    required this.quiz,
    required this.teacherUid,
  });

  final _StudentQuizSummary quiz;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentQuizPage(
                teacherUid: teacherUid,
                quizId: quiz.id,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE5F4)),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Color(0xFF316DFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60708F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _QuizMiniMeta(
                          icon: Icons.timer_outlined,
                          label: '${quiz.timeLimitMinutes} min',
                        ),
                        _QuizMiniMeta(
                          icon: Icons.grade_outlined,
                          label: quiz.marksLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B97AD),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentAssignmentList extends StatelessWidget {
  const _StudentAssignmentList({required this.profile});

  final _StudentDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.teacherUid.isEmpty) {
      return const _StudentMessage(
        icon: Icons.assignment_outlined,
        title: 'No teacher linked',
        message: 'Teacher register කරපු student account එකකින් login වෙන්න.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teacher_assignments')
          .doc(profile.teacherUid)
          .collection('assignments')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _StudentMessage(
            icon: Icons.lock_outline_rounded,
            title: 'Could not load assignments',
            message: 'Firestore assignment read rules check කරන්න.',
          );
        }

        final assignments = (snapshot.data?.docs ?? [])
            .map((doc) => _StudentAssignmentSummary.fromSnapshot(doc))
            .where((assignment) => assignment.status == 'active')
            .where(profile.matchesAssignment)
            .toList()
          ..sort((first, second) {
            final firstDate = first.deadline ?? DateTime(9999);
            final secondDate = second.deadline ?? DateTime(9999);
            return firstDate.compareTo(secondDate);
          });

        if (assignments.isEmpty) {
          return const _StudentMessage(
            icon: Icons.assignment_outlined,
            title: 'No assignments yet',
            message: 'ඔබගේ courses වලට active assignments නැහැ.',
          );
        }

        return Column(
          children: [
            for (final assignment in assignments) ...[
              _StudentAssignmentCard(
                assignment: assignment,
                teacherUid: profile.teacherUid,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _StudentAssignmentCard extends StatelessWidget {
  const _StudentAssignmentCard({
    required this.assignment,
    required this.teacherUid,
  });

  final _StudentAssignmentSummary assignment;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    final isPastDeadline = assignment.deadline != null &&
        DateTime.now().isAfter(assignment.deadline!);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentAssignmentPage(
                teacherUid: teacherUid,
                assignmentId: assignment.id,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE5F4)),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignment.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60708F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _QuizMiniMeta(
                          icon: Icons.event_available_rounded,
                          label: assignment.deadlineLabel,
                        ),
                        _QuizMiniMeta(
                          icon: Icons.grade_outlined,
                          label: assignment.marksLabel,
                        ),
                        if (isPastDeadline)
                          const _QuizMiniMeta(
                            icon: Icons.warning_amber_rounded,
                            label: 'Late',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B97AD),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizMiniMeta extends StatelessWidget {
  const _QuizMiniMeta({required this.icon, required this.label});

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

class _StudentMessage extends StatelessWidget {
  const _StudentMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8C98AF), size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF60708F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDashboardProfile {
  const _StudentDashboardProfile({
    required this.name,
    required this.email,
    required this.teacherUid,
    required this.courseIds,
    required this.courseNames,
    required this.grade,
  });

  final String name;
  final String email;
  final String teacherUid;
  final Set<String> courseIds;
  final Set<String> courseNames;
  final String grade;

  factory _StudentDashboardProfile.fromMap(Map<String, dynamic> data) {
    final courseIds = <String>{};
    final courseNames = <String>{};

    void addCourseId(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        courseIds.add(normalized);
      }
    }

    void addCourseName(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        courseNames.add(normalized);
      }
    }

    final rawCourseIds = data['courseIds'];
    if (rawCourseIds is Iterable) {
      for (final id in rawCourseIds) {
        addCourseId(id.toString());
      }
    }

    void addCoursesFromField(String field) {
      final value = data[field];
      if (value is! Iterable) {
        return;
      }

      for (final item in value) {
        if (item is! Map) {
          continue;
        }

        final courseData = <String, dynamic>{};
        item.forEach((key, value) {
          courseData[key.toString()] = value;
        });

        addCourseId(_readString(courseData, 'courseId', ''));
        addCourseId(_readString(courseData, 'id', ''));
        addCourseName(
          _readString(
            courseData,
            'course',
            _readString(courseData, 'name', ''),
          ),
        );
      }
    }

    addCoursesFromField('courses');
    addCoursesFromField('enrolledCourses');
    addCoursesFromField('studentCourses');
    addCourseId(_readString(data, 'courseId', ''));
    addCourseName(
        _readString(data, 'course', _readString(data, 'subject', '')));

    return _StudentDashboardProfile(
      name: _readString(data, 'name', 'Student'),
      email: _readString(data, 'email', ''),
      teacherUid:
          _readString(data, 'createdBy', _readString(data, 'teacherUid', '')),
      courseIds: courseIds,
      courseNames: courseNames,
      grade: _readString(data, 'grade', ''),
    );
  }

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  String get subtitle {
    final details = <String>[
      if (grade.isNotEmpty) grade,
      if (courseNames.isNotEmpty) courseNames.join(', '),
      if (email.isNotEmpty) email,
    ];

    return details.isEmpty ? 'Student' : details.join(' • ');
  }

  bool matchesQuiz(_StudentQuizSummary quiz) {
    final quizCourseId = quiz.courseId.trim().toLowerCase();
    final quizCourseName = quiz.courseName.trim().toLowerCase();

    if (courseIds.isEmpty && courseNames.isEmpty) {
      return false;
    }

    return (quizCourseId.isNotEmpty && courseIds.contains(quizCourseId)) ||
        (quizCourseName.isNotEmpty && courseNames.contains(quizCourseName));
  }

  bool matchesAssignment(_StudentAssignmentSummary assignment) {
    final assignmentCourseId = assignment.courseId.trim().toLowerCase();
    final assignmentCourseName = assignment.courseName.trim().toLowerCase();

    if (courseIds.isEmpty && courseNames.isEmpty) {
      return false;
    }

    return (assignmentCourseId.isNotEmpty &&
            courseIds.contains(assignmentCourseId)) ||
        (assignmentCourseName.isNotEmpty &&
            courseNames.contains(assignmentCourseName));
  }

  bool matchesLiveClass(_StudentLiveClassSummary liveClass) {
    final liveCourseId = liveClass.courseId.trim().toLowerCase();
    final liveCourseName = liveClass.courseName.trim().toLowerCase();

    if (courseIds.isEmpty && courseNames.isEmpty) {
      return false;
    }

    return (liveCourseId.isNotEmpty && courseIds.contains(liveCourseId)) ||
        (liveCourseName.isNotEmpty && courseNames.contains(liveCourseName));
  }
}

class _StudentLiveClassSummary {
  const _StudentLiveClassSummary({
    required this.id,
    required this.title,
    required this.meetingLink,
    required this.courseId,
    required this.courseName,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final String id;
  final String title;
  final String meetingLink;
  final String courseId;
  final String courseName;
  final DateTime? startAt;
  final DateTime? endAt;
  final String status;

  factory _StudentLiveClassSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final startAt = data['startAt'];
    final endAt = data['endAt'];

    return _StudentLiveClassSummary(
      id: snapshot.id,
      title: _readString(data, 'title', 'Live Class'),
      meetingLink: _readString(data, 'meetingLink', ''),
      courseId: _readString(data, 'courseId', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      startAt: startAt is Timestamp ? startAt.toDate() : null,
      endAt: endAt is Timestamp ? endAt.toDate() : null,
      status: _readString(data, 'status', 'active'),
    );
  }

  String get startLabel =>
      startAt == null ? 'Start time not set' : _studentDateTimeLabel(startAt!);

  String get endLabel =>
      endAt == null ? 'End time not set' : _studentDateTimeLabel(endAt!);
}

class _StudentQuizSummary {
  const _StudentQuizSummary({
    required this.id,
    required this.title,
    required this.lesson,
    required this.courseId,
    required this.courseName,
    required this.timeLimitMinutes,
    required this.totalMarks,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String lesson;
  final String courseId;
  final String courseName;
  final int timeLimitMinutes;
  final double totalMarks;
  final String status;
  final DateTime? createdAt;

  factory _StudentQuizSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];

    return _StudentQuizSummary(
      id: snapshot.id,
      title: _readString(data, 'title', 'Quiz'),
      lesson: _readString(data, 'lesson', ''),
      courseId: _readString(data, 'courseId', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      timeLimitMinutes: _readInt(data, 'timeLimitMinutes', 30),
      totalMarks: _readDouble(data, 'totalMarks'),
      status: _readString(data, 'status', 'active'),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  String get subtitle {
    final parts = <String>[
      courseName,
      if (lesson.isNotEmpty) lesson,
    ];

    return parts.join(' • ');
  }

  String get marksLabel {
    final hasCents = totalMarks.truncateToDouble() != totalMarks;
    return '${totalMarks.toStringAsFixed(hasCents ? 1 : 0)} marks';
  }
}

class _StudentAssignmentSummary {
  const _StudentAssignmentSummary({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.deadline,
    required this.maxMarks,
    required this.status,
  });

  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final DateTime? deadline;
  final double maxMarks;
  final String status;

  factory _StudentAssignmentSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final deadline = data['deadline'];

    return _StudentAssignmentSummary(
      id: snapshot.id,
      title: _readString(data, 'title', 'Assignment'),
      courseId: _readString(data, 'courseId', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      deadline: deadline is Timestamp ? deadline.toDate() : null,
      maxMarks: _readDouble(data, 'maxMarks'),
      status: _readString(data, 'status', 'active'),
    );
  }

  String get subtitle => courseName;

  String get deadlineLabel {
    final date = deadline;
    if (date == null) {
      return 'No deadline';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$month/$day';
  }

  String get marksLabel {
    final hasCents = maxMarks.truncateToDouble() != maxMarks;
    return '${maxMarks.toStringAsFixed(hasCents ? 1 : 0)} marks';
  }
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

int _readInt(Map<String, dynamic> data, String key, int fallback) {
  final value = data[key];
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _studentDateTimeLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$month/$day $hour:$minute $period';
}
