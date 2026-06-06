import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'student_detail_page.dart';
import 'student_qr.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCourse = 'All';

  static const List<String> _courses = [
    'All',
    'Mathematics',
    'Physics',
    'Chemistry',
    'English',
  ];

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

  void _openRegisterSheet() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RegisterStudentSheet(),
    ).then((createdStudentId) {
      if (!mounted || createdStudentId == null || createdStudentId.isEmpty) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentDetailPage(studentId: createdStudentId),
        ),
      );
    });
  }

  List<_StudentProfile> _filterStudents(List<_StudentProfile> students) {
    final query = _searchController.text.trim().toLowerCase();
    final selectedCourse = _selectedCourse.toLowerCase();

    return students.where((student) {
      final matchesSearch = query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query) ||
          student.grade.toLowerCase().contains(query) ||
          student.course.toLowerCase().contains(query);
      final matchesCourse = _selectedCourse == 'All' ||
          student.course.toLowerCase().contains(selectedCourse);

      return matchesSearch && matchesCourse;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Column(
          children: [
            _StudentsTopBar(onAddPressed: _openRegisterSheet),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _SearchBox(controller: _searchController),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _courses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return _SubjectChip(
                    label: course,
                    isSelected: course == _selectedCourse,
                    onTap: () {
                      setState(() {
                        _selectedCourse = course;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Builder(
                builder: (context) {
                  final studentsStream = _studentsStream;
                  if (studentsStream == null) {
                    return const _StudentsMessage(
                      icon: Icons.lock_outline_rounded,
                      title: 'Teacher login needed',
                      message:
                          'Students බලන්න teacher account එකෙන් login වෙන්න.',
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: studentsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const _StudentsMessage(
                          icon: Icons.lock_outline_rounded,
                          title: 'Students load කරන්න බැහැ',
                          message:
                              'Firestore rules read permission check කරන්න.',
                        );
                      }

                      final students = (snapshot.data?.docs ?? [])
                          .map(_StudentProfile.fromSnapshot)
                          .where((student) => student.role == 'student')
                          .toList()
                        ..sort((first, second) =>
                            first.name.compareTo(second.name));
                      final filteredStudents = _filterStudents(students);

                      if (filteredStudents.isEmpty) {
                        return _StudentsMessage(
                          icon: Icons.people_alt_outlined,
                          title: students.isEmpty
                              ? 'තවම students නැහැ'
                              : 'Student කෙනෙක් හමු උනේ නැහැ',
                          message: students.isEmpty
                              ? '+ button එකෙන් පළවෙනි student register කරන්න.'
                              : 'Search text හෝ course filter එක වෙනස් කරන්න.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFE7ECF5),
                        ),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _StudentTile(
                            student: student,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StudentDetailPage(studentId: student.id),
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
            const _StudentsBottomNavigation(),
          ],
        ),
      ),
    );
  }
}

class _StudentsTopBar extends StatelessWidget {
  const _StudentsTopBar({required this.onAddPressed});

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
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF0D1B38),
          ),
          const Expanded(
            child: Text(
              'Students',
              style: TextStyle(
                color: Color(0xFF081A36),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subject chips වලින් filter කරන්න.'),
                ),
              );
            },
            icon: const Icon(Icons.filter_alt_outlined),
            color: const Color(0xFF316DFF),
          ),
          IconButton(
            tooltip: 'Add student',
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            color: const Color(0xFF316DFF),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search students...',
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

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
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
      color: isSelected ? const Color(0xFF316DFF) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF316DFF)
                  : const Color(0xFFDDE5F4),
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

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.onTap,
  });

  final _StudentProfile student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: student.avatarBackground,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF61718E),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: student.statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  student.statusLabel,
                  style: TextStyle(
                    color: student.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterStudentSheet extends StatefulWidget {
  const _RegisterStudentSheet();

  @override
  State<_RegisterStudentSheet> createState() => _RegisterStudentSheetState();
}

class _RegisterStudentSheetState extends State<_RegisterStudentSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSaving = false;
  bool _hidePassword = true;
  String? _errorMessage;

  static const String _registrationAppName = 'student-registration';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _gradeController.dispose();
    _courseController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<FirebaseAuth> _registrationAuth() async {
    final appExists = Firebase.apps.any(
      (app) => app.name == _registrationAppName,
    );
    final registrationApp = appExists
        ? Firebase.app(_registrationAppName)
        : await Firebase.initializeApp(
            name: _registrationAppName,
            options: DefaultFirebaseOptions.currentPlatform,
          );

    return FirebaseAuth.instanceFor(app: registrationApp);
  }

  Future<void> _createStudent() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    FirebaseAuth? registrationAuth;
    UserCredential? studentCredential;

    try {
      final teacher = FirebaseAuth.instance.currentUser;
      if (teacher == null) {
        throw StateError('Teacher is not signed in.');
      }

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final grade = _gradeController.text.trim();
      final course = _courseController.text.trim();
      final password = _passwordController.text;

      registrationAuth = await _registrationAuth();
      studentCredential = await registrationAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final studentUser = studentCredential.user;
      if (studentUser == null) {
        throw StateError('Student account was not created.');
      }

      final classId = buildStudentClassId(course);
      final qrPayload = buildStudentQrPayload(
        studentId: studentUser.uid,
        name: name,
        email: email,
        grade: grade,
        course: course,
        teacherUid: teacher.uid,
      );

      await studentUser.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUser.uid)
          .set({
        'uid': studentUser.uid,
        'studentId': studentUser.uid,
        'name': name,
        'email': email,
        'grade': grade,
        'course': course,
        'subject': course,
        'classId': classId,
        'qrPayload': qrPayload,
        'qrVersion': 1,
        'role': 'student',
        'status': 'active',
        'createdBy': teacher.uid,
        'createdByEmail': teacher.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await registrationAuth.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(studentUser.uid);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _authErrorMessage(error);
      });
    } on FirebaseException catch (error) {
      await _deleteCreatedAuthUser(studentCredential);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'Firestore permission denied. Rules වල users create permission දෙන්න.'
            : 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (_) {
      await _deleteCreatedAuthUser(studentCredential);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Student account create කරන්න බැරි උනා.';
      });
    } finally {
      await registrationAuth?.signOut();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteCreatedAuthUser(UserCredential? credential) async {
    try {
      await credential?.user?.delete();
    } catch (_) {}
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'මේ email එකෙන් account එකක් දැනටම තියෙනවා.';
      case 'invalid-email':
        return 'Email address එක valid නැහැ.';
      case 'weak-password':
        return 'Password එක තව ටිකක් strong කරන්න.';
      case 'network-request-failed':
        return 'Internet connection එක check කරලා ආයෙ try කරන්න.';
      default:
        return 'Firebase Auth error: ${error.message ?? error.code}';
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) {
      return 'Student name එක දාන්න.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Valid email එකක් දාන්න.';
    }
    return null;
  }

  String? _validateGrade(String? value) {
    final grade = value?.trim() ?? '';
    if (grade.isEmpty) {
      return 'Grade එක දාන්න.';
    }
    return null;
  }

  String? _validateCourse(String? value) {
    final course = value?.trim() ?? '';
    if (course.isEmpty) {
      return 'Course එක දාන්න.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Password characters 6කට වැඩි වෙන්න ඕන.';
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
                  'Register Student',
                  style: TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Name, email, grade, course, password දාන්න. Password එක Firestore එකේ save වෙන්නේ නැහැ.',
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
                  validator: _validateName,
                  decoration: _inputDecoration(
                    label: 'Student name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: _inputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gradeController,
                  textInputAction: TextInputAction.next,
                  validator: _validateGrade,
                  decoration: _inputDecoration(
                    label: 'Grade',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _courseController,
                  textInputAction: TextInputAction.next,
                  validator: _validateCourse,
                  decoration: _inputDecoration(
                    label: 'Course',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  validator: _validatePassword,
                  decoration: _inputDecoration(
                    label: 'Temporary password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
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
                  onPressed: _isSaving ? null : _createStudent,
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
                          'Create Student',
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6F7E9A)),
      suffixIcon: suffixIcon,
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

class _StudentsMessage extends StatelessWidget {
  const _StudentsMessage({
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

class _StudentsBottomNavigation extends StatelessWidget {
  const _StudentsBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F4)),
        ),
      ),
      child: Row(
        children: [
          _StudentsBottomNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isActive: false,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const _StudentsBottomNavItem(
            icon: Icons.people_alt_outlined,
            label: 'Students',
            isActive: true,
          ),
          const _StudentsBottomNavItem(
            icon: Icons.menu_book_outlined,
            label: 'Courses',
            isActive: false,
          ),
          const _StudentsBottomNavItem(
            icon: Icons.credit_card_rounded,
            label: 'Payments',
            isActive: false,
          ),
          _StudentsBottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isActive: false,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _StudentsBottomNavItem extends StatelessWidget {
  const _StudentsBottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF316DFF) : const Color(0xFF8B97AD);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentProfile {
  const _StudentProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.grade,
    required this.course,
    required this.role,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final String grade;
  final String course;
  final String role;
  final String status;

  factory _StudentProfile.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final fallbackCourse = _readString(data, 'subject', 'General');

    return _StudentProfile(
      id: snapshot.id,
      name: _readString(data, 'name', 'Unnamed Student'),
      email: _readString(data, 'email', ''),
      grade: _readString(data, 'grade', ''),
      course: _readString(data, 'course', fallbackCourse),
      role: _readString(data, 'role', 'student'),
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

  String get subtitle {
    final details = <String>[
      if (grade.isNotEmpty) grade,
      if (course.isNotEmpty && course != 'General') course,
    ];

    if (details.isNotEmpty) {
      return details.join(' • ');
    }

    return email.isEmpty ? id : email;
  }

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'ST' : letters.toUpperCase();
  }

  Color get avatarColor {
    final colors = [
      const Color(0xFF316DFF),
      const Color(0xFF7048E8),
      const Color(0xFF0FAF75),
      const Color(0xFFFF9500),
      const Color(0xFFFF526B),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  Color get avatarBackground => avatarColor.withOpacity(0.12);

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'due':
        return 'Due';
      case 'overdue':
        return 'Overdue';
      case 'registered':
        return 'Registered';
      default:
        return 'Active';
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'due':
        return const Color(0xFFFF526B);
      case 'overdue':
        return const Color(0xFFFF8A00);
      default:
        return const Color(0xFF00A86B);
    }
  }

  Color get statusBackground {
    switch (status.toLowerCase()) {
      case 'due':
        return const Color(0xFFFFEEF1);
      case 'overdue':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFE7F9F0);
    }
  }
}
