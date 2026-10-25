import 'dart:convert';

enum VaultType {
  password('PASSWORD', 'Password'),
  card('CARDS', 'Card'),
  note('NOTE', 'Note'),
  identity('IDENTITY', 'Identity'),
  secureNote('SECURE_NOTE', 'Secure note');

  const VaultType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VaultType fromApi(String? value) {
    final normalized = (value ?? '').toUpperCase();
    for (final type in values) {
      if (type.apiValue == normalized ||
          type.name.toUpperCase() == normalized) {
        return type;
      }
    }
    return VaultType.password;
  }

  static VaultType fromName(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return VaultType.password;
  }
}

class VaultItem {
  const VaultItem({
    required this.id,
    required this.title,
    required this.type,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.cardNumber = '',
    this.cardholder = '',
    this.expiry = '',
    this.cvv = '',
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.favorite = false,
    this.pending = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final VaultType type;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String cardNumber;
  final String cardholder;
  final String expiry;
  final String cvv;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final bool favorite;

  /// True while a local change still has to reach the server.
  final bool pending;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get subtitle {
    switch (type) {
      case VaultType.password:
        return username.isEmpty ? url : username;
      case VaultType.card:
        if (cardNumber.length < 4) return cardholder;
        return '•••• ${cardNumber.substring(cardNumber.length - 4)}';
      case VaultType.identity:
        return fullName.isEmpty ? email : fullName;
      case VaultType.note:
      case VaultType.secureNote:
        return notes.isEmpty ? 'Private note' : notes;
    }
  }

  String get searchText => [
        title,
        username,
        url,
        notes,
        cardNumber,
        cardholder,
        fullName,
        email,
        phone,
        address,
      ].join(' ').toLowerCase();

  VaultItem copyWith({
    String? id,
    String? title,
    VaultType? type,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? cardNumber,
    String? cardholder,
    String? expiry,
    String? cvv,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    bool? favorite,
    bool? pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      cardNumber: cardNumber ?? this.cardNumber,
      cardholder: cardholder ?? this.cardholder,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      favorite: favorite ?? this.favorite,
      pending: pending ?? this.pending,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'cardNumber': cardNumber,
        'cardholder': cardholder,
        'expiry': expiry,
        'cvv': cvv,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'favorite': favorite,
        'pending': pending,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: _string(json['id']),
      title: _string(json['title']),
      type: VaultType.fromName(json['type'] as String?),
      username: _string(json['username']),
      password: _string(json['password']),
      url: _string(json['url']),
      notes: _string(json['notes']),
      cardNumber: _string(json['cardNumber']),
      cardholder: _string(json['cardholder']),
      expiry: _string(json['expiry']),
      cvv: _string(json['cvv']),
      fullName: _string(json['fullName']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      address: _string(json['address']),
      favorite: _bool(json['favorite']),
      pending: _bool(json['pending']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

enum BillingType {
  bill('BILL', 'Bill'),
  subscription('SUBSCRIPTION', 'Subscription');

  const BillingType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BillingType fromApi(String? value) {
    return (value ?? '').toUpperCase() == 'SUBSCRIPTION'
        ? BillingType.subscription
        : BillingType.bill;
  }

  static BillingType fromName(String? value) {
    return value == BillingType.subscription.name
        ? BillingType.subscription
        : BillingType.bill;
  }
}

enum BillingCycle {
  daily('DAILY', 'Daily'),
  weekly('WEEKLY', 'Weekly'),
  biweekly('BIWEEKLY', 'Every 2 weeks'),
  monthly('MONTHLY', 'Monthly'),
  quarterly('QUARTERLY', 'Quarterly'),
  yearly('YEARLY', 'Yearly');

  const BillingCycle(this.apiValue, this.label);

  final String apiValue;
  final String label;

  DateTime advance(DateTime date) {
    switch (this) {
      case BillingCycle.daily:
        return date.add(const Duration(days: 1));
      case BillingCycle.weekly:
        return date.add(const Duration(days: 7));
      case BillingCycle.biweekly:
        return date.add(const Duration(days: 14));
      case BillingCycle.monthly:
        return _addMonths(date, 1);
      case BillingCycle.quarterly:
        return _addMonths(date, 3);
      case BillingCycle.yearly:
        return _addMonths(date, 12);
    }
  }

  static DateTime _addMonths(DateTime date, int months) {
    final month = date.month - 1 + months;
    final year = date.year + month ~/ 12;
    final targetMonth = month % 12 + 1;
    final lastDay = DateTime(year, targetMonth + 1, 0).day;
    return DateTime(
      year,
      targetMonth,
      date.day > lastDay ? lastDay : date.day,
      date.hour,
      date.minute,
    );
  }

  static BillingCycle? fromApi(String? value) {
    if (value == null) return null;
    for (final cycle in values) {
      if (cycle.apiValue == value.toUpperCase()) return cycle;
    }
    return null;
  }

  static BillingCycle? fromName(String? value) {
    for (final cycle in values) {
      if (cycle.name == value) return cycle;
    }
    return null;
  }
}

enum Urgency { overdue, today, soon, later, none }

class BillItem {
  const BillItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    this.cycle,
    this.nextDueDate,
    this.notes = '',
    this.isActive = true,
    this.lastPaidAt,
    this.pending = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final double amount;
  final BillingType type;
  final BillingCycle? cycle;
  final DateTime? nextDueDate;
  final String notes;
  final bool isActive;
  final DateTime? lastPaidAt;
  final bool pending;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? get daysUntilDue {
    final due = nextDueDate;
    if (due == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    return day.difference(today).inDays;
  }

  Urgency get urgency {
    final days = daysUntilDue;
    if (days == null) return Urgency.none;
    if (days < 0) return Urgency.overdue;
    if (days == 0) return Urgency.today;
    if (days <= 7) return Urgency.soon;
    return Urgency.later;
  }

  bool get wasPaidRecently {
    final paid = lastPaidAt;
    if (paid == null) return false;
    return DateTime.now().difference(paid).inDays <= 31;
  }

  BillItem copyWith({
    String? id,
    String? title,
    double? amount,
    BillingType? type,
    Object? cycle = _unset,
    Object? nextDueDate = _unset,
    String? notes,
    bool? isActive,
    Object? lastPaidAt = _unset,
    bool? pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      cycle: identical(cycle, _unset) ? this.cycle : cycle as BillingCycle?,
      nextDueDate: identical(nextDueDate, _unset)
          ? this.nextDueDate
          : nextDueDate as DateTime?,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      lastPaidAt: identical(lastPaidAt, _unset)
          ? this.lastPaidAt
          : lastPaidAt as DateTime?,
      pending: pending ?? this.pending,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'cycle': cycle?.name,
        'nextDueDate': nextDueDate?.toIso8601String(),
        'notes': notes,
        'isActive': isActive,
        'lastPaidAt': lastPaidAt?.toIso8601String(),
        'pending': pending,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: _string(json['id']),
      title: _string(json['title']),
      amount: _double(json['amount']),
      type: BillingType.fromName(json['type'] as String?),
      cycle: BillingCycle.fromName(json['cycle'] as String?),
      nextDueDate: _nullableDate(json['nextDueDate']),
      notes: _string(json['notes']),
      isActive: _bool(json['isActive'], fallback: true),
      lastPaidAt: _nullableDate(json['lastPaidAt']),
      pending: _bool(json['pending']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class FocusSchedule {
  const FocusSchedule({
    required this.id,
    required this.label,
    required this.startMinutes,
    required this.endMinutes,
    required this.days,
    this.blockedApps = const [],
    this.enabled = true,
    this.pending = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final int startMinutes;
  final int endMinutes;

  /// ISO weekdays: Monday = 1 … Sunday = 7.
  final Set<int> days;
  final List<String> blockedApps;
  final bool enabled;
  final bool pending;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<int> get apiDays =>
      days.map((day) => day == 7 ? 0 : day).toList()..sort();

  String get timeRange {
    String format(int minutes) {
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      final suffix = hour >= 12 ? 'pm' : 'am';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:${minute.toString().padLeft(2, '0')}$suffix';
    }

    return '${format(startMinutes)} – ${format(endMinutes)}';
  }

  FocusSchedule copyWith({
    String? id,
    String? label,
    int? startMinutes,
    int? endMinutes,
    Set<int>? days,
    List<String>? blockedApps,
    bool? enabled,
    bool? pending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusSchedule(
      id: id ?? this.id,
      label: label ?? this.label,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      days: days ?? this.days,
      blockedApps: blockedApps ?? this.blockedApps,
      enabled: enabled ?? this.enabled,
      pending: pending ?? this.pending,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'days': days.toList()..sort(),
        'blockedApps': blockedApps,
        'enabled': enabled,
        'pending': pending,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FocusSchedule.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    return FocusSchedule(
      id: _string(json['id']),
      label: _string(json['label']),
      startMinutes: _int(json['startMinutes']),
      endMinutes: _int(json['endMinutes']),
      days: rawDays is List
          ? rawDays
              .map((value) => _int(value))
              .where((day) => day >= 1 && day <= 7)
              .toSet()
          : <int>{},
      blockedApps: (json['blockedApps'] as List?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      enabled: _bool(json['enabled'], fallback: true),
      pending: _bool(json['pending']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.task,
    required this.minutes,
    required this.startedAt,
    required this.completed,
  });

  final String id;
  final String task;
  final int minutes;
  final DateTime startedAt;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'minutes': minutes,
        'startedAt': startedAt.toIso8601String(),
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: _string(json['id']),
      task: _string(json['task']),
      minutes: _int(json['minutes']),
      startedAt: _date(json['startedAt']),
      completed: _bool(json['completed']),
    );
  }
}

class FocusRun {
  const FocusRun({
    required this.task,
    required this.minutes,
    required this.startedAt,
    required this.endsAt,
    this.paused = false,
    this.pausedRemainingSeconds,
  });

  final String task;
  final int minutes;
  final DateTime startedAt;
  final DateTime endsAt;
  final bool paused;
  final int? pausedRemainingSeconds;

  int remainingSeconds(DateTime now) {
    if (paused) return pausedRemainingSeconds ?? 0;
    final value = endsAt.difference(now).inSeconds;
    return value < 0 ? 0 : value;
  }

  FocusRun pause(DateTime now) => FocusRun(
        task: task,
        minutes: minutes,
        startedAt: startedAt,
        endsAt: endsAt,
        paused: true,
        pausedRemainingSeconds: remainingSeconds(now),
      );

  FocusRun resume(DateTime now) => FocusRun(
        task: task,
        minutes: minutes,
        startedAt: startedAt,
        endsAt: now.add(Duration(seconds: pausedRemainingSeconds ?? 0)),
      );

  Map<String, dynamic> toJson() => {
        'task': task,
        'minutes': minutes,
        'startedAt': startedAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'paused': paused,
        'pausedRemainingSeconds': pausedRemainingSeconds,
      };

  factory FocusRun.fromJson(Map<String, dynamic> json) {
    return FocusRun(
      task: _string(json['task']),
      minutes: _int(json['minutes']),
      startedAt: _date(json['startedAt']),
      endsAt: _date(json['endsAt']),
      paused: _bool(json['paused']),
      pausedRemainingSeconds: json['pausedRemainingSeconds'] == null
          ? null
          : _int(json['pausedRemainingSeconds']),
    );
  }
}

class AppSnapshot {
  AppSnapshot({
    List<VaultItem>? vault,
    List<BillItem>? bills,
    List<FocusSchedule>? schedules,
    List<FocusSession>? sessions,
    List<String>? deletedVaultIds,
    List<String>? deletedBillIds,
    List<String>? deletedScheduleIds,
    this.activeFocus,
  })  : vault = vault ?? <VaultItem>[],
        bills = bills ?? <BillItem>[],
        schedules = schedules ?? <FocusSchedule>[],
        sessions = sessions ?? <FocusSession>[],
        deletedVaultIds = deletedVaultIds ?? <String>[],
        deletedBillIds = deletedBillIds ?? <String>[],
        deletedScheduleIds = deletedScheduleIds ?? <String>[];

  List<VaultItem> vault;
  List<BillItem> bills;
  List<FocusSchedule> schedules;
  List<FocusSession> sessions;
  List<String> deletedVaultIds;
  List<String> deletedBillIds;
  List<String> deletedScheduleIds;
  FocusRun? activeFocus;

  static AppSnapshot empty() => AppSnapshot();

  AppSnapshot copyWith({
    List<VaultItem>? vault,
    List<BillItem>? bills,
    List<FocusSchedule>? schedules,
    List<FocusSession>? sessions,
    List<String>? deletedVaultIds,
    List<String>? deletedBillIds,
    List<String>? deletedScheduleIds,
    Object? activeFocus = _unset,
  }) {
    return AppSnapshot(
      vault: vault ?? this.vault,
      bills: bills ?? this.bills,
      schedules: schedules ?? this.schedules,
      sessions: sessions ?? this.sessions,
      deletedVaultIds: deletedVaultIds ?? this.deletedVaultIds,
      deletedBillIds: deletedBillIds ?? this.deletedBillIds,
      deletedScheduleIds: deletedScheduleIds ?? this.deletedScheduleIds,
      activeFocus: identical(activeFocus, _unset)
          ? this.activeFocus
          : activeFocus as FocusRun?,
    );
  }

  Map<String, dynamic> toJson() => {
        'vault': vault.map((item) => item.toJson()).toList(),
        'bills': bills.map((item) => item.toJson()).toList(),
        'schedules': schedules.map((item) => item.toJson()).toList(),
        'sessions': sessions.map((item) => item.toJson()).toList(),
        'deletedVaultIds': deletedVaultIds,
        'deletedBillIds': deletedBillIds,
        'deletedScheduleIds': deletedScheduleIds,
        'activeFocus': activeFocus?.toJson(),
      };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((value) => parse(Map<String, dynamic>.from(value)))
          .toList();
    }

    List<String> parseIds(dynamic raw) {
      if (raw is! List) return <String>[];
      return raw.map((value) => value.toString()).toList();
    }

    return AppSnapshot(
      vault: parseList(json['vault'], VaultItem.fromJson),
      bills: parseList(json['bills'], BillItem.fromJson),
      schedules: parseList(json['schedules'], FocusSchedule.fromJson),
      sessions: parseList(json['sessions'], FocusSession.fromJson),
      deletedVaultIds: parseIds(json['deletedVaultIds']),
      deletedBillIds: parseIds(json['deletedBillIds']),
      deletedScheduleIds: parseIds(json['deletedScheduleIds']),
      activeFocus: json['activeFocus'] is Map
          ? FocusRun.fromJson(
              Map<String, dynamic>.from(json['activeFocus'] as Map),
            )
          : null,
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class UserProfile {
  const UserProfile({required this.id, required this.email, this.name = ''});

  final String id;
  final String email;
  final String name;

  UserProfile copyWith({String? id, String? email, String? name}) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }
}

const Object _unset = Object();

String _string(dynamic value) => value?.toString() ?? '';

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

DateTime _date(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

DateTime? _nullableDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
