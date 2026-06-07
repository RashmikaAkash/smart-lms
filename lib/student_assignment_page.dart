import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentAssignmentPage extends StatefulWidget {
  const StudentAssignmentPage({
    super.key,
    required this.teacherUid,
    required this.assignmentId,
  });

  final String teacherUid;
  final String assignmentId;

  @override
  State<StudentAssignmentPage> createState() => _StudentAssignmentPageState();
}

class _StudentAssignmentPageState extends State<StudentAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _assignmentReference {
    return FirebaseFirestore.instance
        .collection('teacher_assignments')
        .doc(widget.teacherUid)
        .collection('assignments')
        .doc(widget.assignmentId);
  }

  DocumentReference<Map<String, dynamic>>? get _submissionReference {
    final student = FirebaseAuth.instance.currentUser;
    if (student == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('assignment_submissions')
        .doc(widget.teacherUid)
        .collection('submissions')
        .doc('${widget.assignmentId}-${student.uid}');
  }

  Future<void> _submitAssignment(_AssignmentData assignment) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final student = FirebaseAuth.instance.currentUser;
    final submission = _submissionReference;
    if (student == null || submission == null) {
      _showSnack('Student login needed.');
      return;
    }

    final now = DateTime.now();
    final isLate =
        assignment.deadline != null && now.isAfter(assignment.deadline!);
    if (isLate && assignment.latePolicy == 'block') {
      _showSnack('Deadline passed. Submission closed.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final effectiveMaxMarks = isLate
          ? (assignment.maxMarks - assignment.latePenaltyMarks)
              .clamp(0, assignment.maxMarks)
          : assignment.maxMarks;

      await submission.set({
        'id': submission.id,
        'assignmentId': assignment.id,
        'assignmentTitle': assignment.title,
        'teacherUid': widget.teacherUid,
        'studentId': student.uid,
        'studentName': student.displayName ?? student.email ?? 'Student',
        'studentEmail': student.email ?? '',
        'courseId': assignment.courseId,
        'courseName': assignment.courseName,
        'driveLink': _linkController.text.trim(),
        'maxMarks': assignment.maxMarks,
        'isLate': isLate,
        'latePolicy': assignment.latePolicy,
        'latePenaltyMarks': isLate ? assignment.latePenaltyMarks : 0,
        'effectiveMaxMarks': effectiveMaxMarks,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      _showSnack('Assignment submitted successfully.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnack(
        error.code == 'permission-denied'
            ? 'Permission denied. Assignment submission rules add කරන්න.'
            : 'Firebase error: ${error.message ?? error.code}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnack('Assignment submit කරන්න බැරි වුණා.');
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
          'Assignment',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: submissionReference == null
          ? const _AssignmentMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Student login needed',
              message:
                  'Assignment submit කරන්න student account එකෙන් login වෙන්න.',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _assignmentReference.snapshots(),
              builder: (context, assignmentSnapshot) {
                if (assignmentSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    assignmentSnapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (assignmentSnapshot.hasError) {
                  return const _AssignmentMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Could not load assignment',
                    message: 'Firestore assignment read rules check කරන්න.',
                  );
                }

                final assignmentData = assignmentSnapshot.data?.data();
                if (assignmentData == null) {
                  return const _AssignmentMessage(
                    icon: Icons.assignment_outlined,
                    title: 'Assignment not found',
                    message: 'මේ assignment එක Firestore එකේ නැහැ.',
                  );
                }

                final assignment = _AssignmentData.fromMap(
                    widget.assignmentId, assignmentData);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: submissionReference.snapshots(),
                  builder: (context, submissionSnapshot) {
                    final submissionData = submissionSnapshot.data?.data();
                    final submitted = submissionData != null;

                    if (submitted) {
                      return _AssignmentSubmittedView(
                        assignment: assignment,
                        submission:
                            _AssignmentSubmission.fromMap(submissionData),
                      );
                    }

                    return _AssignmentSubmitView(
                      assignment: assignment,
                      formKey: _formKey,
                      linkController: _linkController,
                      isSubmitting: _isSubmitting,
                      onSubmit: () => _submitAssignment(assignment),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AssignmentSubmitView extends StatelessWidget {
  const _AssignmentSubmitView({
    required this.assignment,
    required this.formKey,
    required this.linkController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final _AssignmentData assignment;
  final GlobalKey<FormState> formKey;
  final TextEditingController linkController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLate =
        assignment.deadline != null && now.isAfter(assignment.deadline!);
    final blocked = isLate && assignment.latePolicy == 'block';

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          _AssignmentHeader(assignment: assignment),
          const SizedBox(height: 16),
          _InstructionsCard(assignment: assignment),
          const SizedBox(height: 16),
          if (blocked)
            const _AssignmentMessage(
              icon: Icons.lock_clock_rounded,
              title: 'Deadline passed',
              message: 'මේ assignment එක deadline පහු වුණා. Submission closed.',
            )
          else ...[
            if (isLate) _LateWarningCard(assignment: assignment),
            if (isLate) const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDDE5F4)),
              ),
              child: TextFormField(
                controller: linkController,
                keyboardType: TextInputType.url,
                validator: (value) {
                  final link = (value ?? '').trim();
                  final uri = Uri.tryParse(link);
                  if (uri == null ||
                      !uri.hasAbsolutePath ||
                      !(link.startsWith('http://') ||
                          link.startsWith('https://'))) {
                    return 'Google Drive link එක paste කරන්න.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Google Drive link',
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF6F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isSubmitting ? 'Submitting...' : 'Submit Assignment'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7048E8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentSubmittedView extends StatelessWidget {
  const _AssignmentSubmittedView({
    required this.assignment,
    required this.submission,
  });

  final _AssignmentData assignment;
  final _AssignmentSubmission submission;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        _AssignmentHeader(assignment: assignment),
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
              Icon(
                submission.isLate
                    ? Icons.warning_amber_rounded
                    : Icons.done_rounded,
                color: submission.isLate
                    ? const Color(0xFFFF9500)
                    : const Color(0xFF00A86B),
                size: 42,
              ),
              const SizedBox(height: 10),
              const Text(
                'Assignment Submitted',
                style: TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                submission.driveLink,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF316DFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                submission.isLate
                    ? 'Late submission • max ${_marksLabel(submission.effectiveMaxMarks)}'
                    : 'On time • max ${_marksLabel(submission.effectiveMaxMarks)}',
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

class _AssignmentHeader extends StatelessWidget {
  const _AssignmentHeader({required this.assignment});

  final _AssignmentData assignment;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${assignment.courseName} • ${_marksLabel(assignment.maxMarks)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Deadline: ${assignment.deadlineLabel}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.assignment});

  final _AssignmentData assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Text(
        assignment.instructions,
        style: const TextStyle(
          color: Color(0xFF071B3C),
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LateWarningCard extends StatelessWidget {
  const _LateWarningCard({required this.assignment});

  final _AssignmentData assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD199)),
      ),
      child: Text(
        'Deadline passed. Submit කරන්න පුළුවන්, හැබැයි ${_marksLabel(assignment.latePenaltyMarks)} අඩු වෙනවා.',
        style: const TextStyle(
          color: Color(0xFFFF6B00),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AssignmentMessage extends StatelessWidget {
  const _AssignmentMessage({
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

class _AssignmentData {
  const _AssignmentData({
    required this.id,
    required this.title,
    required this.instructions,
    required this.courseId,
    required this.courseName,
    required this.deadline,
    required this.maxMarks,
    required this.latePolicy,
    required this.latePenaltyMarks,
  });

  final String id;
  final String title;
  final String instructions;
  final String courseId;
  final String courseName;
  final DateTime? deadline;
  final double maxMarks;
  final String latePolicy;
  final double latePenaltyMarks;

  factory _AssignmentData.fromMap(String id, Map<String, dynamic> data) {
    final deadline = data['deadline'];
    return _AssignmentData(
      id: id,
      title: _readString(data, 'title', 'Assignment'),
      instructions: _readString(data, 'instructions', ''),
      courseId: _readString(data, 'courseId', ''),
      courseName: _readString(data, 'courseName', 'Course'),
      deadline: deadline is Timestamp ? deadline.toDate() : null,
      maxMarks: _readDouble(data, 'maxMarks'),
      latePolicy: _readString(data, 'latePolicy', 'block'),
      latePenaltyMarks: _readDouble(data, 'latePenaltyMarks'),
    );
  }

  String get deadlineLabel {
    final date = deadline;
    if (date == null) {
      return 'Not set';
    }
    return _dateTimeLabel(date);
  }
}

class _AssignmentSubmission {
  const _AssignmentSubmission({
    required this.driveLink,
    required this.isLate,
    required this.effectiveMaxMarks,
  });

  final String driveLink;
  final bool isLate;
  final double effectiveMaxMarks;

  factory _AssignmentSubmission.fromMap(Map<String, dynamic> data) {
    return _AssignmentSubmission(
      driveLink: _readString(data, 'driveLink', ''),
      isLate: data['isLate'] == true,
      effectiveMaxMarks: _readDouble(data, 'effectiveMaxMarks'),
    );
  }
}

String _marksLabel(double marks) {
  final hasCents = marks.truncateToDouble() != marks;
  return '${marks.toStringAsFixed(hasCents ? 1 : 0)} marks';
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

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
