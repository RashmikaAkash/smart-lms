import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentQuizPage extends StatefulWidget {
  const StudentQuizPage({
    super.key,
    required this.teacherUid,
    required this.quizId,
  });

  final String teacherUid;
  final String quizId;

  @override
  State<StudentQuizPage> createState() => _StudentQuizPageState();
}

class _StudentQuizPageState extends State<StudentQuizPage> {
  final Map<String, int> _mcqAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  Timer? _timer;
  DateTime? _startedAt;
  int _remainingSeconds = 0;
  String? _loadedQuizId;
  bool _isSubmitting = false;
  bool _submittedByTimer = false;

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _quizReference {
    return FirebaseFirestore.instance
        .collection('teacher_quizzes')
        .doc(widget.teacherUid)
        .collection('quizzes')
        .doc(widget.quizId);
  }

  DocumentReference<Map<String, dynamic>>? get _submissionReference {
    final student = FirebaseAuth.instance.currentUser;
    if (student == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('quiz_submissions')
        .doc(widget.teacherUid)
        .collection('submissions')
        .doc('${widget.quizId}-${student.uid}');
  }

  void _prepareQuiz(_QuizData quiz, bool alreadySubmitted) {
    if (_loadedQuizId == quiz.id) {
      return;
    }

    _loadedQuizId = quiz.id;
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    _mcqAnswers.clear();

    for (final question in quiz.questions) {
      if (question.type == 'typed') {
        _textControllers[question.id] = TextEditingController();
      }
    }

    if (!alreadySubmitted) {
      _startedAt = DateTime.now();
      _remainingSeconds = quiz.timeLimitMinutes * 60;
      _startTimer(quiz);
    }
  }

  void _startTimer(_QuizData quiz) {
    _timer?.cancel();
    if (_remainingSeconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submittedByTimer = true;
        _submitQuiz(quiz);
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _submitQuiz(_QuizData quiz) async {
    if (_isSubmitting) {
      return;
    }

    final student = FirebaseAuth.instance.currentUser;
    final submission = _submissionReference;
    if (student == null || submission == null) {
      _showSnack('Student login needed.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final gradedAnswers = <Map<String, dynamic>>[];
      var score = 0.0;

      for (final question in quiz.questions) {
        final selectedIndex = _mcqAnswers[question.id];
        final typedAnswer = _textControllers[question.id]?.text.trim() ?? '';
        final givenAnswer = question.type == 'mcq'
            ? selectedIndex == null ||
                    selectedIndex < 0 ||
                    selectedIndex >= question.options.length
                ? ''
                : question.options[selectedIndex]
            : typedAnswer;
        final isCorrect = question.type == 'mcq'
            ? selectedIndex == question.correctOptionIndex
            : _normalizeAnswer(givenAnswer) ==
                _normalizeAnswer(question.correctAnswer);
        final awardedMarks = isCorrect ? question.marks : 0.0;
        score += awardedMarks;

        gradedAnswers.add({
          'questionId': question.id,
          'question': question.question,
          'type': question.type,
          'answer': givenAnswer,
          'selectedIndex': selectedIndex,
          'correctAnswer': question.correctAnswer,
          'isCorrect': isCorrect,
          'marks': question.marks,
          'awardedMarks': awardedMarks,
        });
      }

      final percent =
          quiz.totalMarks <= 0 ? 0 : ((score / quiz.totalMarks) * 100).round();

      await submission.set({
        'id': submission.id,
        'quizId': quiz.id,
        'quizTitle': quiz.title,
        'teacherUid': widget.teacherUid,
        'studentId': student.uid,
        'studentName': student.displayName ?? student.email ?? 'Student',
        'studentEmail': student.email ?? '',
        'courseId': quiz.courseId,
        'courseName': quiz.courseName,
        'lesson': quiz.lesson,
        'score': score,
        'totalMarks': quiz.totalMarks,
        'percent': percent,
        'answers': gradedAnswers,
        'submittedByTimer': _submittedByTimer,
        'startedAt': Timestamp.fromDate(_startedAt ?? DateTime.now()),
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _timer?.cancel();

      if (!mounted) {
        return;
      }

      _showSnack('Quiz submitted. Score: ${_marksLabel(score)}');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnack(
        error.code == 'permission-denied'
            ? 'Permission denied. Firestore quiz submission rules add කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnack('Quiz submit කරන්න බැරි වුණා.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submissionReference = _submissionReference;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Quiz',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: submissionReference == null
          ? const _QuizMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Student login needed',
              message: 'Quiz කරන්න student account එකෙන් login වෙන්න.',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _quizReference.snapshots(),
              builder: (context, quizSnapshot) {
                if (quizSnapshot.connectionState == ConnectionState.waiting &&
                    quizSnapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (quizSnapshot.hasError) {
                  return const _QuizMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Could not load quiz',
                    message: 'Firestore quiz read rules check කරන්න.',
                  );
                }

                final quizData = quizSnapshot.data?.data();
                if (quizData == null) {
                  return const _QuizMessage(
                    icon: Icons.quiz_outlined,
                    title: 'Quiz not found',
                    message: 'මේ quiz එක Firestore එකේ නැහැ.',
                  );
                }

                final quiz = _QuizData.fromMap(widget.quizId, quizData);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: submissionReference.snapshots(),
                  builder: (context, submissionSnapshot) {
                    final submissionData = submissionSnapshot.data?.data();
                    final submitted = submissionData != null;
                    _prepareQuiz(quiz, submitted);

                    if (submitted) {
                      _timer?.cancel();
                      return _QuizResultView(
                        quiz: quiz,
                        submission: _QuizSubmission.fromMap(submissionData),
                      );
                    }

                    return _QuizAttemptView(
                      quiz: quiz,
                      remainingSeconds: _remainingSeconds,
                      mcqAnswers: _mcqAnswers,
                      textControllers: _textControllers,
                      isSubmitting: _isSubmitting,
                      onSubmit: () => _submitQuiz(quiz),
                      onChanged: () => setState(() {}),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _QuizAttemptView extends StatelessWidget {
  const _QuizAttemptView({
    required this.quiz,
    required this.remainingSeconds,
    required this.mcqAnswers,
    required this.textControllers,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onChanged,
  });

  final _QuizData quiz;
  final int remainingSeconds;
  final Map<String, int> mcqAnswers;
  final Map<String, TextEditingController> textControllers;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        _QuizHeader(
          quiz: quiz,
          trailingLabel: _durationLabel(remainingSeconds),
          trailingColor:
              remainingSeconds <= 60 ? const Color(0xFFFF526B) : Colors.white,
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < quiz.questions.length; index++) ...[
          _QuestionAnswerCard(
            number: index + 1,
            question: quiz.questions[index],
            selectedIndex: mcqAnswers[quiz.questions[index].id],
            textController: textControllers[quiz.questions[index].id],
            onMcqChanged: (value) {
              if (value != null) {
                mcqAnswers[quiz.questions[index].id] = value;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(isSubmitting ? 'Submitting...' : 'Submit Quiz'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF316DFF),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizResultView extends StatelessWidget {
  const _QuizResultView({required this.quiz, required this.submission});

  final _QuizData quiz;
  final _QuizSubmission submission;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        _QuizHeader(
          quiz: quiz,
          trailingLabel: '${submission.percent}%',
          trailingColor: Colors.white,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE5F4)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFF9500),
                size: 42,
              ),
              const SizedBox(height: 10),
              const Text(
                'Quiz Completed',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_marksLabel(submission.score)} / ${_marksLabel(submission.totalMarks)}',
                style: const TextStyle(
                  color: Color(0xFF316DFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${submission.percent}% score',
                style: const TextStyle(
                  color: Color(0xFF60708F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({
    required this.quiz,
    required this.trailingLabel,
    required this.trailingColor,
  });

  final _QuizData quiz;
  final String trailingLabel;
  final Color trailingColor;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${quiz.courseName} • ${quiz.lesson}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz.questions.length} questions • ${_marksLabel(quiz.totalMarks)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              trailingLabel,
              style: TextStyle(
                color: trailingColor,
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

class _QuestionAnswerCard extends StatelessWidget {
  const _QuestionAnswerCard({
    required this.number,
    required this.question,
    required this.selectedIndex,
    required this.textController,
    required this.onMcqChanged,
  });

  final int number;
  final _QuizQuestion question;
  final int? selectedIndex;
  final TextEditingController? textController;
  final ValueChanged<int?> onMcqChanged;

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
                    color: Color(0xFF60708F),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _marksLabel(question.marks),
                style: const TextStyle(
                  color: Color(0xFF316DFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: const TextStyle(
              color: Color(0xFF071B3C),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (question.type == 'mcq')
            for (var index = 0; index < question.options.length; index++)
              RadioListTile<int>(
                value: index,
                groupValue: selectedIndex,
                onChanged: onMcqChanged,
                contentPadding: EdgeInsets.zero,
                title: Text(question.options[index]),
              )
          else
            TextField(
              controller: textController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Type your answer',
                filled: true,
                fillColor: const Color(0xFFF6F8FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizMessage extends StatelessWidget {
  const _QuizMessage({
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

class _QuizData {
  const _QuizData({
    required this.id,
    required this.title,
    required this.lesson,
    required this.courseId,
    required this.courseName,
    required this.timeLimitMinutes,
    required this.totalMarks,
    required this.questions,
  });

  final String id;
  final String title;
  final String lesson;
  final String courseId;
  final String courseName;
  final int timeLimitMinutes;
  final double totalMarks;
  final List<_QuizQuestion> questions;

  factory _QuizData.fromMap(String id, Map<String, dynamic> data) {
    final questions = <_QuizQuestion>[];
    final rawQuestions = data['questions'];
    if (rawQuestions is Iterable) {
      for (final item in rawQuestions) {
        final question = _QuizQuestion.tryParse(item);
        if (question != null) {
          questions.add(question);
        }
      }
    }

    return _QuizData(
      id: id,
      title: _readString(data, 'title', 'Quiz'),
      lesson: _readString(data, 'lesson', ''),
      courseId: _readString(data, 'courseId', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      timeLimitMinutes: _readInt(data, 'timeLimitMinutes', 30),
      totalMarks: _readDouble(data, 'totalMarks'),
      questions: List.unmodifiable(questions),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.marks,
    required this.options,
    required this.correctOptionIndex,
    required this.correctAnswer,
  });

  final String id;
  final String type;
  final String question;
  final double marks;
  final List<String> options;
  final int correctOptionIndex;
  final String correctAnswer;

  static _QuizQuestion? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }

    final data = <String, dynamic>{};
    value.forEach((key, value) {
      data[key.toString()] = value;
    });
    final question = _readString(data, 'question', '');
    if (question.isEmpty) {
      return null;
    }

    return _QuizQuestion(
      id: _readString(data, 'id', question.hashCode.toString()),
      type: _readString(data, 'type', 'mcq'),
      question: question,
      marks: _readDouble(data, 'marks'),
      options: _readStringList(data, 'options'),
      correctOptionIndex: _readInt(data, 'correctOptionIndex', -1),
      correctAnswer: _readString(data, 'correctAnswer', ''),
    );
  }
}

class _QuizSubmission {
  const _QuizSubmission({
    required this.score,
    required this.totalMarks,
    required this.percent,
  });

  final double score;
  final double totalMarks;
  final int percent;

  factory _QuizSubmission.fromMap(Map<String, dynamic> data) {
    return _QuizSubmission(
      score: _readDouble(data, 'score'),
      totalMarks: _readDouble(data, 'totalMarks'),
      percent: _readInt(data, 'percent', 0),
    );
  }
}

String _durationLabel(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _marksLabel(double marks) {
  final hasCents = marks.truncateToDouble() != marks;
  return '${marks.toStringAsFixed(hasCents ? 1 : 0)} marks';
}

String _normalizeAnswer(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
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
