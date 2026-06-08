import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'course_schedule_utils.dart';

class CreateCourseSheet extends StatefulWidget {
  const CreateCourseSheet({super.key});

  @override
  State<CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<CreateCourseSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final Map<String, TextEditingController> _startTimeControllers = {};
  final Map<String, TextEditingController> _endTimeControllers = {};
  final Set<String> _selectedDays = <String>{};

  String _courseType = 'group';
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

      final name = _nameController.text.trim();
      final grade = _gradeController.text.trim();
      final fee = double.parse(_feeController.text.trim().replaceAll(',', ''));
      final location = _locationController.text.trim();
      final orderedDays =
          _days.where((day) => _selectedDays.contains(day)).toList();
      final scheduleSlots = _buildScheduleSlots(orderedDays);
      final scheduleTime = courseScheduleTimeFromSlots(scheduleSlots);
      final scheduleLabel = courseScheduleLabel(
        scheduleDays: orderedDays,
        scheduleTime: scheduleTime,
        scheduleSlots: scheduleSlots,
      );
      final conflict = await findCourseScheduleConflict(
        teacherUid: teacher.uid,
        scheduleSlots: scheduleSlots,
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
          .doc();

      await courseReference.set({
        'id': courseReference.id,
        'name': name,
        'grade': grade,
        'classFee': fee,
        'type': _courseType,
        'location': location,
        'scheduleDays': orderedDays,
        'scheduleTime': scheduleTime,
        'scheduleSlots': scheduleSlots.map((slot) => slot.toMap()).toList(),
        'scheduleLabel': scheduleLabel,
        'status': 'active',
        'teacherUid': teacher.uid,
        'teacherEmail': teacher.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name course created.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore permission denied. Course rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Course create කරන්න බැරි උනා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  'Create Course',
                  style: TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Course එක create කළාම student register dropdown එකේ පේනවා.',
                  style: TextStyle(
                    color: Color(0xFF6C7892),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
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
                    'Class days select කළාම ඒ ඒ දවසට time දාන්න පුළුවන්.',
                    style: TextStyle(
                      color: Color(0xFF66748F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  for (final day
                      in _days.where((day) => _selectedDays.contains(day))) ...[
                    _DayTimeRow(
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
                FilledButton(
                  onPressed: _isSaving ? null : _saveCourse,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    disabledBackgroundColor: const Color(0xFF9BB6FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Course',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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
            child: _TypeOption(
              label: 'Group',
              value: 'group',
              selectedType: selectedType,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TypeOption(
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF316DFF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF316DFF) : const Color(0xFFDDE5F4),
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
    );
  }
}

class _DayTimeRow extends StatelessWidget {
  const _DayTimeRow({
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
                child: _TimeField(
                  controller: startController,
                  label: 'Start',
                  validator: startValidator,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeField(
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

class _TimeField extends StatelessWidget {
  const _TimeField({
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

class _TypeOption extends StatelessWidget {
  const _TypeOption({
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
