import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String _courseType = 'group';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _feeController.dispose();
    _locationController.dispose();
    super.dispose();
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
                  textInputAction: TextInputAction.done,
                  validator: (value) => _required(value, 'Location'),
                  decoration: _inputDecoration(
                    label: 'Location',
                    icon: Icons.location_on_outlined,
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
