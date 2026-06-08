import 'package:cloud_firestore/cloud_firestore.dart';

class CourseScheduleRange {
  const CourseScheduleRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  String get label =>
      '${formatCourseScheduleMinutes(startMinutes)} - ${formatCourseScheduleMinutes(endMinutes)}';

  bool overlaps(CourseScheduleRange other) {
    return startMinutes < other.endMinutes && other.startMinutes < endMinutes;
  }
}

class CourseScheduleConflict {
  const CourseScheduleConflict({
    required this.courseName,
    required this.days,
    required this.timeLabel,
  });

  final String courseName;
  final List<String> days;
  final String timeLabel;

  String get message {
    final dayLabel = days.isEmpty ? 'same day' : days.join('/');
    return '$courseName එකට $dayLabel $timeLabel already class time දීලා තියෙනවා.';
  }
}

class CourseScheduleSlot {
  const CourseScheduleSlot({
    required this.day,
    required this.range,
  });

  final String day;
  final CourseScheduleRange range;

  String get normalizedDay => day.trim().toLowerCase();

  String get label => '$day ${range.label}';

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'startTime': formatCourseScheduleMinutes(range.startMinutes),
      'endTime': formatCourseScheduleMinutes(range.endMinutes),
      'timeRange': range.label,
      'startMinutes': range.startMinutes,
      'endMinutes': range.endMinutes,
    };
  }
}

Future<CourseScheduleConflict?> findCourseScheduleConflict({
  required String teacherUid,
  required List<CourseScheduleSlot> scheduleSlots,
  String? currentCourseId,
}) async {
  if (teacherUid.isEmpty || scheduleSlots.isEmpty) {
    return null;
  }

  final coursesSnapshot = await FirebaseFirestore.instance
      .collection('teacher_courses')
      .doc(teacherUid)
      .collection('courses')
      .get();

  for (final courseDoc in coursesSnapshot.docs) {
    if (courseDoc.id == currentCourseId) {
      continue;
    }

    final data = courseDoc.data();
    if (data['status']?.toString().toLowerCase() == 'archived') {
      continue;
    }

    final existingSlots = courseScheduleSlotsFromData(data);
    for (final newSlot in scheduleSlots) {
      for (final existingSlot in existingSlots) {
        if (newSlot.normalizedDay != existingSlot.normalizedDay ||
            !newSlot.range.overlaps(existingSlot.range)) {
          continue;
        }

        return CourseScheduleConflict(
          courseName: _readString(data, 'name', 'Another course'),
          days: [existingSlot.day],
          timeLabel: existingSlot.range.label,
        );
      }
    }
  }

  return null;
}

List<CourseScheduleSlot> courseScheduleSlotsFromData(
  Map<String, dynamic> data,
) {
  final slots = <CourseScheduleSlot>[];
  final rawSlots = data['scheduleSlots'];

  if (rawSlots is Iterable) {
    for (final rawSlot in rawSlots) {
      final slot = courseScheduleSlotFromMap(rawSlot);
      if (slot != null) {
        slots.add(slot);
      }
    }
  }

  if (slots.isNotEmpty) {
    return slots;
  }

  final legacyRange = parseCourseScheduleRange(
    data['scheduleTime']?.toString() ?? '',
  );
  if (legacyRange == null) {
    return const [];
  }

  return _readStringList(data, 'scheduleDays')
      .map((day) => CourseScheduleSlot(day: day, range: legacyRange))
      .toList();
}

