import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentDetailsPage extends StatelessWidget {
  const PaymentDetailsPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  Future<void> _confirmDeletePayment(
    BuildContext context,
    User teacher,
    _PaymentData payment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete payment?'),
          content: Text(
            '${payment.studentName} • ${payment.courseLabel} ${payment.amountLabel} payment එක remove වෙනවා.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF526B),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    try {
      await _deletePayment(teacher.uid, payment);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Permission denied. Firestore payment update rules check කරන්න.'
                : 'Firebase error: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment delete කරන්න බැරි උනා.')),
      );
    }
  }

  Future<void> _deletePayment(String teacherUid, _PaymentData payment) async {
    final paymentReference = FirebaseFirestore.instance
        .collection('teacher_payments')
        .doc(teacherUid)
        .collection('payments')
        .doc(payment.id);

    final updateData = <String, dynamic>{
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final courseKey = _safeKey(
      payment.courseId.isNotEmpty ? payment.courseId : payment.course,
    );

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(paymentReference, updateData);

      if (payment.studentId.isNotEmpty && courseKey.isNotEmpty) {
        transaction.set(
          FirebaseFirestore.instance.collection('users').doc(payment.studentId),
          {
            'payments': {
              courseKey: {
                'courseId': payment.courseId,
                'course': payment.course,
                'amount': payment.amount,
                'monthKey': payment.monthKey,
                'status': 'archived',
              },
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teacher = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final monthKey = _monthKey(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: showBackButton,
        title: const Text(
          'Payment Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: teacher == null
          ? const _PaymentMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Teacher login needed',
              message: 'Payments බලන්න teacher account එකෙන් login වෙන්න.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_payments')
                  .doc(teacher.uid)
                  .collection('payments')
                  .where('monthKey', isEqualTo: monthKey)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _PaymentMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Could not load payments',
                    message: 'Firestore rules check කරන්න.',
                  );
                }

                final payments = (snapshot.data?.docs ?? [])
                    .map((doc) => _PaymentData.fromMap(doc.id, doc.data()))
                    .where((payment) => payment.isActive)
                    .toList()
                  ..sort((first, second) {
                    final firstDate = first.paidAt ?? DateTime(0);
                    final secondDate = second.paidAt ?? DateTime(0);
                    return secondDate.compareTo(firstDate);
                  });
                final total = payments.fold<double>(
                  0,
                  (total, payment) => total + payment.amount,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    _PaymentSummaryCard(
                      monthLabel: _monthLabel(now),
                      total: total,
                      count: payments.length,
                    ),
                    const SizedBox(height: 16),
                    if (payments.isEmpty)
                      const _PaymentMessage(
                        icon: Icons.receipt_long_outlined,
                        title: 'No payments yet',
                        message: 'මේ month එකට QR payment scan කරලා නැහැ.',
                      )
                    else
                      for (final payment in payments) ...[
                        _PaymentTile(
                          payment: payment,
                          onDelete: () =>
                              _confirmDeletePayment(context, teacher, payment),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.monthLabel,
    required this.total,
    required this.count,
  });

  final String monthLabel;
  final double total;
  final int count;

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
              Icons.payments_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _amountLabel(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count paid payment${count == 1 ? '' : 's'}',
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.onDelete,
  });

  final _PaymentData payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F9F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF00A86B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF071B3C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.courseLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60708F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MiniMeta(
                        icon: Icons.calendar_month, label: payment.dateLabel),
                    _MiniMeta(
                        icon: Icons.schedule_rounded, label: payment.timeLabel),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment.amountLabel,
                style: const TextStyle(
                  color: Color(0xFF00A86B),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Delete payment',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFFF526B),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8B97AD)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B97AD),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PaymentMessage extends StatelessWidget {
  const _PaymentMessage({
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

class _PaymentData {
  const _PaymentData({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.course,
    required this.grade,
    required this.amount,
    required this.monthKey,
    required this.status,
    required this.paidAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String courseId;
  final String course;
  final String grade;
  final double amount;
  final String monthKey;
  final String status;
  final DateTime? paidAt;

  factory _PaymentData.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    return _PaymentData(
      id: id,
      studentId: _readString(data, 'studentId', ''),
      studentName: _readString(data, 'studentName', 'Student'),
      courseId: _readString(data, 'courseId', ''),
      course: _readString(
        data,
        'courseName',
        _readString(data, 'course', 'Course'),
      ),
      grade: _readString(data, 'grade', ''),
      amount: _readDouble(data, 'amount'),
      monthKey: _readString(data, 'monthKey', ''),
      status: _readString(data, 'status', 'paid'),
      paidAt: createdAt is Timestamp
          ? createdAt.toDate()
          : updatedAt is Timestamp
              ? updatedAt.toDate()
              : null,
    );
  }

  bool get isActive {
    final normalized = status.toLowerCase();
    return normalized != 'archived' &&
        normalized != 'deleted' &&
        normalized != 'cancelled';
  }

  String get courseLabel {
    if (grade.isEmpty) {
      return course;
    }

    return '$course • $grade';
  }

  String get amountLabel => _amountLabel(amount);

  String get dateLabel {
    final date = paidAt;
    if (date == null) {
      return '-';
    }

    return _dateLabel(date);
  }

  String get timeLabel {
    final date = paidAt;
    if (date == null) {
      return '-';
    }

    return _timeLabel(date);
  }
}

String _monthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _amountLabel(double amount) {
  final hasCents = amount.truncateToDouble() != amount;
  return 'Rs ${amount.toStringAsFixed(hasCents ? 2 : 0)}';
}

String _safeKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return normalized.isEmpty ? 'payment' : normalized;
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
