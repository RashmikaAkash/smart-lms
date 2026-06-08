import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateAssignmentPage extends StatefulWidget {
  const CreateAssignmentPage({
    super.key,
    this.initialCourseId,
    this.initialCourseName,
    this.initialCourseGrade,
    this.assignmentId,
    this.initialTitle,
    this.initialInstructions,
    this.initialDeadline,
    this.initialMaxMarks,
    this.initialLatePolicy,
    this.initialLatePenaltyMarks,
    this.lockCourse = false,
  });

  final String? initialCourseId;
  final String? initialCourseName;
  final String? initialCourseGrade;
  final String? assignmentId;
  final String? initialTitle;
  final String? initialInstructions;
  final DateTime? initialDeadline;
  final double? initialMaxMarks;
  final String? initialLatePolicy;
  final double? initialLatePenaltyMarks;
  final bool lockCourse;

  @override
  State<CreateAssignmentPage> createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _marksController = TextEditingController(text: '100');
  final _penaltyController = TextEditingController(text: '0');

  _AssignmentCourse? _selectedCourse;
  late String? _selectedCourseId;
  DateTime? _deadline;
  String _latePolicy = 'block';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
    _titleController.text = widget.initialTitle ?? '';
    _instructionsController.text = widget.initialInstructions ?? '';
    if (widget.initialMaxMarks != null) {
      _marksController.text = _numberLabel(widget.initialMaxMarks!);
    }
    if (widget.initialLatePenaltyMarks != null) {
      _penaltyController.text = _numberLabel(widget.initialLatePenaltyMarks!);
    }
    _deadline = widget.initialDeadline;
    _latePolicy = widget.initialLatePolicy ?? 'block';
    if (widget.initialCourseId?.isNotEmpty == true) {
      _selectedCourse = _AssignmentCourse(
        id: widget.initialCourseId!,
        name: widget.initialCourseName?.trim().isNotEmpty == true
            ? widget.initialCourseName!.trim()
            : 'Selected Course',
        grade: widget.initialCourseGrade?.trim() ?? '',
        status: 'active',
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _marksController.dispose();
    _penaltyController.dispose();
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _deadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveAssignment() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    final course = _selectedCourse;
    final deadline = _deadline;

    if (teacher == null || course == null || deadline == null) {
      setState(() {
        _errorMessage = 'Teacher login, course සහ deadline select කරන්න.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final assignmentsCollection = FirebaseFirestore.instance
          .collection('teacher_assignments')
          .doc(teacher.uid)
          .collection('assignments');
      final assignmentReference = widget.assignmentId?.isNotEmpty == true
          ? assignmentsCollection.doc(widget.assignmentId)
          : assignmentsCollection.doc();
      final isEdit = widget.assignmentId?.isNotEmpty == true;
      final maxMarks = double.parse(_marksController.text.trim());
      final penaltyMarks = _latePolicy == 'deduct'
          ? double.tryParse(_penaltyController.text.trim()) ?? 0
          : 0.0;

      await assignmentReference.set({
        'id': assignmentReference.id,
        'teacherUid': teacher.uid,
        'teacherEmail': teacher.email ?? '',
        'title': _titleController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'courseId': course.id,
        'courseName': course.name,
        'grade': course.grade,
        'deadline': Timestamp.fromDate(deadline),
        'maxMarks': maxMarks,
        'latePolicy': _latePolicy,
        'latePenaltyMarks': penaltyMarks,
        'status': 'active',
        if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Assignment updated successfully.'
                : 'Assignment created successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Permission denied. Firestore assignment rules add කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Assignment save කරන්න බැරි වුණා.';
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
        title: Text(
          widget.assignmentId?.isNotEmpty == true
              ? 'Edit Assignment'
              : 'Create Assignment',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            const _AssignmentHeroCard(),
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
                        ? 'Assignment title දාන්න.'
                        : null,
                    decoration: _inputDecoration(
                      label: 'Assignment title',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instructionsController,
                    minLines: 5,
                    maxLines: 10,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Assignment instructions/type කරන්න.'
                        : null,
                    decoration: _inputDecoration(
                      label: 'Assignment instructions',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AssignmentCourseDropdown(
                    stream: _coursesStream,
                    selectedCourseId: _selectedCourseId,
                    enabled: !widget.lockCourse,
                    onSelected: (course) {
                      setState(() {
                        _selectedCourse = course;
                        _selectedCourseId = course.id;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _marksController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final marks = double.tryParse((value ?? '').trim());
                      if (marks == null || marks <= 0) {
                        return 'Marks 0ට වැඩි වෙන්න ඕන.';
                      }
                      return null;
                    },
                    decoration: _inputDecoration(
                      label: 'Total marks',
                      icon: Icons.grade_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDeadline,
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        label: 'Deadline',
                        icon: Icons.event_available_rounded,
                      ),
                      child: Text(
                        _deadline == null
                            ? 'Select date and time'
                            : _dateTimeLabel(_deadline!),
                        style: TextStyle(
                          color: _deadline == null
                              ? const Color(0xFF8B97AD)
                              : const Color(0xFF071B3C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LatePolicyCard(
              policy: _latePolicy,
              penaltyController: _penaltyController,
              onPolicyChanged: (policy) {
                setState(() {
                  _latePolicy = policy;
                });
              },
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
              onPressed: _isSaving ? null : _saveAssignment,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_turned_in_rounded),
              label: Text(
                _isSaving
                    ? 'Saving Assignment...'
                    : widget.assignmentId?.isNotEmpty == true
                        ? 'Update Assignment'
                        : 'Publish Assignment',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7048E8),
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

class _AssignmentHeroCard extends StatelessWidget {
  const _AssignmentHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFF7048E8)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.assignment_rounded, color: Colors.white, size: 42),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create assignment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Students submit their Google Drive link before deadline.',
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

class _LatePolicyCard extends StatelessWidget {
  const _LatePolicyCard({
    required this.policy,
    required this.penaltyController,
    required this.onPolicyChanged,
  });

  final String policy;
  final TextEditingController penaltyController;
  final ValueChanged<String> onPolicyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'After deadline',
            style: TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          RadioListTile<String>(
            value: 'block',
            groupValue: policy,
            onChanged: (value) => onPolicyChanged(value ?? 'block'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Do not allow submissions'),
            subtitle: const Text('Deadline පහු වුණාම submit කරන්න බැහැ.'),
          ),
          RadioListTile<String>(
            value: 'deduct',
            groupValue: policy,
            onChanged: (value) => onPolicyChanged(value ?? 'deduct'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow with mark deduction'),
            subtitle: const Text('Late submission එකට marks අඩු කරනවා.'),
          ),
          if (policy == 'deduct') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: penaltyController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (policy != 'deduct') {
                  return null;
                }
                final penalty = double.tryParse((value ?? '').trim());
                if (penalty == null || penalty < 0) {
                  return 'Deduct marks 0 හෝ ඊට වැඩි වෙන්න ඕන.';
                }
                return null;
              },
              decoration: _inputDecoration(
                label: 'Marks to deduct',
                icon: Icons.remove_circle_outline_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentCourseDropdown extends StatelessWidget {
  const _AssignmentCourseDropdown({
    required this.stream,
    required this.selectedCourseId,
    required this.enabled,
    required this.onSelected,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final String? selectedCourseId;
  final bool enabled;
  final ValueChanged<_AssignmentCourse> onSelected;

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
            .map(_AssignmentCourse.fromSnapshot)
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
              value == null && enabled ? 'Course එක select කරන්න.' : null,
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
          onChanged: enabled
              ? (courseId) {
                  if (courseId == null) {
                    return;
                  }

                  onSelected(
                    courses.firstWhere((course) => course.id == courseId),
                  );
                }
              : null,
        );
      },
    );
  }
}

class _AssignmentCourse {
  const _AssignmentCourse({
    required this.id,
    required this.name,
    required this.grade,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final String status;

  factory _AssignmentCourse.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _AssignmentCourse(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      status: _readString(data, 'status', 'active'),
    );
  }

  String get dropdownLabel {
    if (grade.isEmpty) {
      return name;
    }

    return '$name • $grade';
  }
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

String _numberLabel(double value) {
  final hasCents = value.truncateToDouble() != value;
  return value.toStringAsFixed(hasCents ? 2 : 0);
}

String _readString(
  Map<String, dynamic> data,
  String key,
  String fallback,
) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
}
