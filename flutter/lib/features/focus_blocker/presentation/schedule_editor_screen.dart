import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

/// Model representing a study schedule entry on the client side.
class StudySchedule {
  final String id;
  final String label;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<int> daysOfWeek; // 0=Sun .. 6=Sat
  final List<String> blockedApps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySchedule({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    required this.blockedApps,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudySchedule.fromJson(Map<String, dynamic> json) => StudySchedule(
        id: json['id'] as String,
        label: json['label'] as String,
        startTime: _parseTime(json['start_time'] as String),
        endTime: _parseTime(json['end_time'] as String),
        daysOfWeek: (json['days_of_week'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
        blockedApps: (json['blocked_apps'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'start_time': _formatTimeForApi(startTime),
        'end_time': _formatTimeForApi(endTime),
        'days_of_week': daysOfWeek,
        'blocked_apps': blockedApps,
      };

  static TimeOfDay _parseTime(String isoString) {
    final dt = DateTime.parse(isoString);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  static String _formatTimeForApi(TimeOfDay tod) {
    // Use today's date so the backend can parse it as a full DateTime.
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    );
    return scheduled.toIso8601String();
  }
}

/// Screen for creating or editing a focus block schedule.
/// Pass an [entry] to edit an existing one; omit to create new.
class ScheduleEditorScreen extends StatefulWidget {
  final StudySchedule? entry;

  const ScheduleEditorScreen({super.key, this.entry});

  @override
  State<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends State<ScheduleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  late TextEditingController _labelController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  // Day-of-week toggles: 0=Sun, 1=Mon, ..., 6=Sat
  late Set<int> _selectedDays;

  // Predefined apps to toggle
  static const List<String> _defaultApps = [
    'Instagram',
    'TikTok',
    'YouTube',
    'Twitter/X',
    'Reddit',
    'Discord',
    'News Apps',
  ];

  late Set<String> _blockedApps;

  // Custom app input
  late TextEditingController _customAppController;
  bool _showCustomInput = false;

  bool _isLoading = false;
  String? _errorMessage;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _labelController =
        TextEditingController(text: widget.entry?.label ?? 'Work Focus');
    _startTime = widget.entry?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = widget.entry?.endTime ?? const TimeOfDay(hour: 12, minute: 0);
    _selectedDays = widget.entry != null
        ? Set<int>.from(widget.entry!.daysOfWeek)
        : {1, 2, 3, 4, 5}; // Default Mon-Fri
    _blockedApps = widget.entry != null
        ? Set<String>.from(widget.entry!.blockedApps)
        : {};
    _customAppController = TextEditingController();

    if (widget.entry != null) {
      _focusedDay = widget.entry!.createdAt;
      _selectedDay = widget.entry!.createdAt;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _customAppController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        if (_selectedDays.length < 7) {
          _selectedDays.add(day);
        }
      }
    });
  }

  void _toggleApp(String app) {
    setState(() {
      if (_blockedApps.contains(app)) {
        _blockedApps.remove(app);
      } else {
        _blockedApps.add(app);
      }
    });
  }

  void _addCustomApp() {
    final app = _customAppController.text.trim();
    if (app.isNotEmpty && !_blockedApps.contains(app)) {
      setState(() {
        _blockedApps.add(app);
        _customAppController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDays.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final schedule = StudySchedule(
        id: widget.entry?.id ?? _uuid.v4(),
        label: _labelController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        daysOfWeek: _selectedDays.toList(),
        blockedApps: _blockedApps.toList(),
        createdAt: widget.entry?.createdAt ?? now,
        updatedAt: now,
      );

      late final dynamic response;
      if (widget.entry == null) {
        response = await ApiClient.dio.post(
          '/schedules',
          data: schedule.toJson(),
        );
      } else {
        response = await ApiClient.dio.put(
          '/schedules/${schedule.id}',
          data: schedule.toJson(),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.entry == null ? 'Schedule created' : 'Schedule updated',
              ),
              backgroundColor: AppColors.resolved(context),
            ),
          );
        }
      } else {
        throw Exception('Unexpected status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Highlight days that are selected
  bool _isDaySelected(DateTime day) {
    final dow = day.weekday; // Monday=1 .. Sunday=7
    // Convert to 0=Sun .. 6=Sat
    final index = dow == 7 ? 0 : dow;
    return _selectedDays.contains(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final accentColor = AppColors.accent(context);
    final bgSurface = AppColors.bgSurface(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Schedule' : 'Edit Schedule'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Label input
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Schedule Label',
                prefixIcon: Icon(Icons.label_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Label is required' : null,
            ),
            const SizedBox(height: 20),

            // Start time picker
            InkWell(
              onTap: _pickStartTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      'Start Time',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _startTime.format(context),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // End time picker
            InkWell(
              onTap: _pickEndTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      'End Time',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _endTime.format(context),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Day-of-week toggles
            const Text(
              'Days of Week',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DayChip(label: 'Sun', index: 0, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Mon', index: 1, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Tue', index: 2, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Wed', index: 3, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Thu', index: 4, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Fri', index: 5, selected: _selectedDays, onTap: _toggleDay),
                _DayChip(label: 'Sat', index: 6, selected: _selectedDays, onTap: _toggleDay),
              ],
            ),
            const SizedBox(height: 20),

            // Calendar view using table_calendar
            Text(
              'Schedule View',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TableCalendar(
                locale: Localizations.localeOf(context).toString(),
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day) || _isDaySelected(day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarFormat: CalendarFormat.week,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: textPrimary),
                  weekendTextStyle: const TextStyle(color: Colors.grey),
                  selectedDecoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),
                daysOfWeekHeight: 40,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Blocked apps section
            const Text(
              'Blocked Apps',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ..._defaultApps.map((app) => _AppToggleRow(
                  appName: app,
                  blocked: _blockedApps.contains(app),
                  onToggle: () => _toggleApp(app),
                )),
            const SizedBox(height: 12),

            // Custom app input
            if (!_showCustomInput)
              TextButton.icon(
                onPressed: () => setState(() => _showCustomInput = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add custom app'),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                  alignment: Alignment.centerLeft,
                ),
              ),
            if (_showCustomInput) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customAppController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Netflix, Spotify',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2D32) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomApp(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.grey),
                    onPressed: _addCustomApp,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => setState(() => _showCustomInput = false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Show already-added custom apps as chips
              ..._blockedApps.where((a) => !_defaultApps.contains(a)).map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _CustomAppChip(
                    label: app,
                    onRemove: () => _toggleApp(app),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            ..._blockedApps.where((a) => !_defaultApps.contains(a)).map(
              (app) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.urgent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.urgent(context)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Day chip ───────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  final String label;
  final int index;
  final Set<int> selected;
  final ValueChanged<int> onTap;

  const _DayChip({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected.contains(index);
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent(context) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── App toggle row ─────────────────────────────────────────────────────────────

class _AppToggleRow extends StatelessWidget {
  final String appName;
  final bool blocked;
  final VoidCallback onToggle;

  const _AppToggleRow({
    required this.appName,
    required this.blocked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: blocked ? AppColors.urgent(context) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: blocked,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.urgent(context),
          ),
        ],
      ),
    );
  }
}

// ── Custom app chip ────────────────────────────────────────────────────────────

class _CustomAppChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _CustomAppChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: AppColors.accent(context).withValues(alpha: 0.15),
    );
  }
}
