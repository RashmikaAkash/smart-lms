import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'course_schedule_utils.dart';
import 'create_assignment_page.dart';
import 'create_course_sheet.dart';
import 'create_quiz_page.dart';
import 'student_detail_page.dart';
import 'student_qr.dart';
import 'upload_material_sheet.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({
    super.key,
    this.showBackButton = true,
  });

  final bool showBackButton;

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _coursesStream {
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

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _studentsStream {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('createdBy', isEqualTo: teacher.uid)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  void _openCreateCourseSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateCourseSheet(),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              const Text(
                'Filter Courses',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _FilterTile(
                label: 'All courses',
                isSelected: _typeFilter == 'all',
                onTap: () => _selectFilter('all'),
              ),
              _FilterTile(
                label: 'Group classes',
                isSelected: _typeFilter == 'group',
                onTap: () => _selectFilter('group'),
              ),
              _FilterTile(
                label: 'Individual classes',
                isSelected: _typeFilter == 'individual',
                onTap: () => _selectFilter('individual'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectFilter(String value) {
    setState(() {
      _typeFilter = value;
    });
    Navigator.of(context).pop();
  }

  List<_CourseData> _filterCourses(List<_CourseData> courses) {
    final query = _searchController.text.trim().toLowerCase();

    return courses.where((course) {
      final matchesQuery = query.isEmpty ||
          course.name.toLowerCase().contains(query) ||
          course.grade.toLowerCase().contains(query) ||
          course.location.toLowerCase().contains(query) ||
          course.scheduleLabel.toLowerCase().contains(query);
      final matchesType = _typeFilter == 'all' || course.type == _typeFilter;

      return matchesQuery && matchesType;
    }).toList();
  }

  Map<String, int> _studentCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{};

    for (final doc in docs) {
      final data = doc.data();
      if ((data['role']?.toString() ?? '') != 'student') {
        continue;
      }
      if ((data['status']?.toString().toLowerCase() ?? '') == 'archived') {
        continue;
      }

      final student = _CourseStudentData.fromSnapshot(doc);
      for (final courseId in student.courseIds) {
        counts[courseId] = (counts[courseId] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final coursesStream = _coursesStream;
    final studentsStream = _studentsStream;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: Column(
        children: [
          _CoursesTopBar(
            showBackButton: widget.showBackButton,
            onAddPressed: _openCreateCourseSheet,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: _CourseSearchBox(controller: _searchController),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  isActive: _typeFilter != 'all',
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (coursesStream == null || studentsStream == null) {
                  return const _CourseMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Teacher login needed',
                    message: 'Courses බලන්න teacher account එකෙන් login වෙන්න.',
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: coursesStream,
                  builder: (context, courseSnapshot) {
                    if (courseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (courseSnapshot.hasError) {
                      return const _CourseMessage(
                        icon: Icons.lock_outline_rounded,
                        title: 'Courses load කරන්න බැහැ',
                        message: 'Firestore course rules check කරන්න.',
                      );
                    }

                    final courses = (courseSnapshot.data?.docs ?? [])
                        .map(_CourseData.fromSnapshot)
                        .where((course) => course.status != 'archived')
                        .toList()
                      ..sort(
                          (first, second) => first.name.compareTo(second.name));
                    final filteredCourses = _filterCourses(courses);

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: studentsStream,
                      builder: (context, studentSnapshot) {
                        final studentCounts = _studentCounts(
                          studentSnapshot.data?.docs ?? [],
                        );

                        if (filteredCourses.isEmpty) {
                          return _CourseMessage(
                            icon: Icons.menu_book_outlined,
                            title: courses.isEmpty
                                ? 'තවම courses නැහැ'
                                : 'Course එකක් හමු උනේ නැහැ',
                            message: courses.isEmpty
                                ? '+ button එකෙන් පළවෙනි course එක create කරන්න.'
                                : 'Search text හෝ filter එක වෙනස් කරන්න.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: filteredCourses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final course = filteredCourses[index];
                            return _CourseCard(
                              course: course,
                              studentCount: studentCounts[course.id] ?? 0,
                              colorScheme: _CourseColorScheme.byIndex(index),
                              onOpen: () => _showScheduleSheet(
                                course,
                                studentCounts[course.id] ?? 0,
                              ),
                            );
                          },
                        );
                      },
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

  void _showScheduleSheet(_CourseData course, int studentCount) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ScheduleEditorSheet(
          course: course,
          studentCount: studentCount,
        );
      },
    );
  }
}

class _CoursesTopBar extends StatelessWidget {
  const _CoursesTopBar({
    required this.showBackButton,
    required this.onAddPressed,
  });

  final bool showBackButton;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE4EAF4)),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF0D1B38),
            )
          else
            const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'My Courses',
              style: TextStyle(
                color: Color(0xFF081A36),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Create course',
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            color: const Color(0xFF316DFF),
          ),
        ],
      ),
    );
  }
}

class _CourseSearchBox extends StatelessWidget {
  const _CourseSearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search courses...',
        hintStyle: const TextStyle(
          color: Color(0xFF8A96AD),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF7C8AA6),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4F1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF316DFF), width: 1.4),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFFEAF0FF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isActive ? const Color(0xFF316DFF) : const Color(0xFFDCE4F1),
            ),
          ),
          child: const Icon(
            Icons.filter_alt_outlined,
            color: Color(0xFF316DFF),
          ),
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF316DFF))
          : null,
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.studentCount,
    required this.colorScheme,
    required this.onOpen,
  });

  final _CourseData course;
  final int studentCount;
  final _CourseColorScheme colorScheme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = course.progressFor(studentCount);
    final percentage = (progress * 100).round();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE5F4)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                Container(
                  height: 88,
                  color: colorScheme.headerColor,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.blur_on_rounded,
                        color: colorScheme.accentColor.withOpacity(0.55),
                        size: 34,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _CourseMeta(
                            icon: Icons.group_outlined,
                            label: '$studentCount students',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CourseMeta(
                              icon: Icons.calendar_month_outlined,
                              label: course.scheduleLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              color: Color(0xFF697992),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$percentage%',
                            style: const TextStyle(
                              color: Color(0xFF697992),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: progress,
                                color: colorScheme.accentColor,
                                backgroundColor: const Color(0xFFE5EAF2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: colorScheme.accentColor,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onOpen,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Open',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({
    required this.course,
    required this.studentCount,
  });

  final _CourseData course;
  final int studentCount;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final Map<String, TextEditingController> _startTimeControllers = {};
  final Map<String, TextEditingController> _endTimeControllers = {};
  final Set<String> _selectedDays = <String>{};
  late String _courseType;

  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.course.name;
    _gradeController.text = widget.course.grade;
    _feeController.text = widget.course.classFee == 0
        ? '0'
        : widget.course.classFee.toStringAsFixed(
            widget.course.classFee.truncateToDouble() == widget.course.classFee
                ? 0
                : 2,
          );
    _locationController.text = widget.course.location;
    _courseType = widget.course.type == 'individual' ? 'individual' : 'group';
    _selectedDays.addAll(widget.course.scheduleDays);
    final slots = widget.course.scheduleSlots;
    for (final day in widget.course.scheduleDays) {
      CourseScheduleSlot? matchingSlot;
      for (final slot in slots) {
        if (slot.day.toLowerCase() == day.toLowerCase()) {
          matchingSlot = slot;
          break;
        }
      }
      _startControllerFor(day);
      _endControllerFor(day);
      if (matchingSlot != null) {
        _startControllerFor(day).text =
            formatCourseScheduleMinutes(matchingSlot.range.startMinutes);
        _endControllerFor(day).text =
            formatCourseScheduleMinutes(matchingSlot.range.endMinutes);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _feeController.dispose();
    _locationController.dispose();
    for (final controller in _startTimeControllers.values) {
      controller.dispose();
    }
    for (final controller in _endTimeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _startControllerFor(String day) {
    return _startTimeControllers.putIfAbsent(
      day,
      TextEditingController.new,
    );
  }

  TextEditingController _endControllerFor(String day) {
    return _endTimeControllers.putIfAbsent(
      day,
      TextEditingController.new,
    );
  }

  void _removeDayControllers(String day) {
    _startTimeControllers.remove(day)?.dispose();
    _endTimeControllers.remove(day)?.dispose();
  }

  Future<void> _pickTime(String day, {required bool isStart}) async {
    final controller =
        isStart ? _startControllerFor(day) : _endControllerFor(day);
    final initialMinutes =
        parseSingleCourseTime(controller.text) ?? (isStart ? 9 * 60 : 10 * 60);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialMinutes ~/ 60,
        minute: initialMinutes % 60,
      ),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final selectedMinutes = (selectedTime.hour * 60) + selectedTime.minute;
    setState(() {
      controller.text = formatCourseScheduleMinutes(selectedMinutes);
      if (isStart) {
        final endController = _endControllerFor(day);
        final endMinutes = parseSingleCourseTime(endController.text);
        if (endMinutes == null || endMinutes <= selectedMinutes) {
          endController.text =
              formatCourseScheduleMinutes(selectedMinutes + 90);
        }
      }
    });
  }

  void _clearScheduleTime(String day) {
    setState(() {
      _startControllerFor(day).clear();
      _endControllerFor(day).clear();
      _errorMessage = null;
    });
  }

  Future<void> _saveCourse() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final teacher = FirebaseAuth.instance.currentUser;
      if (teacher == null) {
        throw StateError('Teacher is not signed in.');
      }

      final orderedDays =
          _days.where((day) => _selectedDays.contains(day)).toList();
      final scheduleSlots = _buildScheduleSlots(orderedDays);
      final scheduleTime = courseScheduleTimeFromSlots(scheduleSlots);
      final scheduleLabel = courseScheduleLabel(
        scheduleDays: orderedDays,
        scheduleTime: scheduleTime,
        scheduleSlots: scheduleSlots,
      );
      final updatedCourse = widget.course.copyWith(
        name: _nameController.text.trim(),
        grade: _gradeController.text.trim(),
        classFee: double.parse(_feeController.text.trim().replaceAll(',', '')),
        type: _courseType,
        location: _locationController.text.trim(),
        scheduleDays: orderedDays,
        scheduleTime: scheduleTime,
        scheduleSlots: scheduleSlots,
      );

      final conflict = await findCourseScheduleConflict(
        teacherUid: teacher.uid,
        scheduleSlots: scheduleSlots,
        currentCourseId: widget.course.id,
      );

      if (conflict != null) {
        setState(() {
          _errorMessage = conflict.message;
        });
        return;
      }

      final courseReference = FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacher.uid)
          .collection('courses')
          .doc(widget.course.id);

      await courseReference.update({
        'name': updatedCourse.name,
        'grade': updatedCourse.grade,
        'classFee': updatedCourse.classFee,
        'type': updatedCourse.type,
        'location': updatedCourse.location,
        'scheduleDays': updatedCourse.scheduleDays,
        'scheduleTime': updatedCourse.scheduleTime,
        'scheduleSlots': scheduleSlots.map((slot) => slot.toMap()).toList(),
        'scheduleLabel': scheduleLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _syncStudentsAfterCourseUpdate(
        teacherUid: teacher.uid,
        oldCourse: widget.course,
        updatedCourse: updatedCourse,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updatedCourse.title} course updated.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore permission denied. Course update rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Course update කරන්න බැරි උනා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteCourse() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete course?'),
          content: Text(
            '${widget.course.title} course එක hide වෙනවා. Registered studentsගෙන් මේ course enrollment එක remove වෙනවා.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteCourse();
    }
  }

  Future<void> _deleteCourse() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final teacher = FirebaseAuth.instance.currentUser;
      if (teacher == null) {
        throw StateError('Teacher is not signed in.');
      }

      await FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacher.uid)
          .collection('courses')
          .doc(widget.course.id)
          .update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _syncStudentsAfterCourseArchive(
        teacherUid: teacher.uid,
        archivedCourse: widget.course,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.course.title} course deleted.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore permission denied. Course update rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Course delete කරන්න බැරි උනා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  List<CourseScheduleSlot> _buildScheduleSlots(List<String> orderedDays) {
    final slots = <CourseScheduleSlot>[];

    for (final day in orderedDays) {
      final timeRange = buildCourseScheduleTimeRange(
        startTime: _startControllerFor(day).text,
        endTime: _endControllerFor(day).text,
      );
      final range = parseCourseScheduleRange(timeRange);
      if (range != null) {
        slots.add(CourseScheduleSlot(day: day, range: range));
      }
    }

    return slots;
  }

  String? _validateStartTime(String day, String? value) {
    final start = (value ?? '').trim();
    final end = _endControllerFor(day).text.trim();
    if (start.isEmpty && end.isEmpty) {
      return null;
    }
    if (start.isEmpty) {
      return 'Start time දාන්න.';
    }
    return _validateScheduleRange(day);
  }

  String? _validateEndTime(String day, String? value) {
    final start = _startControllerFor(day).text.trim();
    final end = (value ?? '').trim();
    if (start.isEmpty && end.isEmpty) {
      return null;
    }
    if (end.isEmpty) {
      return 'End time දාන්න.';
    }
    return _validateScheduleRange(day);
  }

  String? _validateScheduleRange(String day) {
    final start = parseSingleCourseTime(_startControllerFor(day).text);
    final end = parseSingleCourseTime(_endControllerFor(day).text);
    if (start == null || end == null) {
      return null;
    }
    if (end <= start) {
      return 'End time එක start time එකට පස්සේ වෙන්න ඕන.';
    }
    return null;
  }

  String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _validateFee(String? value) {
    final fee = double.tryParse((value ?? '').trim().replaceAll(',', ''));
    if (fee == null || fee < 0) {
      return 'Valid class fee එකක් දාන්න.';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
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

  String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  double _readDouble(
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

  Future<void> _syncStudentsAfterCourseUpdate({
    required String teacherUid,
    required _CourseData oldCourse,
    required _CourseData updatedCourse,
  }) async {
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('createdBy', isEqualTo: teacherUid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    var writeCount = 0;

    for (final studentDoc in studentsSnapshot.docs) {
      final data = studentDoc.data();
      if (!_shouldSyncStudent(data) || !_studentHasCourse(data, oldCourse)) {
        continue;
      }

      final updatedCourseMap = updatedCourse.toStudentCourseMap();
      final courses = _studentCourseMaps(data);
      final updatedCourses = <Map<String, dynamic>>[];
      var insertedUpdatedCourse = false;

      for (final courseMap in courses) {
        final isOldCourse = _courseMapMatchesCourse(courseMap, oldCourse);
        final isUpdatedCourse =
            _courseMapMatchesCourse(courseMap, updatedCourse);

        if (isOldCourse || isUpdatedCourse) {
          if (!insertedUpdatedCourse) {
            updatedCourses.add(updatedCourseMap);
            insertedUpdatedCourse = true;
          }
          continue;
        }

        updatedCourses.add(courseMap);
      }

      if (!insertedUpdatedCourse) {
        updatedCourses.insert(0, updatedCourseMap);
      }

      final dedupedCourses = _dedupeCourseMaps(updatedCourses);
      final updateData = <String, dynamic>{
        'courseIds': _courseIdsFromMaps(dedupedCourses),
        'courses': dedupedCourses,
        'enrolledCourses': dedupedCourses,
        'totalClassFee': _totalClassFeeFromMaps(dedupedCourses),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_primaryCourseMatches(data, oldCourse)) {
        updateData.addAll(
          _primaryCourseUpdate(
            studentId: studentDoc.id,
            teacherUid: teacherUid,
            studentData: data,
            courseMap: updatedCourseMap,
          ),
        );
      }

      batch.set(studentDoc.reference, updateData, SetOptions(merge: true));
      writeCount++;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _syncStudentsAfterCourseArchive({
    required String teacherUid,
    required _CourseData archivedCourse,
  }) async {
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('createdBy', isEqualTo: teacherUid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    var writeCount = 0;

    for (final studentDoc in studentsSnapshot.docs) {
      final data = studentDoc.data();
      if (!_shouldSyncStudent(data) ||
          !_studentHasCourse(data, archivedCourse)) {
        continue;
      }

      final remainingCourses = _dedupeCourseMaps(
        _studentCourseMaps(data)
            .where(
              (courseMap) =>
                  !_courseMapMatchesCourse(courseMap, archivedCourse),
            )
            .toList(),
      );
      final updateData = <String, dynamic>{
        'courseIds': _courseIdsFromMaps(remainingCourses),
        'courses': remainingCourses,
        'enrolledCourses': remainingCourses,
        'totalClassFee': _totalClassFeeFromMaps(remainingCourses),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_primaryCourseMatches(data, archivedCourse)) {
        final nextPrimary =
            remainingCourses.isEmpty ? null : remainingCourses.first;
        updateData.addAll(
          _primaryCourseUpdate(
            studentId: studentDoc.id,
            teacherUid: teacherUid,
            studentData: data,
            courseMap: nextPrimary,
          ),
        );
      }

      batch.set(studentDoc.reference, updateData, SetOptions(merge: true));
      writeCount++;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  bool _shouldSyncStudent(Map<String, dynamic> data) {
    return data['role']?.toString() == 'student' &&
        data['status']?.toString().toLowerCase() != 'archived';
  }

  bool _studentHasCourse(Map<String, dynamic> data, _CourseData course) {
    if (_primaryCourseMatches(data, course)) {
      return true;
    }

    final courseIds = _readStringList(data, 'courseIds').toSet();
    if (course.id.isNotEmpty && courseIds.contains(course.id)) {
      return true;
    }

    return _studentCourseMaps(data).any(
      (courseMap) => _courseMapMatchesCourse(courseMap, course),
    );
  }

  bool _primaryCourseMatches(Map<String, dynamic> data, _CourseData course) {
    final primaryCourseId = _readString(data, 'courseId', '');
    final primaryCourseName =
        _readString(data, 'course', _readString(data, 'subject', ''));
    final primaryGrade = _readString(data, 'grade', '');

    if (course.id.isNotEmpty && primaryCourseId == course.id) {
      return true;
    }

    return primaryCourseName.toLowerCase() == course.name.toLowerCase() &&
        (primaryGrade.isEmpty ||
            course.grade.isEmpty ||
            primaryGrade.toLowerCase() == course.grade.toLowerCase());
  }

  List<Map<String, dynamic>> _studentCourseMaps(Map<String, dynamic> data) {
    final maps = <Map<String, dynamic>>[];

    void addCourseMap(Object? value) {
      if (value is! Map) {
        return;
      }

      final courseMap = <String, dynamic>{};
      value.forEach((key, value) {
        courseMap[key.toString()] = value;
      });

      final name = _readString(
        courseMap,
        'name',
        _readString(courseMap, 'course', ''),
      );
      final id = _readString(
        courseMap,
        'courseId',
        _readString(courseMap, 'id', ''),
      );
      if (id.isNotEmpty || name.isNotEmpty) {
        maps.add(_normalizedStudentCourseMap(courseMap));
      }
    }

    for (final field in ['courses', 'enrolledCourses', 'studentCourses']) {
      final value = data[field];
      if (value is Iterable) {
        for (final item in value) {
          addCourseMap(item);
        }
      }
    }

    final primaryMap = _primaryCourseMap(data);
    if (primaryMap != null) {
      maps.add(primaryMap);
    }

    return _dedupeCourseMaps(maps);
  }

  Map<String, dynamic>? _primaryCourseMap(Map<String, dynamic> data) {
    final name = _readString(
      data,
      'course',
      _readString(data, 'subject', ''),
    );
    final id = _readString(data, 'courseId', '');
    if (id.isEmpty && name.isEmpty) {
      return null;
    }

    return {
      'id': id,
      'courseId': id,
      'name': name,
      'course': name,
      'grade': _readString(data, 'grade', ''),
      'classId': _readString(data, 'classId', buildStudentClassId(name)),
      'classFee': _readDouble(data, 'classFee'),
      'type': _readString(data, 'classType', 'group'),
      'classType': _readString(data, 'classType', 'group'),
      'location': _readString(data, 'location', ''),
      'status': 'active',
    };
  }

  Map<String, dynamic> _normalizedStudentCourseMap(
    Map<String, dynamic> rawData,
  ) {
    final id = _readString(
      rawData,
      'courseId',
      _readString(rawData, 'id', ''),
    );
    final name = _readString(
      rawData,
      'name',
      _readString(rawData, 'course', ''),
    );
    final type = _readString(
      rawData,
      'classType',
      _readString(rawData, 'type', 'group'),
    );

    return {
      'id': id,
      'courseId': id,
      'name': name,
      'course': name,
      'grade': _readString(rawData, 'grade', ''),
      'classId': _readString(rawData, 'classId', buildStudentClassId(name)),
      'classFee': _readDouble(rawData, 'classFee', _readDouble(rawData, 'fee')),
      'type': type,
      'classType': type,
      'location': _readString(rawData, 'location', ''),
      'status': _readString(rawData, 'status', 'active'),
    };
  }

  bool _courseMapMatchesCourse(
    Map<String, dynamic> courseMap,
    _CourseData course,
  ) {
    final mapId = _readString(
      courseMap,
      'courseId',
      _readString(courseMap, 'id', ''),
    );
    final mapName = _readString(
      courseMap,
      'name',
      _readString(courseMap, 'course', ''),
    );
    final mapGrade = _readString(courseMap, 'grade', '');

    if (course.id.isNotEmpty && mapId == course.id) {
      return true;
    }

    return mapName.toLowerCase() == course.name.toLowerCase() &&
        (mapGrade.isEmpty ||
            course.grade.isEmpty ||
            mapGrade.toLowerCase() == course.grade.toLowerCase());
  }

  List<Map<String, dynamic>> _dedupeCourseMaps(
    List<Map<String, dynamic>> courses,
  ) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final courseMap in courses) {
      final id = _readString(
        courseMap,
        'courseId',
        _readString(courseMap, 'id', ''),
      );
      final name = _readString(
        courseMap,
        'name',
        _readString(courseMap, 'course', ''),
      );
      final grade = _readString(courseMap, 'grade', '');
      final key = id.isNotEmpty
          ? 'id:$id'
          : 'name:${name.toLowerCase()}|${grade.toLowerCase()}';

      if (key == 'name:|' || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      deduped.add(courseMap);
    }

    return deduped;
  }

  List<String> _courseIdsFromMaps(List<Map<String, dynamic>> courses) {
    return courses
        .map(
          (courseMap) => _readString(
            courseMap,
            'courseId',
            _readString(courseMap, 'id', ''),
          ),
        )
        .where((courseId) => courseId.isNotEmpty)
        .toSet()
        .toList();
  }

  double _totalClassFeeFromMaps(List<Map<String, dynamic>> courses) {
    return courses.fold<double>(0, (total, courseMap) {
      return total +
          _readDouble(courseMap, 'classFee', _readDouble(courseMap, 'fee'));
    });
  }

  Map<String, dynamic> _primaryCourseUpdate({
    required String studentId,
    required String teacherUid,
    required Map<String, dynamic> studentData,
    required Map<String, dynamic>? courseMap,
  }) {
    final name = _readString(studentData, 'name', 'Student');
    final email = _readString(studentData, 'email', '');
    final studentMobile = _readString(
      studentData,
      'studentMobile',
      _readString(studentData, 'studentPhone', ''),
    );
    final parentMobile = _readString(
      studentData,
      'parentMobile',
      _readString(studentData, 'parentPhone', ''),
    );
    final address = _readString(studentData, 'address', '');
    final school = _readString(studentData, 'school', '');
    final courseName = courseMap == null
        ? ''
        : _readString(
            courseMap,
            'name',
            _readString(courseMap, 'course', ''),
          );
    final courseId = courseMap == null
        ? ''
        : _readString(
            courseMap,
            'courseId',
            _readString(courseMap, 'id', ''),
          );
    final grade = courseMap == null ? '' : _readString(courseMap, 'grade', '');
    final classFee =
        courseMap == null ? 0.0 : _readDouble(courseMap, 'classFee');
    final classType = courseMap == null
        ? ''
        : _readString(
            courseMap,
            'classType',
            _readString(courseMap, 'type', ''),
          );
    final location =
        courseMap == null ? '' : _readString(courseMap, 'location', '');

    return {
      'grade': grade,
      'courseId': courseId,
      'course': courseName,
      'subject': courseName,
      'classId': buildStudentClassId(courseName),
      'classFee': classFee,
      'classType': classType,
      'location': location,
      'qrPayload': buildStudentQrPayload(
        studentId: studentId,
        name: name,
        email: email,
        grade: grade,
        course: courseName,
        teacherUid: teacherUid,
        courseId: courseId,
        classFee: classFee,
        classType: classType,
        location: location,
        studentMobile: studentMobile,
        parentMobile: parentMobile,
        address: address,
        school: school,
      ),
    };
  }

  void _openMaterialUploadSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadMaterialSheet(
        initialCourseId: widget.course.id,
        initialCourseName: widget.course.name,
        initialCourseGrade: widget.course.grade,
        lockCourse: true,
      ),
    );
  }

  void _openQuizCreator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateQuizPage(
          initialCourseId: widget.course.id,
          initialCourseName: widget.course.name,
          initialCourseGrade: widget.course.grade,
          lockCourse: true,
        ),
      ),
    );
  }

  void _openAssignmentCreator() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAssignmentPage(
          initialCourseId: widget.course.id,
          initialCourseName: widget.course.name,
          initialCourseGrade: widget.course.grade,
          lockCourse: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                Text(
                  widget.course.title,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Course details, fee, location, type සහ class schedule edit කරන්න.',
                  style: TextStyle(
                    color: Color(0xFF66748F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Course name'),
                  decoration: _inputDecoration(
                    label: 'Course name',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gradeController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Grade'),
                  decoration: _inputDecoration(
                    label: 'Grade',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _feeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateFee,
                  decoration: _inputDecoration(
                    label: 'Class fee',
                    icon: Icons.payments_outlined,
                    prefixText: 'Rs ',
                  ),
                ),
                const SizedBox(height: 12),
                _CourseTypeSelector(
                  selectedType: _courseType,
                  onChanged: (type) {
                    setState(() {
                      _courseType = type;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Location'),
                  decoration: _inputDecoration(
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                _CourseDetailRow(
                  label: 'Students',
                  value: '${widget.studentCount}',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Class Days',
                  style: TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in _days)
                      _DayChip(
                        label: day,
                        isSelected: _selectedDays.contains(day),
                        onTap: () {
                          setState(() {
                            if (_selectedDays.contains(day)) {
                              _selectedDays.remove(day);
                              _removeDayControllers(day);
                            } else {
                              _selectedDays.add(day);
                              _startControllerFor(day);
                              _endControllerFor(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_selectedDays.isEmpty)
                  const Text(
                    'Class days select කළාම ඒ ඒ දවසට වෙනම time දාන්න පුළුවන්.',
                    style: TextStyle(
                      color: Color(0xFF66748F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  for (final day
                      in _days.where((day) => _selectedDays.contains(day))) ...[
                    _ScheduleDayTimeRow(
                      day: day,
                      startController: _startControllerFor(day),
                      endController: _endControllerFor(day),
                      startValidator: (value) => _validateStartTime(day, value),
                      endValidator: (value) => _validateEndTime(day, value),
                      onPickStart: () => _pickTime(day, isStart: true),
                      onPickEnd: () => _pickTime(day, isStart: false),
                      onClear: () => _clearScheduleTime(day),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFD9233F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSaving || _isDeleting ? null : _saveCourse,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Course Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    disabledBackgroundColor: const Color(0xFF9BB6FF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      _isSaving || _isDeleting ? null : _confirmDeleteCourse,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete Course'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF526B),
                    side: const BorderSide(color: Color(0xFFFFB8C3)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _CourseStudentsSection(course: widget.course),
                const SizedBox(height: 16),
                _CourseLiveClassesSection(course: widget.course),
                const SizedBox(height: 16),
                _CourseMaterialsSection(
                  course: widget.course,
                  onUploadPressed: _openMaterialUploadSheet,
                ),
                const SizedBox(height: 16),
                _CourseQuizzesSection(
                  course: widget.course,
                  onCreatePressed: _openQuizCreator,
                ),
                const SizedBox(height: 16),
                _CourseAssignmentsSection(
                  course: widget.course,
                  onCreatePressed: _openAssignmentCreator,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF316DFF) : const Color(0xFFF6F8FC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF316DFF)
                  : const Color(0xFFE2E8F4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF50617F),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleDayTimeRow extends StatelessWidget {
  const _ScheduleDayTimeRow({
    required this.day,
    required this.startController,
    required this.endController,
    required this.startValidator,
    required this.endValidator,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final String day;
  final TextEditingController startController;
  final TextEditingController endController;
  final String? Function(String?) startValidator;
  final String? Function(String?) endValidator;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasTime = startController.text.trim().isNotEmpty ||
        endController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasTime)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ScheduleTimeField(
                  controller: startController,
                  label: 'Start',
                  validator: startValidator,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScheduleTimeField(
                  controller: endController,
                  label: 'End',
                  validator: endValidator,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimeField extends StatelessWidget {
  const _ScheduleTimeField({
    required this.controller,
    required this.label,
    required this.validator,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      validator: validator,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.access_time_rounded,
          color: Color(0xFF6F7E9A),
        ),
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.schedule_rounded),
        ),
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
      ),
    );
  }
}

class _CourseTypeSelector extends StatelessWidget {
  const _CourseTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CourseTypeOption(
              label: 'Group',
              value: 'group',
              selectedType: selectedType,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CourseTypeOption(
              label: 'Individual',
              value: 'individual',
              selectedType: selectedType,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTypeOption extends StatelessWidget {
  const _CourseTypeOption({
    required this.label,
    required this.value,
    required this.selectedType,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF316DFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF50617F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CourseLiveClassesSection extends StatelessWidget {
  const _CourseLiveClassesSection({required this.course});

  final _CourseData course;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Classes',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Shared links show here until the end time passes',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.live_tv_rounded,
                color: Color(0xFFFF3B6B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (teacher == null)
            const _MaterialsMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Teacher login needed.',
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_live_classes')
                  .doc(teacher.uid)
                  .collection('classes')
                  .where('courseId', isEqualTo: course.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _MaterialsMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Live classes load failed. Rules check කරන්න.',
                  );
                }

                final now = DateTime.now();
                final liveClasses = (snapshot.data?.docs ?? [])
                    .map(_CourseLiveClassData.fromSnapshot)
                    .where((liveClass) => liveClass.status == 'active')
                    .where((liveClass) => liveClass.meetingLink.isNotEmpty)
                    .where((liveClass) {
                  final endAt = liveClass.endAt;
                  return endAt == null || endAt.isAfter(now);
                }).toList()
                  ..sort((first, second) {
                    final firstDate = first.startAt ?? DateTime(9999);
                    final secondDate = second.startAt ?? DateTime(9999);
                    return firstDate.compareTo(secondDate);
                  });

                if (liveClasses.isEmpty) {
                  return const _MaterialsMessage(
                    icon: Icons.live_tv_outlined,
                    message: 'No active live class links for this course.',
                  );
                }

                return Column(
                  children: [
                    for (var index = 0;
                        index < liveClasses.length;
                        index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _LiveClassListTile(
                        liveClass: liveClasses[index],
                        teacherUid: teacher.uid,
                      ),
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

class _CourseStudentsSection extends StatelessWidget {
  const _CourseStudentsSection({required this.course});

  final _CourseData course;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Course Students',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'මේ course එක register වෙලා තියෙන students',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.groups_2_outlined,
                color: Color(0xFF316DFF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (teacher == null)
            const _MaterialsMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Teacher login needed.',
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('createdBy', isEqualTo: teacher.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _MaterialsMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Students load failed. Rules check කරන්න.',
                  );
                }

                final students = (snapshot.data?.docs ?? [])
                    .map(_CourseStudentData.fromSnapshot)
                    .where((student) => student.role == 'student')
                    .where(
                      (student) => student.status.toLowerCase() != 'archived',
                    )
                    .where((student) => student.matchesCourse(course))
                    .toList()
                  ..sort((first, second) => first.name.compareTo(second.name));

                if (students.isEmpty) {
                  return const _MaterialsMessage(
                    icon: Icons.people_outline_rounded,
                    message: 'මේ course එකට students register වෙලා නැහැ.',
                  );
                }

                if (students.length <= 2) {
                  return Column(
                    children: [
                      for (var index = 0; index < students.length; index++) ...[
                        if (index > 0) const SizedBox(height: 10),
                        _CourseStudentTile(student: students[index]),
                      ],
                    ],
                  );
                }

                return SizedBox(
                  height: 154,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _CourseStudentTile(student: students[index]);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CourseStudentTile extends StatelessWidget {
  const _CourseStudentTile({required this.student});

  final _CourseStudentData student;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentDetailPage(studentId: student.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: student.avatarColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  student.initials,
                  style: TextStyle(
                    color: student.avatarColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
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
                      student.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697992),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MaterialTag(
                label: student.statusLabel,
                color: student.statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseMaterialsSection extends StatelessWidget {
  const _CourseMaterialsSection({
    required this.course,
    required this.onUploadPressed,
  });

  final _CourseData course;
  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F4)),
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
                      'Course Materials',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Notes, tutes, videos, PDFs and links',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onUploadPressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Upload'),
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
          if (teacher == null)
            const _MaterialsMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Teacher login needed.',
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_materials')
                  .doc(teacher.uid)
                  .collection('materials')
                  .where('courseId', isEqualTo: course.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _MaterialsMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Materials load failed. Rules check කරන්න.',
                  );
                }

                final materials = (snapshot.data?.docs ?? [])
                    .map(_CourseMaterialData.fromSnapshot)
                    .where((material) => material.status != 'archived')
                    .toList()
                  ..sort((first, second) {
                    final firstDate = first.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final secondDate = second.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return secondDate.compareTo(firstDate);
                  });

                if (materials.isEmpty) {
                  return _EmptyMaterialsCard(onUploadPressed: onUploadPressed);
                }

                return Column(
                  children: [
                    for (var index = 0; index < materials.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _MaterialListTile(
                        material: materials[index],
                        course: course,
                        teacherUid: teacher.uid,
                      ),
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

class _CourseQuizzesSection extends StatelessWidget {
  const _CourseQuizzesSection({
    required this.course,
    required this.onCreatePressed,
  });

  final _CourseData course;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F4)),
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
                      'Course Quizzes',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'මේ course/module එකට අදාල quizzes',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Quiz'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7048E8),
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
          if (teacher == null)
            const _MaterialsMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Teacher login needed.',
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_quizzes')
                  .doc(teacher.uid)
                  .collection('quizzes')
                  .where('courseId', isEqualTo: course.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _MaterialsMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Quizzes load failed. Rules check කරන්න.',
                  );
                }

                final quizzes = (snapshot.data?.docs ?? [])
                    .map(_CourseQuizData.fromSnapshot)
                    .where((quiz) => quiz.status != 'archived')
                    .toList()
                  ..sort((first, second) {
                    final firstDate = first.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final secondDate = second.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return secondDate.compareTo(firstDate);
                  });

                if (quizzes.isEmpty) {
                  return _EmptyQuizzesCard(onCreatePressed: onCreatePressed);
                }

                return Column(
                  children: [
                    for (var index = 0; index < quizzes.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _QuizListTile(
                        quiz: quizzes[index],
                        course: course,
                        teacherUid: teacher.uid,
                      ),
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

class _QuizListTile extends StatelessWidget {
  const _QuizListTile({
    required this.quiz,
    required this.course,
    required this.teacherUid,
  });

  final _CourseQuizData quiz;
  final _CourseData course;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openQuizPreview(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF7048E8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Color(0xFF7048E8),
                  size: 22,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      quiz.lesson.isEmpty ? quiz.courseName : quiz.lesson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697992),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MaterialTag(
                          label: '${quiz.questionCount} Questions',
                          color: const Color(0xFF7048E8),
                        ),
                        _MaterialTag(
                          label: quiz.marksLabel,
                          color: const Color(0xFF316DFF),
                        ),
                        _MaterialTag(
                          label: '${quiz.timeLimitMinutes} min',
                          color: const Color(0xFFFF9500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Quiz actions',
                onSelected: (value) {
                  if (value == 'view') {
                    _openQuizPreview(context);
                  } else if (value == 'edit') {
                    _openQuizEditor(context);
                  } else if (value == 'delete') {
                    _archiveContent(
                      context: context,
                      teacherUid: teacherUid,
                      rootCollection: 'teacher_quizzes',
                      childCollection: 'quizzes',
                      documentId: quiz.id,
                      itemLabel: 'quiz',
                      title: quiz.title,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('View'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuizPreview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuizPreviewSheet(quiz: quiz),
    );
  }

  void _openQuizEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateQuizPage(
          quizId: quiz.id,
          initialCourseId: course.id,
          initialCourseName: course.name,
          initialCourseGrade: course.grade,
          initialTitle: quiz.title,
          initialLesson: quiz.lesson,
          initialTimeLimitMinutes: quiz.timeLimitMinutes,
          initialQuestions: quiz.editableQuestions,
          lockCourse: true,
        ),
      ),
    );
  }
}

class _QuizPreviewSheet extends StatelessWidget {
  const _QuizPreviewSheet({required this.quiz});

  final _CourseQuizData quiz;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                quiz.title,
                style: const TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${quiz.courseName} • ${quiz.lesson}',
                style: const TextStyle(
                  color: Color(0xFF60708F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MaterialTag(
                    label: '${quiz.questionCount} Questions',
                    color: const Color(0xFF7048E8),
                  ),
                  _MaterialTag(
                    label: quiz.marksLabel,
                    color: const Color(0xFF316DFF),
                  ),
                  _MaterialTag(
                    label: '${quiz.timeLimitMinutes} min',
                    color: const Color(0xFFFF9500),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < quiz.questions.length; index++) ...[
                _QuizQuestionPreview(
                  number: index + 1,
                  question: quiz.questions[index],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QuizQuestionPreview extends StatelessWidget {
  const _QuizQuestionPreview({
    required this.number,
    required this.question,
  });

  final int number;
  final _CourseQuizQuestion question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question $number',
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                question.marksLabel,
                style: const TextStyle(
                  color: Color(0xFF316DFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.text,
            style: const TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final option in question.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $option',
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            'Correct: ${question.correctAnswer}',
            style: const TextStyle(
              color: Color(0xFF00A86B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQuizzesCard extends StatelessWidget {
  const _EmptyQuizzesCard({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onCreatePressed,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.quiz_outlined,
                color: Color(0xFF7048E8),
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'No quizzes for this course yet',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tap here to create the first quiz for this module.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6C7892),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseAssignmentsSection extends StatelessWidget {
  const _CourseAssignmentsSection({
    required this.course,
    required this.onCreatePressed,
  });

  final _CourseData course;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F4)),
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
                      'Course Assignments',
                      style: TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Google Drive link submissions',
                      style: TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Task'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
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
          if (teacher == null)
            const _MaterialsMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Teacher login needed.',
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_assignments')
                  .doc(teacher.uid)
                  .collection('assignments')
                  .where('courseId', isEqualTo: course.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _MaterialsMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Assignments load failed. Rules check කරන්න.',
                  );
                }

                final assignments = (snapshot.data?.docs ?? [])
                    .map(_CourseAssignmentData.fromSnapshot)
                    .where((assignment) => assignment.status != 'archived')
                    .toList()
                  ..sort((first, second) {
                    final firstDate = first.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final secondDate = second.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return secondDate.compareTo(firstDate);
                  });

                if (assignments.isEmpty) {
                  return _EmptyAssignmentsCard(
                      onCreatePressed: onCreatePressed);
                }

                return Column(
                  children: [
                    for (var index = 0;
                        index < assignments.length;
                        index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _AssignmentListTile(
                        assignment: assignments[index],
                        teacherUid: teacher.uid,
                        course: course,
                      ),
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

class _AssignmentListTile extends StatelessWidget {
  const _AssignmentListTile({
    required this.assignment,
    required this.teacherUid,
    required this.course,
  });

  final _CourseAssignmentData assignment;
  final String teacherUid;
  final _CourseData course;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openAssignmentPreview(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFFFF9500),
                  size: 22,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Deadline: ${assignment.deadlineLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697992),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MaterialTag(
                          label: assignment.marksLabel,
                          color: const Color(0xFF316DFF),
                        ),
                        _MaterialTag(
                          label: assignment.latePolicyLabel,
                          color: const Color(0xFFFF9500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Assignment actions',
                onSelected: (value) {
                  if (value == 'view') {
                    _openAssignmentPreview(context);
                  } else if (value == 'edit') {
                    _openAssignmentEditor(context);
                  } else if (value == 'delete') {
                    _archiveContent(
                      context: context,
                      teacherUid: teacherUid,
                      rootCollection: 'teacher_assignments',
                      childCollection: 'assignments',
                      documentId: assignment.id,
                      itemLabel: 'assignment',
                      title: assignment.title,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('View submissions'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAssignmentPreview(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentPreviewSheet(
        assignment: assignment,
        teacherUid: teacherUid,
      ),
    );
  }

  void _openAssignmentEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAssignmentPage(
          assignmentId: assignment.id,
          initialCourseId: course.id,
          initialCourseName: course.name,
          initialCourseGrade: course.grade,
          initialTitle: assignment.title,
          initialInstructions: assignment.instructions,
          initialDeadline: assignment.deadline,
          initialMaxMarks: assignment.maxMarks,
          initialLatePolicy: assignment.latePolicy,
          initialLatePenaltyMarks: assignment.latePenaltyMarks,
          lockCourse: true,
        ),
      ),
    );
  }
}

class _AssignmentPreviewSheet extends StatelessWidget {
  const _AssignmentPreviewSheet({
    required this.assignment,
    required this.teacherUid,
  });

  final _CourseAssignmentData assignment;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                assignment.title,
                style: const TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${assignment.courseName} • Deadline ${assignment.deadlineLabel}',
                style: const TextStyle(
                  color: Color(0xFF60708F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MaterialTag(
                    label: assignment.marksLabel,
                    color: const Color(0xFF316DFF),
                  ),
                  _MaterialTag(
                    label: assignment.latePolicyLabel,
                    color: const Color(0xFFFF9500),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F4)),
                ),
                child: Text(
                  assignment.instructions,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Student Submissions',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('assignment_submissions')
                    .doc(teacherUid)
                    .collection('submissions')
                    .where('assignmentId', isEqualTo: assignment.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _MaterialsMessage(
                      icon: Icons.warning_amber_rounded,
                      message: 'Submissions load failed. Rules check කරන්න.',
                    );
                  }

                  final submissions = (snapshot.data?.docs ?? [])
                      .map(_AssignmentSubmissionData.fromSnapshot)
                      .toList()
                    ..sort((first, second) {
                      final firstDate = first.submittedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final secondDate = second.submittedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return secondDate.compareTo(firstDate);
                    });

                  if (submissions.isEmpty) {
                    return const _MaterialsMessage(
                      icon: Icons.inbox_outlined,
                      message: 'No student submissions yet.',
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0;
                          index < submissions.length;
                          index++) ...[
                        if (index > 0) const SizedBox(height: 10),
                        _AssignmentSubmissionTile(
                            submission: submissions[index]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentSubmissionTile extends StatelessWidget {
  const _AssignmentSubmissionTile({required this.submission});

  final _AssignmentSubmissionData submission;

  @override
  Widget build(BuildContext context) {
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
              color: submission.isLate
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFE7F9F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              submission.isLate
                  ? Icons.warning_amber_rounded
                  : Icons.check_rounded,
              color: submission.isLate
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF00A86B),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.studentName,
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
                  submission.isLate
                      ? 'Late • max ${submission.effectiveMarksLabel}'
                      : 'On time • max ${submission.effectiveMarksLabel}',
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy Drive link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: submission.driveLink));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Drive link copied.')),
              );
            },
            icon: const Icon(Icons.content_copy_rounded),
            color: const Color(0xFF316DFF),
          ),
        ],
      ),
    );
  }
}

class _EmptyAssignmentsCard extends StatelessWidget {
  const _EmptyAssignmentsCard({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onCreatePressed,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: Color(0xFFFF9500),
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'No assignments yet',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tap here to create the first assignment for this module.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6C7892),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseStudentData {
  const _CourseStudentData({
    required this.id,
    required this.name,
    required this.email,
    required this.grade,
    required this.role,
    required this.status,
    required this.courseIds,
    required this.courseNames,
  });

  final String id;
  final String name;
  final String email;
  final String grade;
  final String role;
  final String status;
  final Set<String> courseIds;
  final Set<String> courseNames;

  factory _CourseStudentData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final courseIds = <String>{};
    final courseNames = <String>{};

    void addCourseId(String value) {
      final normalized = value.trim();
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

    void addCourseMap(Map<dynamic, dynamic> rawData) {
      final courseData = <String, dynamic>{};
      rawData.forEach((key, value) {
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

    void addCoursesFromField(String field) {
      final value = data[field];
      if (value is! Iterable) {
        return;
      }

      for (final item in value) {
        if (item is Map) {
          addCourseMap(item);
        } else {
          addCourseId(item.toString());
        }
      }
    }

    addCoursesFromField('courseIds');
    addCoursesFromField('courses');
    addCoursesFromField('enrolledCourses');
    addCoursesFromField('studentCourses');
    addCourseId(_readString(data, 'courseId', ''));
    addCourseName(
        _readString(data, 'course', _readString(data, 'subject', '')));

    return _CourseStudentData(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Student'),
      email: _readString(data, 'email', ''),
      grade: _readString(data, 'grade', ''),
      role: _readString(data, 'role', 'student'),
      status: _readString(data, 'status', 'active'),
      courseIds: courseIds,
      courseNames: courseNames,
    );
  }

  bool matchesCourse(_CourseData course) {
    final courseId = course.id.trim();
    final courseName = course.name.trim().toLowerCase();

    return (courseId.isNotEmpty && courseIds.contains(courseId)) ||
        (courseName.isNotEmpty && courseNames.contains(courseName));
  }

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  String get subtitle {
    final details = <String>[
      if (grade.isNotEmpty) grade,
      if (email.isNotEmpty) email,
    ];

    return details.isEmpty ? id : details.join(' • ');
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'due':
        return 'Due';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Active';
    }
  }

  Color get avatarColor {
    final colors = [
      const Color(0xFF316DFF),
      const Color(0xFF7048E8),
      const Color(0xFF00A86B),
      const Color(0xFFFF9500),
      const Color(0xFFFF526B),
    ];

    return colors[id.hashCode.abs() % colors.length];
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'due':
        return const Color(0xFFFF526B);
      case 'overdue':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFF00A86B);
    }
  }

  static String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }
}

class _CourseLiveClassData {
  const _CourseLiveClassData({
    required this.id,
    required this.title,
    required this.meetingLink,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final String id;
  final String title;
  final String meetingLink;
  final DateTime? startAt;
  final DateTime? endAt;
  final String status;

  factory _CourseLiveClassData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final startAt = data['startAt'];
    final endAt = data['endAt'];

    return _CourseLiveClassData(
      id: snapshot.id,
      title: _readString(data, 'title', 'Live Class'),
      meetingLink: _readString(data, 'meetingLink', ''),
      startAt: startAt is Timestamp ? startAt.toDate() : null,
      endAt: endAt is Timestamp ? endAt.toDate() : null,
      status: _readString(data, 'status', 'active'),
    );
  }

  String get startLabel =>
      startAt == null ? 'Start time not set' : dateTimeLabel(startAt!);

  String get endLabel =>
      endAt == null ? 'End time not set' : dateTimeLabel(endAt!);

  static String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }

  static String dateTimeLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day $hour:$minute $period';
  }
}

class _LiveClassListTile extends StatelessWidget {
  const _LiveClassListTile({
    required this.liveClass,
    required this.teacherUid,
  });

  final _CourseLiveClassData liveClass;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = liveClass.startAt != null &&
        liveClass.endAt != null &&
        now.isAfter(liveClass.startAt!) &&
        now.isBefore(liveClass.endAt!);
    final isUpcoming =
        liveClass.startAt != null && now.isBefore(liveClass.startAt!);
    final statusLabel = isLive
        ? 'Live now'
        : isUpcoming
            ? 'Upcoming'
            : 'Active';
    final statusColor = isLive
        ? const Color(0xFF00A86B)
        : isUpcoming
            ? const Color(0xFFFF9500)
            : const Color(0xFF316DFF);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copyLink(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B6B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFFFF3B6B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liveClass.title,
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
                      liveClass.meetingLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697992),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MaterialTag(label: statusLabel, color: statusColor),
                        _MaterialTag(
                          label: liveClass.startLabel,
                          color: const Color(0xFF60708F),
                        ),
                        _MaterialTag(
                          label: 'Ends ${liveClass.endLabel}',
                          color: const Color(0xFF8B97AD),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy live link',
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.content_copy_rounded),
                color: const Color(0xFFFF3B6B),
              ),
              PopupMenuButton<String>(
                tooltip: 'Live class actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditSheet(context);
                  } else if (value == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFFF526B),
                        ),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: liveClass.meetingLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live class link copied.')),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditLiveClassSheet(
        liveClass: liveClass,
        teacherUid: teacherUid,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete live class?'),
          content: Text(
            '${liveClass.title} live class link එක course එකෙන් hide වෙනවා.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('teacher_live_classes')
          .doc(teacherUid)
          .collection('classes')
          .doc(liveClass.id)
          .update({
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live class link deleted.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Permission denied. Firestore live class rules check කරන්න.'
                : 'Firebase error: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }
}

class _EditLiveClassSheet extends StatefulWidget {
  const _EditLiveClassSheet({
    required this.liveClass,
    required this.teacherUid,
  });

  final _CourseLiveClassData liveClass;
  final String teacherUid;

  @override
  State<_EditLiveClassSheet> createState() => _EditLiveClassSheetState();
}

class _EditLiveClassSheetState extends State<_EditLiveClassSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _linkController;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.liveClass.title);
    _linkController = TextEditingController(text: widget.liveClass.meetingLink);
    _startAt = widget.liveClass.startAt;
    _endAt = widget.liveClass.endAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startAt ?? now)
        : (_endAt ?? (_startAt ?? now).add(const Duration(hours: 1)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = value;
        if (_endAt == null || !_endAt!.isAfter(value)) {
          _endAt = value.add(const Duration(hours: 1));
        }
      } else {
        _endAt = value;
      }
    });
  }

  Future<void> _saveLiveClass() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startAt = _startAt;
    final endAt = _endAt;
    if (startAt == null || endAt == null) {
      setState(() {
        _errorMessage = 'Start time සහ end time දාන්න.';
      });
      return;
    }

    if (!endAt.isAfter(startAt)) {
      setState(() {
        _errorMessage = 'End time එක start time එකට පස්සේ වෙන්න ඕන.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('teacher_live_classes')
          .doc(widget.teacherUid)
          .collection('classes')
          .doc(widget.liveClass.id)
          .update({
        'title': _titleController.text.trim(),
        'meetingLink': _linkController.text.trim(),
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live class link updated.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Permission denied. Firestore live class rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Live class update කරන්න බැරි උනා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateLink(String? value) {
    final link = (value ?? '').trim();
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !(link.startsWith('http://') || link.startsWith('https://'))) {
      return 'Valid live class link එක දාන්න.';
    }
    return null;
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                  'Edit Live Class',
                  style: TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Link, title, start time සහ end time update කරන්න.',
                  style: TextStyle(
                    color: Color(0xFF6C7892),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Live class title එක දාන්න.'
                      : null,
                  decoration: _liveClassInputDecoration(
                    label: 'Live class title',
                    icon: Icons.live_tv_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  validator: _validateLink,
                  decoration: _liveClassInputDecoration(
                    label: 'Live class link',
                    icon: Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                _LiveClassDateTimeField(
                  label: 'Start time',
                  value: _startAt,
                  onTap: () => _pickDateTime(isStart: true),
                ),
                const SizedBox(height: 12),
                _LiveClassDateTimeField(
                  label: 'End time',
                  value: _endAt,
                  onTap: () => _pickDateTime(isStart: false),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFD9233F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveLiveClass,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Live Class'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B6B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
}

class _LiveClassDateTimeField extends StatelessWidget {
  const _LiveClassDateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: _liveClassInputDecoration(
          label: label,
          icon: Icons.schedule_rounded,
        ),
        child: Text(
          value == null
              ? 'Select date and time'
              : _CourseLiveClassData.dateTimeLabel(value!),
          style: TextStyle(
            color: value == null
                ? const Color(0xFF8B97AD)
                : const Color(0xFF071B3C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

InputDecoration _liveClassInputDecoration({
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
      borderSide: const BorderSide(color: Color(0xFFFF3B6B), width: 1.4),
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

class _MaterialListTile extends StatelessWidget {
  const _MaterialListTile({
    required this.material,
    required this.course,
    required this.teacherUid,
  });

  final _CourseMaterialData material;
  final _CourseData course;
  final String teacherUid;

  @override
  Widget build(BuildContext context) {
    final visual = _MaterialVisual.forType(material.type);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copyLink(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(visual.icon, color: visual.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
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
                      material.description.isEmpty
                          ? 'Tap to copy material link'
                          : material.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF697992),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MaterialTag(
                          label: visual.label,
                          color: visual.color,
                        ),
                        _MaterialTag(
                          label: material.sourceLabel,
                          color: const Color(0xFF60708F),
                        ),
                        if (material.dateLabel.isNotEmpty)
                          _MaterialTag(
                            label: material.dateLabel,
                            color: const Color(0xFF8B97AD),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Material actions',
                onSelected: (value) {
                  if (value == 'copy') {
                    _copyLink(context);
                  } else if (value == 'edit') {
                    _openEditSheet(context);
                  } else if (value == 'delete') {
                    _archiveContent(
                      context: context,
                      teacherUid: teacherUid,
                      rootCollection: 'teacher_materials',
                      childCollection: 'materials',
                      documentId: material.id,
                      itemLabel: 'material',
                      title: material.title,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.content_copy_rounded),
                      title: Text('Copy link'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyLink(BuildContext context) {
    final link = material.primaryLink;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material link not available.')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material link copied.')),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadMaterialSheet(
        initialCourseId: course.id,
        initialCourseName: course.name,
        initialCourseGrade: course.grade,
        materialId: material.id,
        initialTitle: material.title,
        initialDescription: material.description,
        initialLink: material.primaryLink,
        initialType: material.type,
        lockCourse: true,
      ),
    );
  }
}

Future<void> _archiveContent({
  required BuildContext context,
  required String teacherUid,
  required String rootCollection,
  required String childCollection,
  required String documentId,
  required String itemLabel,
  required String title,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Delete $itemLabel?'),
        content: Text('$title hide/delete වෙනවා. Continue කරන්නද?'),
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
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection(rootCollection)
        .doc(teacherUid)
        .collection(childCollection)
        .doc(documentId)
        .update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title deleted.')),
    );
  } on FirebaseException catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.code == 'permission-denied'
              ? 'Permission denied. Firestore rules update කරන්න.'
              : 'Firebase error: ${error.message ?? error.code}',
        ),
      ),
    );
  }
}

class _MaterialTag extends StatelessWidget {
  const _MaterialTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyMaterialsCard extends StatelessWidget {
  const _EmptyMaterialsCard({required this.onUploadPressed});

  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onUploadPressed,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F4)),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: Color(0xFF316DFF),
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'No materials uploaded yet',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tap here to add the first note, tute, video, PDF or link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6C7892),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialsMessage extends StatelessWidget {
  const _MaterialsMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8C98AF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6C7892),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseMaterialData {
  const _CourseMaterialData({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.link,
    required this.downloadUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String link;
  final String downloadUrl;
  final String status;
  final DateTime? createdAt;

  factory _CourseMaterialData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];

    return _CourseMaterialData(
      id: snapshot.id,
      title: _readString(data, 'title', 'Untitled Material'),
      description: _readString(data, 'description', ''),
      type: _readString(data, 'type', 'note'),
      link: _readString(data, 'link', ''),
      downloadUrl: _readString(data, 'downloadUrl', ''),
      status: _readString(data, 'status', 'active'),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  String get primaryLink => downloadUrl.isNotEmpty ? downloadUrl : link;

  String get sourceLabel => 'Link';

  String get dateLabel {
    final date = createdAt;
    if (date == null) {
      return '';
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  static String _readString(
    Map<String, dynamic> data,
    String key,
    String fallback,
  ) {
    final value = data[key]?.toString().trim();
    return value?.isNotEmpty == true ? value! : fallback;
  }
}

class _CourseQuizData {
  const _CourseQuizData({
    required this.id,
    required this.title,
    required this.lesson,
    required this.courseName,
    required this.timeLimitMinutes,
    required this.totalMarks,
    required this.questionCount,
    required this.status,
    required this.createdAt,
    required this.questions,
  });

  final String id;
  final String title;
  final String lesson;
  final String courseName;
  final int timeLimitMinutes;
  final double totalMarks;
  final int questionCount;
  final String status;
  final DateTime? createdAt;
  final List<_CourseQuizQuestion> questions;

  factory _CourseQuizData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];
    final questions = <_CourseQuizQuestion>[];
    final rawQuestions = data['questions'];

    if (rawQuestions is Iterable) {
      for (final item in rawQuestions) {
        final question = _CourseQuizQuestion.tryParse(item);
        if (question != null) {
          questions.add(question);
        }
      }
    }

    return _CourseQuizData(
      id: snapshot.id,
      title: _readString(data, 'title', 'Untitled Quiz'),
      lesson: _readString(data, 'lesson', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      timeLimitMinutes: _readInt(data, 'timeLimitMinutes', 30),
      totalMarks: _readDouble(data, 'totalMarks'),
      questionCount: _readInt(data, 'questionCount', questions.length),
      status: _readString(data, 'status', 'active'),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      questions: List.unmodifiable(questions),
    );
  }

  String get marksLabel {
    final hasCents = totalMarks.truncateToDouble() != totalMarks;
    return '${totalMarks.toStringAsFixed(hasCents ? 1 : 0)} Marks';
  }

  List<Map<String, dynamic>> get editableQuestions {
    return questions
        .map((question) => question.toEditableMap())
        .toList(growable: false);
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

  static int _readInt(Map<String, dynamic> data, String key, int fallback) {
    final value = data[key];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _CourseQuizQuestion {
  const _CourseQuizQuestion({
    required this.text,
    required this.type,
    required this.options,
    required this.correctAnswer,
    required this.correctOptionIndex,
    required this.marks,
  });

  final String text;
  final String type;
  final List<String> options;
  final String correctAnswer;
  final int correctOptionIndex;
  final double marks;

  static _CourseQuizQuestion? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final data = <String, dynamic>{};
    value.forEach((key, value) {
      data[key.toString()] = value;
    });
    final text = _readString(data, 'question', '');

    if (text.isEmpty) {
      return null;
    }

    return _CourseQuizQuestion(
      text: text,
      type: _readString(data, 'type', 'mcq'),
      options: _readStringList(data, 'options'),
      correctAnswer: _readString(data, 'correctAnswer', '-'),
      correctOptionIndex: _readInt(data, 'correctOptionIndex', -1),
      marks: _readDouble(data, 'marks'),
    );
  }

  String get marksLabel {
    final hasCents = marks.truncateToDouble() != marks;
    return '${marks.toStringAsFixed(hasCents ? 1 : 0)} marks';
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

  static int _readInt(Map<String, dynamic> data, String key, int fallback) {
    final value = data[key];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _readStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> toEditableMap() {
    final optionIndex = correctOptionIndex >= 0
        ? correctOptionIndex
        : options.indexWhere(
            (option) =>
                option.trim().toLowerCase() ==
                correctAnswer.trim().toLowerCase(),
          );

    return {
      'type': type,
      'question': text,
      'marks': marks,
      'options': options,
      'correctAnswer': correctAnswer,
      'correctOptionIndex': optionIndex,
    };
  }
}

class _CourseAssignmentData {
  const _CourseAssignmentData({
    required this.id,
    required this.title,
    required this.instructions,
    required this.courseName,
    required this.deadline,
    required this.maxMarks,
    required this.latePolicy,
    required this.latePenaltyMarks,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String instructions;
  final String courseName;
  final DateTime? deadline;
  final double maxMarks;
  final String latePolicy;
  final double latePenaltyMarks;
  final String status;
  final DateTime? createdAt;

  factory _CourseAssignmentData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final deadline = data['deadline'];
    final createdAt = data['createdAt'];

    return _CourseAssignmentData(
      id: snapshot.id,
      title: _readString(data, 'title', 'Untitled Assignment'),
      instructions: _readString(data, 'instructions', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      deadline: deadline is Timestamp ? deadline.toDate() : null,
      maxMarks: _readDouble(data, 'maxMarks'),
      latePolicy: _readString(data, 'latePolicy', 'block'),
      latePenaltyMarks: _readDouble(data, 'latePenaltyMarks'),
      status: _readString(data, 'status', 'active'),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  String get deadlineLabel {
    final date = deadline;
    if (date == null) {
      return 'Not set';
    }
    return _dateTimeLabel(date);
  }

  String get marksLabel {
    final hasCents = maxMarks.truncateToDouble() != maxMarks;
    return '${maxMarks.toStringAsFixed(hasCents ? 1 : 0)} Marks';
  }

  String get latePolicyLabel {
    if (latePolicy == 'deduct') {
      final hasCents = latePenaltyMarks.truncateToDouble() != latePenaltyMarks;
      return 'Late -${latePenaltyMarks.toStringAsFixed(hasCents ? 1 : 0)}';
    }
    return 'No late submit';
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
}

class _AssignmentSubmissionData {
  const _AssignmentSubmissionData({
    required this.studentName,
    required this.driveLink,
    required this.isLate,
    required this.effectiveMaxMarks,
    required this.submittedAt,
  });

  final String studentName;
  final String driveLink;
  final bool isLate;
  final double effectiveMaxMarks;
  final DateTime? submittedAt;

  factory _AssignmentSubmissionData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final submittedAt = data['submittedAt'];

    return _AssignmentSubmissionData(
      studentName: _readString(data, 'studentName', 'Student'),
      driveLink: _readString(data, 'driveLink', ''),
      isLate: data['isLate'] == true,
      effectiveMaxMarks: _readDouble(data, 'effectiveMaxMarks'),
      submittedAt: submittedAt is Timestamp ? submittedAt.toDate() : null,
    );
  }

  String get effectiveMarksLabel {
    final hasCents = effectiveMaxMarks.truncateToDouble() != effectiveMaxMarks;
    return '${effectiveMaxMarks.toStringAsFixed(hasCents ? 1 : 0)} marks';
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
}

String _dateTimeLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.year}-$month-$day $hour:$minute $period';
}

class _MaterialVisual {
  const _MaterialVisual({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static _MaterialVisual forType(String type) {
    switch (type) {
      case 'tute':
        return const _MaterialVisual(
          label: 'Tute',
          icon: Icons.assignment_outlined,
          color: Color(0xFF7048E8),
        );
      case 'video':
        return const _MaterialVisual(
          label: 'Video',
          icon: Icons.play_circle_outline_rounded,
          color: Color(0xFFFF3B6B),
        );
      case 'pdf':
        return const _MaterialVisual(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          color: Color(0xFFFF9500),
        );
      case 'link':
        return const _MaterialVisual(
          label: 'Link',
          icon: Icons.link_rounded,
          color: Color(0xFF0FAF75),
        );
      default:
        return const _MaterialVisual(
          label: 'Note',
          icon: Icons.article_outlined,
          color: Color(0xFF316DFF),
        );
    }
  }
}

class _CourseMeta extends StatelessWidget {
  const _CourseMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF8A98B2)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF697992),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseDetailRow extends StatelessWidget {
  const _CourseDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 94,
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

class _CourseMessage extends StatelessWidget {
  const _CourseMessage({
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

class _CourseData {
  const _CourseData({
    required this.id,
    required this.name,
    required this.grade,
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
  final double classFee;
  final String type;
  final String location;
  final List<String> scheduleDays;
  final String scheduleTime;
  final List<CourseScheduleSlot> scheduleSlots;
  final String status;

  factory _CourseData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final slots = courseScheduleSlotsFromData(data);
    final scheduleDays = _readStringList(data, 'scheduleDays');
    return _CourseData(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      classFee: _readDouble(data, 'classFee'),
      type: _readString(data, 'type', 'group'),
      location: _readString(data, 'location', ''),
      scheduleDays: scheduleDays.isNotEmpty
          ? scheduleDays
          : courseScheduleDaysFromSlots(slots),
      scheduleTime: _readString(data, 'scheduleTime', ''),
      scheduleSlots: slots,
      status: _readString(data, 'status', 'active'),
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

  static List<String> _readStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  _CourseData copyWith({
    String? name,
    String? grade,
    double? classFee,
    String? type,
    String? location,
    List<String>? scheduleDays,
    String? scheduleTime,
    List<CourseScheduleSlot>? scheduleSlots,
    String? status,
  }) {
    return _CourseData(
      id: id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      classFee: classFee ?? this.classFee,
      type: type ?? this.type,
      location: location ?? this.location,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      scheduleSlots: scheduleSlots ?? this.scheduleSlots,
      status: status ?? this.status,
    );
  }

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
      'scheduleDays': scheduleDays,
      'scheduleTime': scheduleTime,
      'scheduleSlots': scheduleSlots.map((slot) => slot.toMap()).toList(),
      'status': status == 'archived' ? 'archived' : 'active',
    };
  }

  String get title => grade.isEmpty ? name : '$name $grade';

  String get typeLabel => type == 'individual' ? 'Individual' : 'Group';

  String get feeLabel {
    final hasCents = classFee.truncateToDouble() != classFee;
    return 'Rs ${classFee.toStringAsFixed(hasCents ? 2 : 0)}';
  }

  String get locationLabel {
    final parts = <String>[
      typeLabel,
      if (location.isNotEmpty) location,
      feeLabel,
    ];

    return parts.join(' • ');
  }

  String get scheduleLabel {
    return courseScheduleLabel(
      scheduleDays: scheduleDays,
      scheduleTime: scheduleTime,
      scheduleSlots: scheduleSlots,
    );
  }

  double progressFor(int studentCount) {
    final capacity = type == 'individual' ? 10 : 50;
    return (studentCount / capacity).clamp(0.0, 1.0);
  }
}

class _CourseColorScheme {
  const _CourseColorScheme({
    required this.headerColor,
    required this.accentColor,
  });

  final Color headerColor;
  final Color accentColor;

  static _CourseColorScheme byIndex(int index) {
    const schemes = [
      _CourseColorScheme(
        headerColor: Color(0xFFE6F0FF),
        accentColor: Color(0xFF316DFF),
      ),
      _CourseColorScheme(
        headerColor: Color(0xFFF0E9FF),
        accentColor: Color(0xFF7B2FF2),
      ),
      _CourseColorScheme(
        headerColor: Color(0xFFE0FAEB),
        accentColor: Color(0xFF00B979),
      ),
      _CourseColorScheme(
        headerColor: Color(0xFFFFF5D8),
        accentColor: Color(0xFFFF9500),
      ),
    ];

    return schemes[index % schemes.length];
  }
}
