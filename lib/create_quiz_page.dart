import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateQuizPage extends StatefulWidget {
  const CreateQuizPage({
    super.key,
    this.initialCourseId,
    this.initialCourseName,
    this.initialCourseGrade,
    this.quizId,
    this.initialTitle,
    this.initialLesson,
    this.initialTimeLimitMinutes,
    this.initialQuestions,
    this.lockCourse = false,
  });

  final String? initialCourseId;
  final String? initialCourseName;
  final String? initialCourseGrade;
  final String? quizId;
  final String? initialTitle;
  final String? initialLesson;
  final int? initialTimeLimitMinutes;
  final List<Map<String, dynamic>>? initialQuestions;
  final bool lockCourse;

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _lessonController = TextEditingController();
  final _timeController = TextEditingController(text: '30');
  final List<_QuestionDraft> _questions = [];

  _TeacherQuizCourse? _selectedCourse;
  late String? _selectedCourseId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.initialCourseId;
    _titleController.text = widget.initialTitle ?? '';
    _lessonController.text = widget.initialLesson ?? '';
    if (widget.initialTimeLimitMinutes != null) {
      _timeController.text = widget.initialTimeLimitMinutes.toString();
    }
    final initialQuestions = widget.initialQuestions ?? const [];
    if (initialQuestions.isEmpty) {
      _questions.add(_QuestionDraft.mcq());
    } else {
      _questions.addAll(initialQuestions.map(_QuestionDraft.fromMap));
    }
    if (widget.initialCourseId?.isNotEmpty == true) {
      _selectedCourse = _TeacherQuizCourse(
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
    _lessonController.dispose();
    _timeController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
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

  double get _totalMarks {
    return _questions.fold<double>(
      0,
      (total, question) => total + question.marks,
    );
  }

  Future<void> _saveQuiz() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    final course = _selectedCourse;
    if (teacher == null || course == null) {
      setState(() {
        _errorMessage = 'Teacher login සහ course select කරන්න.';
      });
      return;
    }

    final validationError = _validateQuestions();
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final quizzesCollection = FirebaseFirestore.instance
          .collection('teacher_quizzes')
          .doc(teacher.uid)
          .collection('quizzes');
      final quizReference = widget.quizId?.isNotEmpty == true
          ? quizzesCollection.doc(widget.quizId)
          : quizzesCollection.doc();
      final isEdit = widget.quizId?.isNotEmpty == true;
      final questionData = <Map<String, dynamic>>[];

      for (var index = 0; index < _questions.length; index++) {
        questionData.add(_questions[index].toFirestore(index));
      }

      await quizReference.set({
        'id': quizReference.id,
        'teacherUid': teacher.uid,
        'teacherEmail': teacher.email ?? '',
        'title': _titleController.text.trim(),
        'lesson': _lessonController.text.trim(),
        'courseId': course.id,
        'courseName': course.name,
        'grade': course.grade,
        'timeLimitMinutes': int.parse(_timeController.text.trim()),
        'totalMarks': _totalMarks,
        'questionCount': questionData.length,
        'questions': questionData,
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
            isEdit ? 'Quiz updated successfully.' : 'Quiz created successfully.',
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
            ? 'Permission denied. Firestore quiz rules add කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Quiz save කරන්න බැරි වුණා.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateQuestions() {
    if (_questions.isEmpty) {
      return 'අවම වශයෙන් question එකක් add කරන්න.';
    }

    for (var index = 0; index < _questions.length; index++) {
      final question = _questions[index];
      final number = index + 1;

      if (question.questionText.isEmpty) {
        return 'Question $number text එක දාන්න.';
      }
      if (question.marks <= 0) {
        return 'Question $number marks 0ට වැඩි වෙන්න ඕන.';
      }
      if (question.type == _QuestionType.mcq) {
        final options = question.options;
        if (options.length < 2) {
          return 'Question $number MCQ answers දෙකක්වත් දාන්න.';
        }
        if (options.any((option) => option.isEmpty)) {
          return 'Question $number හි empty answers තියෙනවා.';
        }
        if (question.correctOptionIndex < 0 ||
            question.correctOptionIndex >= options.length) {
          return 'Question $number correct answer select කරන්න.';
        }
      } else if (question.correctTextAnswer.isEmpty) {
        return 'Question $number correct answer දාන්න.';
      }
    }

    return null;
  }

  void _addQuestion(_QuestionType type) {
    setState(() {
      _questions.add(
        type == _QuestionType.mcq
            ? _QuestionDraft.mcq()
            : _QuestionDraft.typed(),
      );
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) {
      setState(() {
        _errorMessage = 'අවම වශයෙන් question එකක් තියෙන්න ඕන.';
      });
      return;
    }

    final removed = _questions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.quizId?.isNotEmpty == true ? 'Edit Quiz' : 'Create Quiz',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: [
            _HeroCard(
                totalMarks: _totalMarks, questionCount: _questions.length),
            const SizedBox(height: 16),
            _QuizSetupCard(
              titleController: _titleController,
              lessonController: _lessonController,
              timeController: _timeController,
              coursesStream: _coursesStream,
              selectedCourseId: _selectedCourseId,
              lockCourse: widget.lockCourse,
              onCourseSelected: (course) {
                setState(() {
                  _selectedCourse = course;
                  _selectedCourseId = course.id;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Questions',
                    style: TextStyle(
                      color: Color(0xFF071B3C),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_totalMarks.toStringAsFixed(_totalMarks.truncateToDouble() == _totalMarks ? 0 : 1)} marks',
                  style: const TextStyle(
                    color: Color(0xFF316DFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _questions.length; index++) ...[
              _QuestionCard(
                number: index + 1,
                question: _questions[index],
                onChanged: () => setState(() {}),
                onRemove: () => _removeQuestion(index),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addQuestion(_QuestionType.mcq),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Add MCQ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addQuestion(_QuestionType.typed),
                    icon: const Icon(Icons.short_text_rounded),
                    label: const Text('Add Typed'),
                  ),
                ),
              ],
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
              onPressed: _isSaving ? null : _saveQuiz,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.quiz_rounded),
              label: Text(
                _isSaving
                    ? 'Saving Quiz...'
                    : widget.quizId?.isNotEmpty == true
                        ? 'Update Quiz'
                        : 'Publish Quiz',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF316DFF),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.totalMarks, required this.questionCount});

  final double totalMarks;
  final int questionCount;

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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build a smart quiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$questionCount questions • ${_marksLabel(totalMarks)}',
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

class _QuizSetupCard extends StatelessWidget {
  const _QuizSetupCard({
    required this.titleController,
    required this.lessonController,
    required this.timeController,
    required this.coursesStream,
    required this.selectedCourseId,
    required this.lockCourse,
    required this.onCourseSelected,
  });

  final TextEditingController titleController;
  final TextEditingController lessonController;
  final TextEditingController timeController;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? coursesStream;
  final String? selectedCourseId;
  final bool lockCourse;
  final ValueChanged<_TeacherQuizCourse> onCourseSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Quiz title දාන්න.' : null,
            decoration: _inputDecoration(
              label: 'Quiz title',
              icon: Icons.drive_file_rename_outline_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: lessonController,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Lesson / padama දාන්න.' : null,
            decoration: _inputDecoration(
              label: 'Lesson / padama',
              icon: Icons.auto_stories_outlined,
            ),
          ),
          const SizedBox(height: 12),
          _CourseDropdown(
            stream: coursesStream,
            selectedCourseId: selectedCourseId,
            enabled: !lockCourse,
            onSelected: onCourseSelected,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: timeController,
            keyboardType: TextInputType.number,
            validator: (value) {
              final minutes = int.tryParse((value ?? '').trim());
              if (minutes == null || minutes <= 0) {
                return 'Time minutes වලින් දාන්න.';
              }
              return null;
            },
            decoration: _inputDecoration(
              label: 'Time limit (minutes)',
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseDropdown extends StatelessWidget {
  const _CourseDropdown({
    required this.stream,
    required this.selectedCourseId,
    required this.enabled,
    required this.onSelected,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final String? selectedCourseId;
  final bool enabled;
  final ValueChanged<_TeacherQuizCourse> onSelected;

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
            .map(_TeacherQuizCourse.fromSnapshot)
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.onChanged,
    required this.onRemove,
  });

  final int number;
  final _QuestionDraft question;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question $number',
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TypeChip(type: question.type),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFFF526B),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: question.questionController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Question text',
              icon: Icons.help_outline_rounded,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: question.marksController,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: _inputDecoration(
              label: 'Marks for this question',
              icon: Icons.grade_outlined,
            ),
          ),
          const SizedBox(height: 12),
          if (question.type == _QuestionType.mcq)
            _McqEditor(question: question, onChanged: onChanged)
          else
            TextFormField(
              controller: question.correctAnswerController,
              decoration: _inputDecoration(
                label: 'Correct typed answer',
                icon: Icons.check_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

class _McqEditor extends StatelessWidget {
  const _McqEditor({required this.question, required this.onChanged});

  final _QuestionDraft question;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Answers',
          style: TextStyle(
            color: Color(0xFF60708F),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < question.optionControllers.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<int>(
                  value: index,
                  groupValue: question.correctOptionIndex,
                  onChanged: (value) {
                    question.correctOptionIndex = value ?? index;
                    onChanged();
                  },
                ),
                Expanded(
                  child: TextFormField(
                    controller: question.optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Answer ${index + 1}',
                      filled: true,
                      fillColor: const Color(0xFFF6F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove answer',
                  onPressed: question.optionControllers.length <= 2
                      ? null
                      : () {
                          question.removeOption(index);
                          onChanged();
                        },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              question.addOption();
              onChanged();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add answer'),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final _QuestionType type;

  @override
  Widget build(BuildContext context) {
    final isMcq = type == _QuestionType.mcq;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (isMcq ? const Color(0xFF316DFF) : const Color(0xFF00A86B))
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isMcq ? 'MCQ' : 'Typed',
        style: TextStyle(
          color: isMcq ? const Color(0xFF316DFF) : const Color(0xFF00A86B),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeacherQuizCourse {
  const _TeacherQuizCourse({
    required this.id,
    required this.name,
    required this.grade,
    required this.status,
  });

  final String id;
  final String name;
  final String grade;
  final String status;

  factory _TeacherQuizCourse.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _TeacherQuizCourse(
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

enum _QuestionType { mcq, typed }

class _QuestionDraft {
  _QuestionDraft._({required this.type});

  factory _QuestionDraft.mcq() {
    return _QuestionDraft._(type: _QuestionType.mcq)
      ..optionControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
  }

  factory _QuestionDraft.typed() {
    return _QuestionDraft._(type: _QuestionType.typed);
  }

  factory _QuestionDraft.fromMap(Map<String, dynamic> data) {
    final typeValue = _readString(data, 'type', 'mcq').toLowerCase();
    final draft = typeValue == 'typed'
        ? _QuestionDraft.typed()
        : _QuestionDraft._(type: _QuestionType.mcq);
    final options = _readStringList(data, 'options');

    draft.questionController.text = _readString(data, 'question', '');
    draft.marksController.text = _numberLabel(_readDouble(data, 'marks', 1));

    if (draft.type == _QuestionType.mcq) {
      final savedOptions =
          options.length >= 2 ? options : const ['', '', '', ''];
      draft.optionControllers.addAll(
        savedOptions.map((option) => TextEditingController(text: option)),
      );
      final correctAnswer = _readString(data, 'correctAnswer', '');
      final savedIndex = _readInt(data, 'correctOptionIndex', -1);
      final answerIndex = savedOptions.indexWhere(
        (option) => option.trim().toLowerCase() ==
            correctAnswer.trim().toLowerCase(),
      );
      draft.correctOptionIndex = savedIndex >= 0
          ? savedIndex
              .clamp(0, draft.optionControllers.length - 1)
              .toInt()
          : answerIndex >= 0
              ? answerIndex
              : 0;
    } else {
      draft.correctAnswerController.text = _readString(
        data,
        'correctAnswer',
        '',
      );
    }

    return draft;
  }

  final _QuestionType type;
  final questionController = TextEditingController();
  final marksController = TextEditingController(text: '1');
  final correctAnswerController = TextEditingController();
  final List<TextEditingController> optionControllers = [];
  int correctOptionIndex = 0;

  String get questionText => questionController.text.trim();

  double get marks {
    return double.tryParse(marksController.text.trim()) ?? 0;
  }

  List<String> get options {
    return optionControllers
        .map((controller) => controller.text.trim())
        .toList();
  }

  String get correctTextAnswer => correctAnswerController.text.trim();

  void addOption() {
    optionControllers.add(TextEditingController());
  }

  void removeOption(int index) {
    if (index < 0 || index >= optionControllers.length) {
      return;
    }

    optionControllers.removeAt(index).dispose();
    if (correctOptionIndex >= optionControllers.length) {
      correctOptionIndex = optionControllers.length - 1;
    }
  }

  Map<String, dynamic> toFirestore(int index) {
    final savedOptions = options;
    final correctAnswer = type == _QuestionType.mcq
        ? savedOptions[correctOptionIndex]
        : correctTextAnswer;

    return {
      'id': 'q${index + 1}',
      'type': type == _QuestionType.mcq ? 'mcq' : 'typed',
      'question': questionText,
      'marks': marks,
      'options': type == _QuestionType.mcq ? savedOptions : <String>[],
      'correctOptionIndex': type == _QuestionType.mcq ? correctOptionIndex : -1,
      'correctAnswer': correctAnswer,
    };
  }

  void dispose() {
    questionController.dispose();
    marksController.dispose();
    correctAnswerController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
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

String _marksLabel(double marks) {
  final hasCents = marks.truncateToDouble() != marks;
  return '${marks.toStringAsFixed(hasCents ? 1 : 0)} marks';
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

double _readDouble(Map<String, dynamic> data, String key, double fallback) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _readInt(Map<String, dynamic> data, String key, int fallback) {
  final value = data[key];
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
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
