import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UploadMaterialSheet extends StatefulWidget {
  const UploadMaterialSheet({
    super.key,
    this.initialCourseId,
    this.initialCourseName,
    this.initialCourseGrade,
    this.materialId,
    this.initialTitle,
    this.initialDescription,
    this.initialLink,
    this.initialType,
    this.lockCourse = false,
  });

  final String? initialCourseId;
  final String? initialCourseName;
  final String? initialCourseGrade;
  final String? materialId;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialLink;
  final String? initialType;
  final bool lockCourse;

  @override
  State<UploadMaterialSheet> createState() => _UploadMaterialSheetState();
}

class _UploadMaterialSheetState extends State<UploadMaterialSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  _MaterialCourse? _selectedCourse;
  String? _selectedCourseId;
  String _materialType = 'note';
  bool _isSaving = false;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
    _titleController.text = widget.initialTitle ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _linkController.text = widget.initialLink ?? '';
    _materialType = widget.initialType ?? 'note';
    if (widget.initialCourseId != null && widget.initialCourseName != null) {
      _selectedCourse = _MaterialCourse(
        id: widget.initialCourseId!,
        name: widget.initialCourseName!,
        grade: widget.initialCourseGrade ?? '',
        status: 'active',
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveMaterialLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedCourse = _selectedCourse;
    if (selectedCourse == null) {
      setState(() {
        _errorMessage = 'Course එකක් select කරන්න.';
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

      final link = _linkController.text.trim();
      final materialsCollection = FirebaseFirestore.instance
          .collection('teacher_materials')
          .doc(teacher.uid)
          .collection('materials');
      final materialReference = widget.materialId?.isNotEmpty == true
          ? materialsCollection.doc(widget.materialId)
          : materialsCollection.doc();
      final isEdit = widget.materialId?.isNotEmpty == true;

      await materialReference.set({
        'id': materialReference.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _materialType,
        'sourceType': 'link',
        'link': link,
        'externalLink': link,
        'downloadUrl': '',
        'storagePath': '',
        'storageBucket': '',
        'fileName': '',
        'fileSize': 0,
        'contentType': '',
        'courseId': selectedCourse.id,
        'courseName': selectedCourse.name,
        'grade': selectedCourse.grade,
        'status': 'active',
        'sourceStatus': 'ready',
        'teacherUid': teacher.uid,
        'teacherEmail': teacher.email,
        if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? '${_titleController.text.trim()} updated.'
                : '${_titleController.text.trim()} saved.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore permission denied. Material rules check කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Material link save කරන්න බැරි වුණා.';
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

  String? _validateLink(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Material link is required.';
    }

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Valid link එකක් දාන්න.';
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DFEC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _UploadHeader(
                  type: _materialType,
                  isEdit: widget.materialId?.isNotEmpty == true,
                ),
                const SizedBox(height: 16),
                _buildCoursePicker(),
                const SizedBox(height: 14),
                const _FieldLabel('Material type'),
                const SizedBox(height: 8),
                _MaterialTypeSelector(
                  selectedType: _materialType,
                  onChanged: (type) {
                    setState(() {
                      _materialType = type;
                    });
                  },
                ),
                const SizedBox(height: 14),
                const _LinkHelpCard(),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: _validateLink,
                  decoration: _inputDecoration(
                    label: 'Material link',
                    icon: Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _required(value, 'Title'),
                  decoration: _inputDecoration(
                    label: 'Material title',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    label: 'Short description',
                    icon: Icons.description_outlined,
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
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveMaterialLink,
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
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : widget.materialId?.isNotEmpty == true
                            ? 'Update Material'
                            : 'Save Material Link',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF316DFF),
                    disabledBackgroundColor: const Color(0xFF9BB6FF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
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

  Widget _buildCoursePicker() {
    if (widget.lockCourse && _selectedCourse != null) {
      return _LockedCourseCard(course: _selectedCourse!);
    }

    final coursesStream = _coursesStream;
    if (coursesStream == null) {
      return _disabledField('Teacher login needed');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coursesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _disabledField('Loading courses...');
        }

        final courses = (snapshot.data?.docs ?? [])
            .map(_MaterialCourse.fromSnapshot)
            .where((course) => course.status != 'archived')
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name));

        if (courses.isEmpty) {
          return _disabledField('Create a course first');
        }

        if (_selectedCourseId != null && _selectedCourse == null) {
          for (final course in courses) {
            if (course.id == _selectedCourseId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _selectedCourse = course;
                });
              });
              break;
            }
          }
        }

        final selectedValue =
            courses.any((course) => course.id == _selectedCourseId)
                ? _selectedCourseId
                : null;

        return DropdownButtonFormField<String>(
          value: selectedValue,
          isExpanded: true,
          validator: (value) => value == null ? 'Course is required.' : null,
          decoration: _inputDecoration(
            label: 'Course',
            icon: Icons.menu_book_outlined,
          ),
          hint: const Text('Select course'),
          items: courses.map((course) {
            return DropdownMenuItem<String>(
              value: course.id,
              child: Text(
                course.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (courseId) {
                  if (courseId == null) {
                    return;
                  }
                  final course = courses.firstWhere(
                    (course) => course.id == courseId,
                  );
                  setState(() {
                    _selectedCourseId = course.id;
                    _selectedCourse = course;
                  });
                },
        );
      },
    );
  }

  Widget _disabledField(String label) {
    return TextFormField(
      enabled: false,
      decoration: _inputDecoration(
        label: label,
        icon: Icons.menu_book_outlined,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6F7E9A)),
      filled: true,
      fillColor: Colors.white,
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

class _UploadHeader extends StatelessWidget {
  const _UploadHeader({required this.type, required this.isEdit});

  final String type;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final config = _MaterialTypeConfig.forType(type);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D5BEA),
            Color(0xFF7048E8),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(config.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Update Course Material' : 'Save Course Material',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Google Drive / YouTube / website links course එකට attach කරන්න.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF071B3C),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LinkHelpCard extends StatelessWidget {
  const _LinkHelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD1FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF316DFF), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'File එක Google Drive එකට upload කරලා “Anyone with link” දාලා link එක මෙතන paste කරන්න.',
              style: TextStyle(
                color: Color(0xFF31527F),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCourseCard extends StatelessWidget {
  const _LockedCourseCard({required this.course});

  final _MaterialCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF316DFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected course',
                  style: TextStyle(
                    color: Color(0xFF7A879F),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: Color(0xFF9AA6BB), size: 18),
        ],
      ),
    );
  }
}

class _MaterialTypeSelector extends StatelessWidget {
  const _MaterialTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const types = ['note', 'tute', 'video', 'pdf', 'link'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in types)
          _MaterialTypeChip(
            type: type,
            isSelected: selectedType == type,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _MaterialTypeChip extends StatelessWidget {
  const _MaterialTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = _MaterialTypeConfig.forType(type);

    return Material(
      color: isSelected ? config.color : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? config.color : const Color(0xFFE2E8F4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                config.icon,
                size: 17,
                color: isSelected ? Colors.white : config.color,
              ),
              const SizedBox(width: 7),
              Text(
                config.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF071B3C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCourse {
  const _MaterialCourse({
    required this.id,
    required this.name,
    required this.grade,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final String status;

  factory _MaterialCourse.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _MaterialCourse(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Course'),
      grade: _readString(data, 'grade', ''),
      status: _readString(data, 'status', 'active'),
    );
  }

  String get label => grade.isEmpty ? name : '$name • $grade';
}

class _MaterialTypeConfig {
  const _MaterialTypeConfig({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static _MaterialTypeConfig forType(String type) {
    switch (type) {
      case 'tute':
        return const _MaterialTypeConfig(
          label: 'Tute',
          icon: Icons.assignment_outlined,
          color: Color(0xFF7048E8),
        );
      case 'video':
        return const _MaterialTypeConfig(
          label: 'Video',
          icon: Icons.play_circle_outline_rounded,
          color: Color(0xFFFF3B6B),
        );
      case 'pdf':
        return const _MaterialTypeConfig(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          color: Color(0xFFFF9500),
        );
      case 'link':
        return const _MaterialTypeConfig(
          label: 'Link',
          icon: Icons.link_rounded,
          color: Color(0xFF0FAF75),
        );
      default:
        return const _MaterialTypeConfig(
          label: 'Note',
          icon: Icons.article_outlined,
          color: Color(0xFF316DFF),
        );
    }
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
