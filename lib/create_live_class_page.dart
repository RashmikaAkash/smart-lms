import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateLiveClassPage extends StatefulWidget {
  const CreateLiveClassPage({super.key});

  @override
  State<CreateLiveClassPage> createState() => _CreateLiveClassPageState();
}

class _CreateLiveClassPageState extends State<CreateLiveClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();

  _LiveClassCourse? _selectedCourse;
  String? _selectedCourseId;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

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

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startAt ?? now.add(const Duration(minutes: 15)))
        : (_endAt ?? (_startAt ?? now).add(const Duration(hours: 1)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
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

  Future<void> _shareLiveClass() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    final course = _selectedCourse;
    final startAt = _startAt;
    final endAt = _endAt;

    if (teacher == null || course == null || startAt == null || endAt == null) {
      setState(() {
        _errorMessage = 'Teacher login, course, start time සහ end time දාන්න.';
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
      final liveClassReference = FirebaseFirestore.instance
          .collection('teacher_live_classes')
          .doc(teacher.uid)
          .collection('classes')
          .doc();

      await liveClassReference.set({
        'id': liveClassReference.id,
        'teacherUid': teacher.uid,
        'teacherEmail': teacher.email ?? '',
        'title': _titleController.text.trim(),
        'meetingLink': _linkController.text.trim(),
        'courseId': course.id,
        'courseName': course.name,
        'grade': course.grade,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live class link shared.')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Permission denied. Firestore live class rules add කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Live class share කරන්න බැරි වුණා.';
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
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Share Live Class',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            const _LiveClassHeroCard(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDE5F4)),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Live class title එක දාන්න.'
                        : null,
                    decoration: _inputDecoration(
                      label: 'Live class title',
                      icon: Icons.live_tv_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      final link = (value ?? '').trim();
                      final uri = Uri.tryParse(link);
                      if (uri == null ||
                          !(link.startsWith('http://') ||
                              link.startsWith('https://'))) {
                        return 'Valid live class link එක දාන්න.';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      label: 'Live class link',
                      icon: Icons.link_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LiveClassCourseDropdown(
                    stream: _coursesStream,
                    selectedCourseId: _selectedCourseId,
                    onSelected: (course) {
                      setState(() {
                        _selectedCourse = course;
                        _selectedCourseId = course.id;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _DateTimePickerField(
                    label: 'Start time',
                    value: _startAt,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                  const SizedBox(height: 12),
                  _DateTimePickerField(
                    label: 'End time',
                    value: _endAt,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                ],
              ),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : _shareLiveClass,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_isSaving ? 'Sharing...' : 'Share Live Class'),
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
    );
  }
}

class _LiveClassHeroCard extends StatelessWidget {
  const _LiveClassHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B6B), Color(0xFF7048E8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.live_tv_rounded, color: Colors.white, size: 42),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share live class',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Students see the link with start and end time.',
                  style: TextStyle(
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

class _DateTimePickerField extends StatelessWidget {
  const _DateTimePickerField({
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
        decoration: _inputDecoration(
          label: label,
          icon: Icons.schedule_rounded,
        ),
        child: Text(
          value == null ? 'Select date and time' : _dateTimeLabel(value!),
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

class _LiveClassCourseDropdown extends StatelessWidget {
  const _LiveClassCourseDropdown({
    required this.stream,
    required this.selectedCourseId,
    required this.onSelected,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final String? selectedCourseId;
  final ValueChanged<_LiveClassCourse> onSelected;

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        validator: (_) => 'Teacher login needed.',
        decoration: _inputDecoration(
          label: 'Course',
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return TextFormField(
            enabled: false,
            decoration: _inputDecoration(
              label: 'Loading courses...',
              icon: Icons.menu_book_outlined,
            ),
          );
        }

        final courses = (snapshot.data?.docs ?? [])
            .map(_LiveClassCourse.fromSnapshot)
            .where((course) => course.status != 'archived')
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name));
        final selectedValue =
            courses.any((course) => course.id == selectedCourseId)
                ? selectedCourseId
                : null;

        return DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          validator: (value) =>
              value == null ? 'Course එක select කරන්න.' : null,
          decoration: _inputDecoration(
            label: 'Course',
            icon: Icons.menu_book_outlined,
          ),
          hint: Text(courses.isEmpty ? 'Create course first' : 'Select course'),
          items: courses
              .map(
                (course) => DropdownMenuItem<String>(
                  value: course.id,
                  child: Text(
                    course.dropdownLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (courseId) {
            if (courseId == null) {
              return;
            }

            onSelected(courses.firstWhere((course) => course.id == courseId));
          },
        );
      },
    );
  }
}

class _LiveClassCourse {
  const _LiveClassCourse({
    required this.id,
    required this.name,
    required this.grade,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final String status;

  factory _LiveClassCourse.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _LiveClassCourse(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      status: _readString(data, 'status', 'active'),
    );
  }

  String get dropdownLabel => grade.isEmpty ? name : '$name • $grade';
}

InputDecoration _inputDecoration({
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

String _dateTimeLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.year}-$month-$day $hour:$minute $period';
}

String _readString(
  Map<String, dynamic> data,
  String key,
  String fallback,
) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
}