CourseScheduleSlot? courseScheduleSlotFromMap(Object? rawSlot) {
  if (rawSlot is! Map) {
    return null;
  }

  final data = <String, dynamic>{};
  rawSlot.forEach((key, value) {
    data[key.toString()] = value;
  });

  final day = _readString(data, 'day', '');
  if (day.isEmpty) {
    return null;
  }

  final startMinutes = _readInt(data, 'startMinutes');
  final endMinutes = _readInt(data, 'endMinutes');
  CourseScheduleRange? range;

  if (startMinutes != null && endMinutes != null && endMinutes > startMinutes) {
    range = CourseScheduleRange(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
  }

  range ??= parseCourseScheduleRange(
    _readString(
      data,
      'timeRange',
      '${_readString(data, 'startTime', '')} - ${_readString(data, 'endTime', '')}',
    ),
  );

  if (range == null) {
    return null;
  }

  return CourseScheduleSlot(day: day, range: range);
}

List<String> courseScheduleDaysFromSlots(List<CourseScheduleSlot> slots) {
  return slots
      .map((slot) => slot.day.trim())
      .where((day) => day.isNotEmpty)
      .toSet()
      .toList();
}

String courseScheduleTimeFromSlots(List<CourseScheduleSlot> slots) {
  if (slots.isEmpty) {
    return '';
  }

  final labels = slots.map((slot) => slot.range.label).toSet();
  return labels.length == 1 ? labels.first : 'Multiple times';
}

String courseScheduleLabel({
  required List<String> scheduleDays,
  required String scheduleTime,
  required List<CourseScheduleSlot> scheduleSlots,
}) {
  if (scheduleSlots.isNotEmpty) {
    final timeLabels = scheduleSlots.map((slot) => slot.range.label).toSet();
    if (timeLabels.length == 1) {
      return '${scheduleSlots.map((slot) => slot.day).join('/')} ${timeLabels.first}';
    }

    return scheduleSlots.map((slot) => slot.label).join(' • ');
  }

  if (scheduleDays.isEmpty && scheduleTime.isEmpty) {
    return 'Schedule not set';
  }

  if (scheduleDays.isEmpty) {
    return scheduleTime;
  }

  if (scheduleTime.isEmpty) {
    return scheduleDays.join('/');
  }

  return '${scheduleDays.join('/')} $scheduleTime';
}

CourseScheduleSlot? courseScheduleSlotForDate({
  required List<CourseScheduleSlot> scheduleSlots,
  required List<String> scheduleDays,
  required String scheduleTime,
  required DateTime date,
}) {
  final dayNames = {
    _shortDayName(date).toLowerCase(),
    _fullDayName(date).toLowerCase(),
  };

  for (final slot in scheduleSlots) {
    if (dayNames.contains(slot.normalizedDay)) {
      return slot;
    }
  }

  final legacyRange = parseCourseScheduleRange(scheduleTime);
  if (legacyRange == null) {
    return null;
  }

  for (final day in scheduleDays) {
    if (dayNames.contains(day.trim().toLowerCase())) {
      return CourseScheduleSlot(day: day, range: legacyRange);
    }
  }

  return null;
}

CourseScheduleRange? parseCourseScheduleRange(String value) {
  final timeMatches = RegExp(
    r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?',
    caseSensitive: false,
  ).allMatches(value.trim()).toList();

  if (timeMatches.isEmpty) {
    return null;
  }

  final endPeriod = timeMatches.length > 1 ? timeMatches[1].group(3) : null;
  final start = _minutesFromMatch(
    timeMatches.first,
    fallbackPeriod: endPeriod,
  );
  if (start == null) {
    return null;
  }

  final end = timeMatches.length > 1
      ? _minutesFromMatch(
          timeMatches[1],
          fallbackPeriod: timeMatches.first.group(3),
        )
      : start + 90;

  if (end == null || end <= start) {
    return null;
  }

  return CourseScheduleRange(startMinutes: start, endMinutes: end);
}

int? courseScheduleStartMinutes(String value) {
  return parseCourseScheduleRange(value)?.startMinutes;
}

String buildCourseScheduleTimeRange({
  required String startTime,
  required String endTime,
}) {
  final start = parseSingleCourseTime(startTime);
  final end = parseSingleCourseTime(endTime);

  if (start == null && end == null) {
    return '';
  }
  if (start == null || end == null || end <= start) {
    return '';
  }

  return '${formatCourseScheduleMinutes(start)} - ${formatCourseScheduleMinutes(end)}';
}

int? parseSingleCourseTime(String value) {
  final match = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());

  if (match == null) {
    return null;
  }

  return _minutesFromMatch(match);
}

String formatCourseScheduleMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

int? _minutesFromMatch(RegExpMatch match, {String? fallbackPeriod}) {
  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final period = (match.group(3) ?? fallbackPeriod)?.toUpperCase();

  if (hour == null || minute < 0 || minute > 59) {
    return null;
  }

  if (period == 'PM' && hour < 12) {
    hour += 12;
  }
  if (period == 'AM' && hour == 12) {
    hour = 0;
  }

  if (hour < 0 || hour > 23) {
    return null;
  }

  return (hour * 60) + minute;
}

int? _readInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _readString(
  Map<String, dynamic> data,
  String key,
  String fallback,
) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
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

String _shortDayName(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

String _fullDayName(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[date.weekday - 1];
}
