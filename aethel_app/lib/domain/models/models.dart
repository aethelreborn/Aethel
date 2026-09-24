import 'package:equatable/equatable.dart';

enum VaultItemType { password, note, card, identity, secureNote }

enum BillingType { bill, subscription }

enum BillingCycle { daily, weekly, biweekly, monthly, quarterly, yearly }

enum UrgencyLevel { resolved, scheduled, upcoming, urgent }

class User extends Equatable {
  final String id;
  final String email;
  final DateTime createdAt;

  const User({required this.id, required this.email, required this.createdAt});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'created_at': createdAt.toIso8601String()};

  @override
  List<Object?> get props => [id, email, createdAt];
}

class VaultEntry extends Equatable {
  final String id;
  final String title;
  final VaultItemType type;
  final String encryptedPayload;
  final String iv;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.encryptedPayload,
    required this.iv,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        type: _parseItemType(json['item_type'] as String),
        encryptedPayload: json['encrypted_payload'] as String,
        iv: json['iv'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'item_type': _itemTypeToString(type),
        'encrypted_payload': encryptedPayload,
        'iv': iv,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static VaultItemType _parseItemType(String s) =>
      VaultItemType.values.byName(s.toLowerCase());

  static String _itemTypeToString(VaultItemType t) => t.name;

  @override
  List<Object?> get props => [id, title, type, createdAt, updatedAt];
}

class BillingEntry extends Equatable {
  final String id;
  final String title;
  final double amountDue;
  final BillingType type;
  final BillingCycle? cycle;
  final DateTime? nextDueDate;
  final DateTime? lastNotifiedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillingEntry({
    required this.id,
    required this.title,
    required this.amountDue,
    required this.type,
    this.cycle,
    this.nextDueDate,
    this.lastNotifiedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillingEntry.fromJson(Map<String, dynamic> json) => BillingEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        amountDue: (json['amount_due'] as num).toDouble(),
        type: BillingType.values.byName(json['item_type'] as String),
        cycle: json['billing_cycle'] == null
            ? null
            : BillingCycle.values.byName(json['billing_cycle'] as String),
        nextDueDate: json['next_due_date'] == null
            ? null
            : DateTime.parse(json['next_due_date'] as String),
        lastNotifiedAt: json['last_notified_at'] == null
            ? null
            : DateTime.parse(json['last_notified_at'] as String),
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount_due': amountDue,
        'item_type': type.name,
        'billing_cycle': cycle?.name,
        'next_due_date': nextDueDate?.toIso8601String(),
        'last_notified_at': lastNotifiedAt?.toIso8601String(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UrgencyLevel get urgency {
    if (!isActive) return UrgencyLevel.resolved;
    final now = DateTime.now();
    if (nextDueDate == null) return UrgencyLevel.scheduled;
    final diff = nextDueDate!.difference(now).inDays;
    if (diff < 0) return UrgencyLevel.urgent;
    if (diff <= 7) return UrgencyLevel.upcoming;
    return UrgencyLevel.scheduled;
  }

  @override
  List<Object?> get props => [id, title, amountDue, type, isActive, createdAt, updatedAt];
}

class TimelineEvent extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final UrgencyLevel urgency;
  final DateTime timestamp;
  final String module;

  const TimelineEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.urgency,
    required this.timestamp,
    required this.module,
  });

  factory TimelineEvent.fromBilling(BillingEntry entry) => TimelineEvent(
        id: entry.id,
        title: entry.title,
        subtitle: '\$${entry.amountDue.toStringAsFixed(2)} — ${entry.cycle?.name ?? 'one-time'}',
        urgency: entry.urgency,
        timestamp: entry.nextDueDate ?? entry.createdAt,
        module: 'billing',
      );

  factory TimelineEvent.fromVault(VaultEntry entry) => TimelineEvent(
        id: entry.id,
        title: entry.title,
        subtitle: entry.type.name,
        urgency: UrgencyLevel.scheduled,
        timestamp: entry.updatedAt,
        module: 'vault',
      );

  @override
  List<Object?> get props => [id, title, urgency, timestamp];
}
