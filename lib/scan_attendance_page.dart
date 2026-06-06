import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanAttendancePage extends StatefulWidget {
  const ScanAttendancePage({super.key});

  @override
  State<ScanAttendancePage> createState() => _ScanAttendancePageState();
}

class _ScanAttendancePageState extends State<ScanAttendancePage>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _scanLineController;
  late final AnimationController _successController;
  bool _isSaving = false;
  String? _lastScannedValue;
  String? _statusMessage;
  Color _statusColor = const Color(0xFF20D6A1);

  CollectionReference<Map<String, dynamic>>? get _scanCollection {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_attendance')
        .doc(teacher.uid)
        .collection('scans');
  }

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _successController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isSaving || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty || rawValue == _lastScannedValue) {
      return;
    }

    setState(() {
      _isSaving = true;
      _lastScannedValue = rawValue;
      _statusMessage = 'Saving attendance...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      await _saveAttendance(rawValue);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Attendance saved';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.code == 'permission-denied'
            ? 'Permission denied. Check Firestore rules.'
            : 'Firebase error: ${error.message ?? error.code}';
        _statusColor = const Color(0xFFFF526B);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            error is StateError ? error.message : 'Could not save attendance.';
        _statusColor = const Color(0xFFFF526B);
      });
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveAttendance(String qrValue) async {
    final teacher = FirebaseAuth.instance.currentUser;
    final scans = _scanCollection;

    if (teacher == null || scans == null) {
      throw StateError('Teacher is not signed in.');
    }

    final payload = _parseQrPayload(qrValue);
    final studentId = payload['studentId'] ?? qrValue;
    final studentName = payload['name'] ?? studentId;
    final classId = payload['classId'] ?? 'mathematics-10a';
    final course = payload['course'] ?? classId;
    final grade = payload['grade'] ?? '';
    final studentEmail = payload['email'] ?? '';
    final qrTeacherUid = payload['teacherUid'] ?? '';
    final dateKey = _dateKey(DateTime.now());
    final documentId = '$dateKey-$studentId';

    if (qrTeacherUid.isNotEmpty && qrTeacherUid != teacher.uid) {
      throw StateError('This QR belongs to another teacher.');
    }

    await scans.doc(documentId).set({
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'grade': grade,
      'course': course,
      'classId': classId,
      'dateKey': dateKey,
      'qrValue': qrValue,
      'qrTeacherUid': qrTeacherUid,
      'status': 'present',
      'teacherUid': teacher.uid,
      'scannedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, String> _parseQrPayload(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      // Plain student IDs are valid QR values.
    }

    final uri = Uri.tryParse(rawValue);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final studentId =
          uri.queryParameters['studentId'] ?? uri.queryParameters['id'];
      if (studentId != null && studentId.trim().isNotEmpty) {
        return <String, String>{
          'studentId': studentId.trim(),
          if (uri.queryParameters['name'] != null)
            'name': uri.queryParameters['name']!,
          if (uri.queryParameters['classId'] != null)
            'classId': uri.queryParameters['classId']!,
        };
      }
    }

    return <String, String>{'studentId': rawValue};
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manual attendance'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              hintText: 'Enter student ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop();
                if (value.isNotEmpty) {
                  _handleManualEntry(value);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleManualEntry(String studentId) async {
    setState(() {
      _isSaving = true;
      _lastScannedValue = null;
      _statusMessage = 'Saving manual attendance...';
      _statusColor = const Color(0xFF4E7BFF);
    });

    try {
      await _saveAttendance(studentId);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Manual attendance saved';
        _statusColor = const Color(0xFF20D6A1);
      });
      _successController.forward(from: 0);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Could not save manual attendance.';
        _statusColor = const Color(0xFFFF526B);
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
      backgroundColor: const Color(0xFF0D1833),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Attendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _showManualEntryDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white54,
                      backgroundColor: const Color(0xFF283854),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Manual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScannerFrame(
                      controller: _scannerController,
                      onDetect: _handleDetect,
                      scanAnimation: _scanLineController,
                      successAnimation: _successController,
                      isSaving: _isSaving,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _isSaving
                          ? 'Saving scanned QR code...'
                          : "Point camera at student's QR code",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    _RecentScansPanel(scans: _scanCollection),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({
    required this.controller,
    required this.onDetect,
    required this.scanAnimation,
    required this.successAnimation,
    required this.isSaving,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final Animation<double> scanAnimation;
  final Animation<double> successAnimation;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
            ),
            Container(color: Colors.black.withOpacity(0.18)),
            _ScanLaserLine(animation: scanAnimation),
            _ScannerStatusHalo(isSaving: isSaving),
            _SuccessPulse(animation: successAnimation),
            const _ScannerCorner(alignment: Alignment.topLeft),
            const _ScannerCorner(alignment: Alignment.topRight),
            const _ScannerCorner(alignment: Alignment.bottomLeft),
            const _ScannerCorner(alignment: Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

class _ScanLaserLine extends StatelessWidget {
  const _ScanLaserLine({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final travelDistance = constraints.maxHeight - 112;
              final top = 56 + (travelDistance * animation.value);

              return Stack(
                children: [
                  Positioned(
                    left: 48,
                    right: 48,
                    top: top,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x004E7BFF),
                            Color(0xFF4E7BFF),
                            Color(0xFF20D6A1),
                            Color(0x004E7BFF),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xAA4E7BFF),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ScannerStatusHalo extends StatelessWidget {
  const _ScannerStatusHalo({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: isSaving ? 96 : 128,
        height: isSaving ? 96 : 128,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSaving
                ? const Color(0xFF20D6A1).withOpacity(0.9)
                : const Color(0xFF4E7BFF).withOpacity(0.25),
            width: isSaving ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isSaving ? const Color(0xFF20D6A1) : const Color(0xFF4E7BFF))
                      .withOpacity(isSaving ? 0.35 : 0.12),
              blurRadius: isSaving ? 32 : 18,
              spreadRadius: isSaving ? 6 : 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessPulse extends StatelessWidget {
  const _SuccessPulse({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }

        final value = Curves.easeOutCubic.transform(animation.value);
        final opacity = (1 - value).clamp(0.0, 1.0);

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.65 + (value * 1.4),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF20D6A1).withOpacity(0.22),
                  border: Border.all(
                    color: const Color(0xFF20D6A1),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA20D6A1),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: [
              Positioned(
                top: isTop ? 0 : null,
                bottom: isTop ? null : 0,
                left: isLeft ? 0 : null,
                right: isLeft ? null : 0,
                child: Container(
                  width: 28,
                  height: 2,
                  color: const Color(0xFF4E7BFF),
                ),
              ),
              Positioned(
                top: isTop ? 0 : null,
                bottom: isTop ? null : 0,
                left: isLeft ? 0 : null,
                right: isLeft ? null : 0,
                child: Container(
                  width: 2,
                  height: 28,
                  color: const Color(0xFF4E7BFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentScansPanel extends StatelessWidget {
  const _RecentScansPanel({required this.scans});

  final CollectionReference<Map<String, dynamic>>? scans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2944),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Scans',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TodayCountBadge(scans: scans),
            ],
          ),
          const SizedBox(height: 12),
          if (scans == null)
            const _EmptyRecentScans(message: 'Sign in to save scans.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: scans!
                  .orderBy('scannedAt', descending: true)
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _EmptyRecentScans(message: 'Loading scans...');
                }

                if (snapshot.hasError) {
                  return const _EmptyRecentScans(
                    message: 'Could not load recent scans.',
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _EmptyRecentScans(message: 'No scans yet.');
                }

                return Column(
                  children: [
                    for (var index = 0; index < docs.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _RecentScanTile(data: docs[index].data()),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TodayCountBadge extends StatelessWidget {
  const _TodayCountBadge({required this.scans});

  final CollectionReference<Map<String, dynamic>>? scans;

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (scans == null) {
      return const _CountBadge(label: 'Today: 0');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: scans!
          .where('dateKey', isEqualTo: _dateKey(DateTime.now()))
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.size ?? 0;
        return _CountBadge(label: 'Today: $count');
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2B5FFF),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyRecentScans extends StatelessWidget {
  const _EmptyRecentScans({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3954),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFB8C4D8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['studentName']?.toString() ??
        data['studentId']?.toString() ??
        'Unknown student';
    final scannedAt = data['scannedAt'];
    final trailing = scannedAt is Timestamp
        ? _elapsedLabel(scannedAt.toDate())
        : data['status']?.toString() ?? 'Saved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3954),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF20D6A1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFFB8C4D8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _elapsedLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) {
      return 'now';
    }
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes}m ago';
    }
    if (elapsed.inDays < 1) {
      return '${elapsed.inHours}h ago';
    }
    return '${elapsed.inDays}d ago';
  }
}
