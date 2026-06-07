import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.userData = const {},
  });

  final Map<String, dynamic> userData;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _darkMode = false;
  bool _pushNotifications = true;
  bool _settingsLoaded = false;
  String _languageCode = 'en';

  String get _teacherUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>>? get _teacherDoc {
    if (_teacherUid.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance.collection('users').doc(_teacherUid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _teacherStream =>
      _teacherDoc?.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _studentsStream {
    if (_teacherUid.isEmpty) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('createdBy', isEqualTo: _teacherUid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _coursesStream {
    if (_teacherUid.isEmpty) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_courses')
        .doc(_teacherUid)
        .collection('courses')
        .snapshots();
  }

  void _applySettings(Map<String, dynamic> data) {
    if (_settingsLoaded) {
      return;
    }

    final settings = data['settings'];
    if (!data.containsKey('settings')) {
      return;
    }

    if (settings is Map) {
      _darkMode = settings['darkMode'] == true;
      _pushNotifications = settings['pushNotifications'] != false;
      final language = settings['language']?.toString().trim();
      _languageCode = language == 'si' ? 'si' : 'en';
    }
    _settingsLoaded = true;
  }

  Future<void> _updateSetting(String key, Object value) async {
    final teacherDoc = _teacherDoc;
    if (teacherDoc == null) {
      return;
    }

    await teacherDoc.set({
      'settings': {key: value},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool get _isSinhala => _languageCode == 'si';

  String _text(String english, String sinhala) {
    return _isSinhala ? sinhala : english;
  }

  Future<void> _openLanguageSheet() async {
    var selectedLanguage = _languageCode;
    var isSaving = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveLanguage(String languageCode) async {
              setSheetState(() {
                selectedLanguage = languageCode;
                isSaving = true;
                errorMessage = null;
              });

              try {
                await _updateSetting('language', languageCode);

                if (!mounted) {
                  return;
                }

                setState(() {
                  _languageCode = languageCode;
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                _showSnack(
                  languageCode == 'si'
                      ? 'භාෂාව සිංහලට මාරු කළා.'
                      : 'Language changed to English.',
                );
              } on FirebaseException catch (error) {
                setSheetState(() {
                  errorMessage = error.code == 'permission-denied'
                      ? 'Firestore permission denied. Language setting rules check කරන්න.'
                      : 'Firebase error: ${error.message ?? error.code}';
                });
              } catch (_) {
                setSheetState(() {
                  errorMessage = _text(
                    'Could not save language setting.',
                    'භාෂා සැකසුම save කරන්න බැරි වුණා.',
                  );
                });
              } finally {
                if (context.mounted) {
                  setSheetState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
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
                  Text(
                    _text('Choose Language', 'භාෂාව තෝරන්න'),
                    style: const TextStyle(
                      color: Color(0xFF071B3C),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _text(
                      'This preference is saved to your teacher account.',
                      'මේ සැකසුම teacher account එකට save වෙනවා.',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF6C7892),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LanguageOptionTile(
                    title: 'English',
                    subtitle: 'Use English labels',
                    isSelected: selectedLanguage == 'en',
                    isSaving: isSaving,
                    onTap: () => saveLanguage('en'),
                  ),
                  const SizedBox(height: 10),
                  _LanguageOptionTile(
                    title: 'සිංහල',
                    subtitle: 'Sinhala labels භාවිතා කරන්න',
                    isSelected: selectedLanguage == 'si',
                    isSaving: isSaving,
                    onTap: () => saveLanguage('si'),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD9233F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditProfileSheet(_TeacherProfile profile) async {
    final nameController = TextEditingController(text: profile.name);
    final titleController = TextEditingController(text: profile.title);
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveProfile() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setSheetState(() {
                isSaving = true;
                errorMessage = null;
              });

              try {
                final name = nameController.text.trim();
                final title = titleController.text.trim();
                final teacherDoc = _teacherDoc;
                final user = FirebaseAuth.instance.currentUser;

                if (teacherDoc == null || user == null) {
                  throw StateError('Teacher is not signed in.');
                }

                await user.updateDisplayName(name);
                await teacherDoc.set({
                  'name': name,
                  'title': title,
                  'role': 'teacher',
                  'email': user.email ?? profile.email,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } on FirebaseException catch (error) {
                setSheetState(() {
                  errorMessage = error.code == 'permission-denied'
                      ? 'Firestore permission denied. Profile update rules check කරන්න.'
                      : 'Firebase error: ${error.message ?? error.code}';
                });
              } catch (_) {
                setSheetState(() {
                  errorMessage = _text(
                    'Could not update profile.',
                    'පැතිකඩ update කරන්න බැරි උනා.',
                  );
                });
              } finally {
                if (context.mounted) {
                  setSheetState(() {
                    isSaving = false;
                  });
                }
              }
            }

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
                child: Form(
                  key: formKey,
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
                        _text('Edit Profile', 'පැතිකඩ වෙනස් කරන්න'),
                        style: const TextStyle(
                          color: Color(0xFF071B3C),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if ((value ?? '').trim().length < 2) {
                            return _text(
                              'Enter a valid name.',
                              'නිවැරදි නමක් දාන්න.',
                            );
                          }
                          return null;
                        },
                        decoration: _sheetInputDecoration(
                          label: _text('Name', 'නම'),
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        textInputAction: TextInputAction.done,
                        decoration: _sheetInputDecoration(
                          label: _text('Title', 'තනතුර'),
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFD9233F),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: isSaving ? null : saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF316DFF),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _text(
                                  'Save Profile',
                                  'පැතිකඩ save කරන්න',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    titleController.dispose();
  }

  InputDecoration _sheetInputDecoration({
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

  @override
  Widget build(BuildContext context) {
    final teacherStream = _teacherStream;
    final studentsStream = _studentsStream;
    final coursesStream = _coursesStream;

    if (teacherStream == null ||
        studentsStream == null ||
        coursesStream == null) {
      return const _ProfileMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Teacher login needed',
        message: 'Profile බලන්න teacher account එකෙන් login වෙන්න.',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: teacherStream,
      builder: (context, teacherSnapshot) {
        final teacherData = <String, dynamic>{
          ...widget.userData,
          ...?teacherSnapshot.data?.data(),
        };
        _applySettings(teacherData);
        final profile = _TeacherProfile.fromMap(
          FirebaseAuth.instance.currentUser,
          teacherData,
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: studentsStream,
          builder: (context, studentSnapshot) {
            final studentCount = _countStudents(studentSnapshot.data?.docs);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: coursesStream,
              builder: (context, courseSnapshot) {
                final courseCount =
                    _countActiveCourses(courseSnapshot.data?.docs);

                return Scaffold(
                  backgroundColor: const Color(0xFFF5F7FC),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHeader(
                          profile: profile,
                          studentCount: studentCount,
                          courseCount: courseCount,
                          rating: '4.9',
                          isSinhala: _isSinhala,
                        ),
                        const SizedBox(height: 12),
                        _SectionLabel(_text('ACCOUNT', 'ගිණුම')),
                        _ProfileMenuTile(
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF316DFF),
                          label: _text(
                            'Edit Profile',
                            'පැතිකඩ වෙනස් කරන්න',
                          ),
                          onTap: () => _openEditProfileSheet(profile),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.notifications_none_rounded,
                          iconColor: const Color(0xFF7B2FF2),
                          label: _text('Notifications', 'දැනුම්දීම්'),
                          onTap: () => _showSnack(
                            _text(
                              'Notifications coming soon.',
                              'දැනුම්දීම් ඉක්මනින් එනවා.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.security_rounded,
                          iconColor: const Color(0xFF00B979),
                          label: _text('Security', 'ආරක්ෂාව'),
                          onTap: () => _showSnack(
                            _text(
                              'Security settings coming soon.',
                              'ආරක්ෂක සැකසුම් ඉක්මනින් එනවා.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionLabel(_text('PREFERENCES', 'කැමැත්ත')),
                        _SwitchTile(
                          icon: Icons.dark_mode_outlined,
                          iconColor: const Color(0xFFFF9500),
                          label: _text('Dark Mode', 'අඳුරු මාදිලිය'),
                          value: _darkMode,
                          onChanged: (value) async {
                            setState(() {
                              _darkMode = value;
                            });
                            try {
                              await _updateSetting('darkMode', value);
                            } catch (_) {
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _darkMode = !value;
                              });
                              _showSnack(
                                _text(
                                  'Could not save dark mode setting.',
                                  'අඳුරු මාදිලි සැකසුම save කරන්න බැරි වුණා.',
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.language_rounded,
                          iconColor: const Color(0xFF316DFF),
                          label: _languageCode == 'si'
                              ? 'භාෂාව — සිංහල'
                              : 'Language — English',
                          onTap: _openLanguageSheet,
                        ),
                        const SizedBox(height: 8),
                        _SwitchTile(
                          icon: Icons.notifications_active_outlined,
                          iconColor: const Color(0xFF00B979),
                          label: _text(
                            'Push Notifications',
                            'Push දැනුම්දීම්',
                          ),
                          value: _pushNotifications,
                          activeColor: const Color(0xFF20C997),
                          onChanged: (value) async {
                            setState(() {
                              _pushNotifications = value;
                            });
                            try {
                              await _updateSetting('pushNotifications', value);
                            } catch (_) {
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _pushNotifications = !value;
                              });
                              _showSnack(
                                _text(
                                  'Could not save notification setting.',
                                  'දැනුම්දීම් සැකසුම save කරන්න බැරි වුණා.',
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(_text('Sign Out', 'ඉවත් වන්න')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF3B4E),
                            side: const BorderSide(color: Color(0xFFFF7A88)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  int _countStudents(List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs) {
    return (docs ?? [])
        .where((doc) => doc.data()['role']?.toString() == 'student')
        .where(
          (doc) => doc.data()['status']?.toString().toLowerCase() != 'archived',
        )
        .length;
  }

  int _countActiveCourses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  ) {
    return (docs ?? [])
        .where((doc) => doc.data()['status']?.toString() != 'archived')
        .length;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFEAF0FF) : const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSaving ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF316DFF)
                  : const Color(0xFFE2E8F4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF316DFF) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  title.trim().isEmpty
                      ? '?'
                      : title.trim().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF316DFF),
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
                      title,
                      style: const TextStyle(
                        color: Color(0xFF071B3C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6C7892),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSaving && isSelected)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF316DFF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.studentCount,
    required this.courseCount,
    required this.rating,
    required this.isSinhala,
  });

  final _TeacherProfile profile;
  final int studentCount;
  final int courseCount;
  final String rating;
  final bool isSinhala;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF243DA4),
            Color(0xFF7B2FF2),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 2),
            ),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            profile.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeaderStat(
                value: '$studentCount',
                label: isSinhala ? 'සිසුන්' : 'Students',
              ),
              const _HeaderDivider(),
              _HeaderStat(
                value: '$courseCount',
                label: isSinhala ? 'පාඨමාලා' : 'Courses',
              ),
              const _HeaderDivider(),
              _HeaderStat(
                value: rating,
                label: isSinhala ? 'අගය' : 'Rating',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withOpacity(0.35),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 7),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8B97AD),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5F4)),
          ),
          child: Row(
            children: [
              _TileIcon(icon: icon, iconColor: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB6C0D4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFFFF9500),
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Row(
        children: [
          _TileIcon(icon: icon, iconColor: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF071B3C),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.iconColor});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 17),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF8C98AF), size: 44),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 18,
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
      ),
    );
  }
}

class _TeacherProfile {
  const _TeacherProfile({
    required this.name,
    required this.email,
    required this.title,
  });

  final String name;
  final String email;
  final String title;

  factory _TeacherProfile.fromMap(User? user, Map<String, dynamic> data) {
    final email = _readString(data, 'email', user?.email ?? '');
    final fallbackName = email.contains('@') ? email.split('@').first : email;

    return _TeacherProfile(
      name: _readString(data, 'name', user?.displayName ?? fallbackName),
      email: email,
      title: _readString(data, 'title', 'Teacher • Smart LMS'),
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

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'T' : letters.toUpperCase();
  }
}
