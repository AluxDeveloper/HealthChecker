import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../theme/format.dart';
import '../theme/health.dart';

/// Rezultatul închiderii editorului.
sealed class EditorResult {}

class EditorSaved extends EditorResult {
  EditorSaved(this.task);
  final Task task;
}

class EditorDeleted extends EditorResult {}

/// Deschide foaia modală pentru adăugare (task == null) sau editare.
Future<EditorResult?> showTaskEditor(BuildContext context, {Task? task}) {
  return showCupertinoSheet<EditorResult>(
    context: context,
    scrollableBuilder: (context, controller) =>
        TaskEditorSheet(task: task, scrollController: controller),
  );
}

enum _Picker { none, date, time }

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.task, required this.scrollController});

  final Task? task;
  final ScrollController scrollController;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _dueAt;
  late bool _remind;
  late TaskCategory _category;
  _Picker _picker = _Picker.none;

  bool get _isNew => widget.task == null;
  bool get _canSave => _title.text.trim().isNotEmpty;
  bool get _inPast => _dueAt.isBefore(DateTime.now());

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '')..addListener(_refresh);
    _notes = TextEditingController(text: t?.notes ?? '');
    _dueAt = t?.dueAt ?? _defaultDue();
    _remind = t?.remind ?? true;
    _category = t?.category ?? TaskCategory.general;
  }

  /// Implicit: ora următoare, la fix.
  static DateTime _defaultDue() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _togglePicker(_Picker p) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _picker = _picker == p ? _Picker.none : p);
  }

  void _setQuick(DateTime d) {
    HapticFeedback.selectionClick();
    setState(() {
      _dueAt = d;
      _picker = _Picker.none;
    });
  }

  void _save() {
    if (!_canSave) return;
    final title = _title.text.trim();
    final notes = _notes.text.trim();
    final result =
        widget.task?.copyWith(
          title: title,
          notes: notes,
          category: _category,
          dueAt: _dueAt,
          remind: _remind,
          // dacă o sarcină finalizată e mutată în viitor, redevine activă
          done: _dueAt.isAfter(DateTime.now()) ? false : null,
        ) ??
        Task(
          id: Task.newId(),
          title: title,
          notes: notes,
          category: _category,
          dueAt: _dueAt,
          remind: _remind,
        );
    Navigator.of(context).pop(EditorSaved(result));
  }

  Future<void> _confirmDelete() async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Ștergi această sarcină?'),
        message: const Text(
          'Notificarea va fi anulată. Sarcina rămâne 3 zile în Istoric, '
          'de unde o poți restaura.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge sarcina'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Anulează'),
        ),
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(EditorDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bg,
        border: null,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anulează'),
        ),
        middle: Text(_isNew ? 'Sarcină nouă' : 'Detalii'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canSave ? _save : null,
          child: Text(
            _isNew ? 'Adaugă' : 'Gata',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          controller: widget.scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _categorySection(context),
            _textSection(context),
            _scheduleSection(context),
            _quickPicks(context),
            _reminderSection(context),
            if (!_isNew) _deleteSection(context),
          ],
        ),
      ),
    );
  }

  Widget _categorySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CATEGORIE',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              const gap = 10.0;
              final w = (box.maxWidth - 2 * gap) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final c in TaskCategory.values)
                    SizedBox(
                      width: w,
                      child: _CategoryTile(
                        category: c,
                        selected: c == _category,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _category = c);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _textSection(BuildContext context) {
    final placeholder = CupertinoColors.placeholderText.resolveFrom(context);
    return CupertinoListSection.insetGrouped(
      children: [
        CupertinoTextField.borderless(
          controller: _title,
          autofocus: _isNew,
          placeholder: _category.placeholder,
          placeholderStyle: TextStyle(color: placeholder, fontSize: 17),
          style: const TextStyle(fontSize: 17),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onTap: () => setState(() => _picker = _Picker.none),
        ),
        CupertinoTextField.borderless(
          controller: _notes,
          placeholder: 'Notițe',
          placeholderStyle: TextStyle(color: placeholder, fontSize: 17),
          style: const TextStyle(fontSize: 17),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          onTap: () => setState(() => _picker = _Picker.none),
        ),
      ],
    );
  }

  Widget _scheduleSection(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    Widget value(String text, bool active) => AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: CupertinoTheme.of(context).textTheme.textStyle
          .copyWith(fontSize: 17, color: active ? accent : secondary),
      child: Text(text),
    );

    return CupertinoListSection.insetGrouped(
      children: [
        CupertinoListTile(
          leading: const _IconBadge(
            icon: CupertinoIcons.calendar,
            color: HealthColors.crimson,
          ),
          title: const Text('Data'),
          additionalInfo: value(RoFormat.day(_dueAt), _picker == _Picker.date),
          onTap: () => _togglePicker(_Picker.date),
        ),
        _expandable(
          open: _picker == _Picker.date,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _dueAt,
            showDayOfWeek: true,
            onDateTimeChanged: (d) => setState(() {
              _dueAt = DateTime(
                d.year,
                d.month,
                d.day,
                _dueAt.hour,
                _dueAt.minute,
              );
            }),
          ),
        ),
        CupertinoListTile(
          leading: const _IconBadge(
            icon: CupertinoIcons.clock_fill,
            color: HealthColors.medicalBlue,
          ),
          title: const Text('Ora'),
          additionalInfo: value(RoFormat.time(_dueAt), _picker == _Picker.time),
          onTap: () => _togglePicker(_Picker.time),
        ),
        _expandable(
          open: _picker == _Picker.time,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: _dueAt,
            use24hFormat: true,
            onDateTimeChanged: (d) => setState(() {
              _dueAt = DateTime(
                _dueAt.year,
                _dueAt.month,
                _dueAt.day,
                d.hour,
                d.minute,
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _expandable({required bool open, required Widget child}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: open
          ? SizedBox(height: 216, child: child)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _quickPicks(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picks = <(String, IconData, DateTime)>[
      ('Peste 1 oră', CupertinoIcons.timer, now.add(const Duration(hours: 1))),
      if (now.hour < 19)
        (
          'Diseară',
          CupertinoIcons.moon_fill,
          today.add(const Duration(hours: 20)),
        ),
      (
        'Mâine',
        CupertinoIcons.sunrise_fill,
        today.add(const Duration(days: 1, hours: 9)),
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: picks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, icon, date) = picks[i];
          return _Chip(label: label, icon: icon, onTap: () => _setQuick(date));
        },
      ),
    );
  }

  Widget _reminderSection(BuildContext context) {
    final String footer;
    final bool warn = _remind && _inPast;
    if (!_remind) {
      footer = 'Nu vei primi nicio notificare pentru această sarcină.';
    } else if (warn) {
      footer = 'Ora selectată a trecut — alege o oră din viitor ca să primești notificarea.';
    } else {
      footer =
          'Vei primi o notificare ${RoFormat.dateTime(_dueAt).toLowerCase()}.';
    }

    return CupertinoListSection.insetGrouped(
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          footer,
          style: TextStyle(
            fontSize: 13,
            color: warn
                ? CupertinoColors.systemRed.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
      children: [
        CupertinoListTile(
          leading: const _IconBadge(
            icon: CupertinoIcons.bell_fill,
            color: HealthColors.medicalBlue,
          ),
          title: const Text('Notificare'),
          trailing: CupertinoSwitch(
            activeTrackColor: HealthColors.medicalBlue.resolveFrom(context),
            value: _remind,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _remind = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _deleteSection(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      children: [
        CupertinoListTile(
          title: Center(
            child: Text(
              'Șterge sarcina',
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          ),
          onTap: _confirmDelete,
        ),
      ],
    );
  }
}

/// Pictogramă albă pe pătrat colorat, ca în Setări iOS.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final CupertinoDynamicColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color.resolveFrom(context),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 18),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      minimumSize: const Size(0, 38),
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
        context,
      ),
      borderRadius: BorderRadius.circular(19),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 15, color: accent)),
        ],
      ),
    );
  }
}

/// Plăcuță selectabilă pentru o categorie de sănătate.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color.resolveFrom(context);
    final card = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(color.withValues(alpha: 0.14), card)
              : card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0x00000000),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: CategoryIcon(
                  category,
                  size: 19,
                  color: CupertinoColors.white,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? color
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
