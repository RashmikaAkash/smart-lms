import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'create_course_sheet.dart';
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

      final courseId = data['courseId']?.toString() ?? '';
      if (courseId.isEmpty) {
        continue;
      }

      counts[courseId] = (counts[courseId] ?? 0) + 1;
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
  final TextEditingController _timeController = TextEditingController();
  final Set<String> _selectedDays = <String>{};

  bool _isSaving = false;
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
    _selectedDays.addAll(widget.course.scheduleDays);
    _timeController.text = widget.course.scheduleTime;
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _parseTime(_timeController.text) ?? TimeOfDay.now(),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _timeController.text = selectedTime.format(context);
    });
  }

  TimeOfDay? _parseTime(String value) {
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

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _saveSchedule() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDays.isEmpty) {
      setState(() {
        _errorMessage = 'Class days select කරන්න.';
      });
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
      final time = _timeController.text.trim();
      final scheduleLabel = '${orderedDays.join('/')} $time';

      await FirebaseFirestore.instance
          .collection('teacher_courses')
          .doc(teacher.uid)
          .collection('courses')
          .doc(widget.course.id)
          .update({
        'scheduleDays': orderedDays,
        'scheduleTime': time,
        'scheduleLabel': scheduleLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.course.title} schedule updated.')),
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
        _errorMessage = 'Schedule update කරන්න බැරි උනා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateTime(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Class time එක දාන්න.';
    }
    return null;
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
                  'Class schedule update කරන්න days සහ time select කරන්න.',
                  style: TextStyle(
                    color: Color(0xFF66748F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _CourseDetailRow(
                  label: 'Students',
                  value: '${widget.studentCount}',
                ),
                _CourseDetailRow(label: 'Type', value: widget.course.typeLabel),
                _CourseDetailRow(label: 'Fee', value: widget.course.feeLabel),
                _CourseDetailRow(
                  label: 'Location',
                  value: widget.course.location,
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
                            } else {
                              _selectedDays.add(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _timeController,
                  readOnly: true,
                  validator: _validateTime,
                  onTap: _pickTime,
                  decoration: InputDecoration(
                    labelText: 'Class time',
                    prefixIcon: const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF6F7E9A),
                    ),
                    suffixIcon: IconButton(
                      onPressed: _pickTime,
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
                      borderSide: const BorderSide(
                        color: Color(0xFF316DFF),
                        width: 1.4,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF526B)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF526B),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
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
                  onPressed: _isSaving ? null : _saveSchedule,
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
                  label: Text(_isSaving ? 'Saving...' : 'Update Schedule'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    disabledBackgroundColor: const Color(0xFF9BB6FF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _CourseMaterialsSection(
                  course: widget.course,
                  onUploadPressed: _openMaterialUploadSheet,
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
                      _MaterialListTile(material: materials[index]),
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

class _MaterialListTile extends StatelessWidget {
  const _MaterialListTile({required this.material});

  final _CourseMaterialData material;

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
              IconButton(
                tooltip: 'Copy link',
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.content_copy_rounded),
                color: const Color(0xFF316DFF),
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
  final String status;

  factory _CourseData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _CourseData(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      classFee: _readDouble(data, 'classFee'),
      type: _readString(data, 'type', 'group'),
      location: _readString(data, 'location', ''),
      scheduleDays: _readStringList(data, 'scheduleDays'),
      scheduleTime: _readString(data, 'scheduleTime', ''),
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
    if (scheduleDays.isEmpty && scheduleTime.isEmpty) {
      return 'Schedule not set';
    }

    if (scheduleDays.isEmpty) {
      return scheduleTime;
    }

    if (scheduleTime.isEmpty) {
      return scheduleDays.join('/');
    }

    return '${scheduleDays.join('/')} $scheduleTime';
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
