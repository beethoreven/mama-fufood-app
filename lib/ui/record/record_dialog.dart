import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/log.dart';
import '../../core/text.dart';
import '../../core/time.dart';
import '../../data/store.dart';
import '../../domain/catalog.dart';
import '../../domain/judgement.dart';
import '../../domain/record.dart';
import '../../services/photo_service.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/wheel_picker.dart';

/// 新增 / 檢視 / 編輯紀錄(SPEC 第 7 節):疊在畫面上、不滿版、內部可捲動,
/// 按鈕固定在最下方。檢視:關閉、修改、刪除(刪除要二次確認);修改:取消、儲存。
Future<void> showRecordDialog(BuildContext context, {required int babySeq, required Day day, String? recordId}) =>
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordDialog(babySeq: babySeq, day: day, recordId: recordId),
    );

enum _Mode { add, view, edit }

class _Draft {
  _Draft({
    required this.day,
    required this.hour,
    required this.minute,
    required this.tzOffset,
    this.groupId,
    this.foodId,
    required this.preparedCenti,
    required this.preparedUnitId,
    required this.eatenCenti,
    required this.eatenUnitId,
    this.allergy,
    this.reaction,
    this.note = '',
    required this.photos,
  });

  Day day;
  int hour;
  int minute;
  int tzOffset;
  int? groupId;
  int? foodId;
  int preparedCenti;
  int preparedUnitId;
  int eatenCenti;
  int eatenUnitId;
  Allergy? allergy;
  Reaction? reaction;
  String note;
  List<DraftPhoto> photos;

  String signature() => [
        day, hour, minute, groupId, foodId, preparedCenti, preparedUnitId, eatenCenti, eatenUnitId,
        allergy, reaction, note, photos.map((p) => p.id).join(','),
      ].join('|');
}

class RecordDialog extends ConsumerStatefulWidget {
  const RecordDialog({super.key, required this.babySeq, required this.day, this.recordId});

  final int babySeq;
  final Day day;
  final String? recordId;

  @override
  ConsumerState<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends ConsumerState<RecordDialog> {
  late _Mode _mode;
  _Draft? _draft;
  FeedRecord? _original;
  String _savedSignature = '';
  bool _busy = false;
  final _prepared = TextEditingController();
  final _eaten = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.recordId == null ? _Mode.add : _Mode.view;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _prepared.dispose();
    _eaten.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final catalog = await ref.read(catalogProvider.future);
    if (widget.recordId == null) {
      final now = TimeRules.now();
      final unit = catalog.defaultUnit.id;
      _setDraft(_Draft(
        day: widget.day,
        hour: now.hour,
        minute: now.minute,
        tzOffset: TimeRules.currentOffsetMinutes(),
        preparedCenti: 0,
        preparedUnitId: unit,
        eatenCenti: 0,
        eatenUnitId: unit,
        photos: [],
      ));
    } else {
      final r = await ref.read(storeProvider).record(widget.recordId!);
      if (r == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      _original = r;
      _setDraft(_fromRecord(r, catalog));
    }
  }

  _Draft _fromRecord(FeedRecord r, Catalog catalog) {
    final local = r.localTime;
    return _Draft(
      day: r.day,
      hour: local.hour,
      minute: local.minute,
      tzOffset: r.tzOffsetMinutes,
      groupId: catalog.groupOfFood(r.foodId)?.id,
      foodId: r.foodId,
      preparedCenti: r.preparedCenti,
      preparedUnitId: r.preparedUnitId,
      eatenCenti: r.eatenCenti,
      eatenUnitId: r.eatenUnitId,
      allergy: r.allergy,
      reaction: r.reaction,
      note: r.note,
      photos: [for (final id in r.photoIds) DraftPhoto.existing(id)],
    );
  }

  void _setDraft(_Draft d) {
    setState(() {
      _draft = d;
      _prepared.text = Amount.format(d.preparedCenti);
      _eaten.text = Amount.format(d.eatenCenti);
      _note.text = d.note;
      _savedSignature = d.signature();
    });
  }

  bool get _readOnly => _mode == _Mode.view;

  bool get _changed => _draft != null && _draft!.signature() != _savedSignature;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final d = _draft;
    final c = context.colors;
    final title = switch (_mode) { _Mode.add => '新增紀錄', _Mode.view => '紀錄', _Mode.edit => '修改紀錄' };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
        child: d == null || catalog == null
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                ),
                Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: _form(d, catalog))),
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _buttons(),
                ),
              ]),
      ),
    );
  }

  Widget _section(String label, Widget child, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            ?trailing,
          ]),
          const SizedBox(height: 6),
          child,
        ]),
      );

  Widget _form(_Draft d, Catalog catalog) {
    final daysInMonth = DateTime.utc(d.day.year, d.day.month + 1, 0).day;
    final groups = [
      ...catalog.selectableGroups(),
      if (d.groupId != null && !catalog.selectableGroups().any((g) => g.id == d.groupId) && catalog.group(d.groupId!) != null)
        catalog.group(d.groupId!)!,
    ];
    final foods = d.groupId == null
        ? <Food>[]
        : [
            ...catalog.selectableFoods(d.groupId!),
            if (d.foodId != null &&
                catalog.food(d.foodId!)?.groupId == d.groupId &&
                !catalog.selectableFoods(d.groupId!).any((f) => f.id == d.foodId))
              catalog.food(d.foodId!)!,
          ];
    final units = catalog.selectableUnits();
    final unitChoices = {
      for (final u in [...units, catalog.unit(d.preparedUnitId), catalog.unit(d.eatenUnitId)].whereType<Unit>()) u.id: u,
    }.values.toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));

    // 和頁籤 3「食材判斷」同一個結果(SPEC 第 8 節):這個食材全部已存的紀錄,包含正在看的這一筆;
    // 修改中還沒儲存的內容不算。
    final history = knownOnly(ref.watch(allRecordsProvider(widget.babySeq)).value ?? const [], catalog)
        .where((r) => r.foodId == d.foodId)
        .toList();
    final allergy = d.foodId == null ? null : judgeAllergy(history);
    final preference = d.foodId == null ? null : judgePreference(history, today: Day.of(TimeRules.now()));

    String two(int v) => v.toString().padLeft(2, '0');
    Future<void> pick<T>(String title, List<T> items, T? current, String Function(T) label, void Function(T) apply) async {
      if (_readOnly) return;
      final v = await showWheelPicker<T>(context, title: title, items: items, initial: current, label: label);
      if (v != null) setState(() => apply(v));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. 年月日 + 時:分(24 小時制),日期不限制,未來日期也可記錄。
      _section('日期與時間', Wrap(spacing: 6, runSpacing: 6, children: [
        PickerButton(
          enabled: !_readOnly,
          text: '${d.day.year} 年',
          onTap: () => pick('年', [for (var y = Limits.yearMin; y <= Limits.yearMax; y++) y], d.day.year, (y) => '$y 年',
              (y) => d.day = Day(y, d.day.month, d.day.day.clamp(1, DateTime.utc(y, d.day.month + 1, 0).day))),
        ),
        PickerButton(
          enabled: !_readOnly,
          text: '${d.day.month} 月',
          onTap: () => pick('月', [for (var m = 1; m <= 12; m++) m], d.day.month, (m) => '$m 月',
              (m) => d.day = Day(d.day.year, m, d.day.day.clamp(1, DateTime.utc(d.day.year, m + 1, 0).day))),
        ),
        PickerButton(
          enabled: !_readOnly,
          text: '${d.day.day} 日',
          onTap: () => pick('日', [for (var x = 1; x <= daysInMonth; x++) x], d.day.day, (x) => '$x 日',
              (x) => d.day = Day(d.day.year, d.day.month, x)),
        ),
        PickerButton(
          enabled: !_readOnly,
          text: '${two(d.hour)} 時',
          onTap: () => pick('時', [for (var h = 0; h < 24; h++) h], d.hour, (h) => '${two(h)} 時', (h) => d.hour = h),
        ),
        PickerButton(
          enabled: !_readOnly,
          text: '${two(d.minute)} 分',
          onTap: () => pick('分', [for (var m = 0; m < 60; m++) m], d.minute, (m) => '${two(m)} 分', (m) => d.minute = m),
        ),
      ])),
      // 2. 分組 → 食材(選分組後才解鎖)。右側:喜好、過敏圖示(只顯示)。
      _section(
        '分組與食材',
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PickerButton(
            enabled: !_readOnly,
            text: d.groupId == null ? '選分組' : '${catalog.group(d.groupId!)?.emoji ?? ''} ${catalog.group(d.groupId!)?.name ?? ''}',
            onTap: () => pick<FoodGroup>('分組', groups, d.groupId == null ? null : catalog.group(d.groupId!),
                (g) => '${g.emoji} ${g.name}', (g) {
              if (g.id != d.groupId) {
                // 已選食材後又改分組:食材清空(喜好、過敏圖示也跟著清空)。
                d.groupId = g.id;
                d.foodId = null;
              }
            }),
          ),
          PickerButton(
            enabled: !_readOnly && d.groupId != null,
            text: d.foodId == null ? '選食材' : '${catalog.food(d.foodId!)?.emoji ?? ''} ${catalog.food(d.foodId!)?.name ?? ''}',
            onTap: () => pick<Food>('食材', foods, d.foodId == null ? null : catalog.food(d.foodId!),
                (f) => '${f.emoji} ${f.name}', (f) => d.foodId = f.id),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          PreferenceIcon(preference, size: 24),
          AllergyIcon(allergy, size: 24),
        ]),
      ),
      // 3. 準備量、食用量:各自的單位;準備量只做紀錄。
      _section('準備量', _amountRow(_prepared, d.preparedUnitId, unitChoices, (v) => d.preparedCenti = v, (u) => d.preparedUnitId = u)),
      _section('食用量', _amountRow(_eaten, d.eatenUnitId, unitChoices, (v) => d.eatenCenti = v, (u) => d.eatenUnitId = u)),
      // 4. 過敏狀況(單選,再點可取消,預設未選 = 不納入運算)。
      _section(
        '過敏狀況',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IgnorePointer(
            ignoring: _readOnly,
            child: ChoiceChips<Allergy>(
              options: Allergy.display,
              value: d.allergy,
              label: (a) => a.label,
              onChanged: (a) => setState(() => d.allergy = a),
            ),
          ),
          const SizedBox(height: 4),
          Text('同一天吃多種食材時，請依你的判斷標記。', style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
      // 5. 用食反應。
      _section(
        '用食反應',
        IgnorePointer(
          ignoring: _readOnly,
          child: ChoiceChips<Reaction>(
            options: Reaction.values,
            value: d.reaction,
            label: (r) => r.label,
            onChanged: (r) => setState(() => d.reaction = r),
          ),
        ),
      ),
      // 6. 備註、照片(從相簿選,最多 3 張;拍照功能預留)。
      _section(
        '備註',
        TextField(
          controller: _note,
          readOnly: _readOnly,
          maxLength: Limits.noteMaxChars,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(hintText: _readOnly ? '沒有備註' : '可以不填'),
          onChanged: (v) => setState(() => d.note = v),
        ),
      ),
      _section('照片', _photos(d)),
      // 7. 免責提醒。
      const DisclaimerText(Disclaimers.record),
    ]);
  }

  Widget _amountRow(TextEditingController controller, int unitId, List<Unit> units, ValueChanged<int> onAmount,
      ValueChanged<int> onUnit) {
    final unit = units.where((u) => u.id == unitId).firstOrNull;
    return Row(children: [
      SizedBox(
        width: 120,
        child: TextField(
          controller: controller,
          readOnly: _readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // 0~999.99、最多 2 位小數,輸入時就限制。
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?'))],
          onChanged: (v) => setState(() => onAmount(Amount.parse(v) ?? 0)),
          onTap: () {
            if (!_readOnly && controller.text == '0') controller.clear();
          },
        ),
      ),
      const SizedBox(width: 8),
      PickerButton(
        enabled: !_readOnly,
        text: unit?.name ?? '單位',
        onTap: () async {
          if (_readOnly) return;
          final u = await showWheelPicker<Unit>(context, title: '單位', items: units, initial: unit, label: (u) => u.name);
          if (u != null) setState(() => onUnit(u.id));
        },
      ),
    ]);
  }

  Widget _photos(_Draft d) {
    final photos = ref.read(servicesProvider).photos;
    final c = context.colors;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final p in d.photos)
        GestureDetector(
          onTap: () => _viewPhoto(p, d),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 84, height: 84, child: PhotoThumb(photo: p, service: photos)),
          ),
        ),
      if (!_readOnly && d.photos.length < Limits.photosPerRecord)
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final picked = await photos.pick(Limits.photosPerRecord - d.photos.length);
                    setState(() => d.photos = [...d.photos, ...picked]);
                  } catch (e, st) {
                    AppLog.error('photo.pick_failed', e, st);
                    if (mounted) toast(context, '照片沒有加進來，請再試一次');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          icon: Icon(Icons.add_photo_alternate_rounded, color: c.accent),
          label: const Text('加入照片'),
        ),
      if (_readOnly && d.photos.isEmpty) Text('沒有照片', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Future<void> _viewPhoto(DraftPhoto p, _Draft d) async {
    final service = ref.read(servicesProvider).photos;
    final remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
            child: PhotoThumb(photo: p, service: service, fit: BoxFit.contain),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (!_readOnly) TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('移除這張照片')),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('關閉')),
          ]),
        ]),
      ),
    );
    if (remove == true) setState(() => d.photos = d.photos.where((x) => x.id != p.id).toList());
  }

  Widget _buttons() {
    final c = context.colors;
    if (_mode == _Mode.view) {
      return Row(children: [
        TextButton(
          onPressed: _busy ? null : _delete,
          child: Text('刪除', style: TextStyle(color: c.danger)),
        ),
        const Spacer(),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        const SizedBox(width: 8),
        FilledButton(onPressed: _busy ? null : _startEdit, child: const Text('修改')),
      ]);
    }
    return Row(children: [
      const Spacer(),
      OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('取消')),
      const SizedBox(width: 8),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('儲存')),
    ]);
  }

  Future<void> _startEdit() async {
    setState(() => _busy = true);
    // 進入修改時先比對雲端版本(SPEC 第 4、7 節);沒開同步或連不上就用手機上的版本。
    final changed = await ref.read(servicesProvider).sync.refreshBeforeEdit(widget.recordId!);
    if (!mounted) return;
    if (changed) {
      final r = await ref.read(storeProvider).record(widget.recordId!);
      final catalog = await ref.read(catalogProvider.future);
      if (r != null) {
        _original = r;
        _setDraft(_fromRecord(r, catalog));
        if (mounted) toast(context, '雲端有比較新的版本，已經更新成最新的內容');
      }
    }
    setState(() {
      _busy = false;
      _mode = _Mode.edit;
    });
  }

  Future<void> _cancel() async {
    if (_mode == _Mode.view) {
      Navigator.pop(context);
      return;
    }
    if (_changed) {
      final ok = await confirm(context,
          title: _mode == _Mode.edit ? '放棄修改？' : '放棄這筆紀錄？', message: '剛剛輸入的內容不會儲存。', ok: '放棄');
      if (!ok || !mounted) return;
    }
    await ref.read(servicesProvider).photos.discardDraft(_draft?.photos ?? const []);
    if (!mounted) return;
    if (_mode == _Mode.edit) {
      final catalog = await ref.read(catalogProvider.future);
      _setDraft(_fromRecord(_original!, catalog));
      setState(() => _mode = _Mode.view);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final d = _draft!;
    if (d.groupId == null || d.foodId == null) {
      toast(context, '請選擇分組與食材');
      return;
    }
    setState(() => _busy = true);
    final services = ref.read(servicesProvider);
    final isNew = _mode == _Mode.add;
    final id = widget.recordId ?? newId();
    try {
      final timeUtc = TimeRules.toUtcMs(d.day, d.hour, d.minute, d.tzOffset);
      final draftRecord = FeedRecord(
        id: id,
        babySeq: widget.babySeq,
        timeUtcMs: timeUtc,
        tzOffsetMinutes: d.tzOffset,
        foodId: d.foodId!,
        preparedCenti: d.preparedCenti,
        preparedUnitId: d.preparedUnitId,
        eatenCenti: d.eatenCenti,
        eatenUnitId: d.eatenUnitId,
        allergy: d.allergy,
        reaction: d.reaction,
        note: d.note.trim(),
        photoIds: [for (final p in d.photos) p.id],
        createdAtMs: _original?.createdAtMs ?? 0,
        updatedAtMs: 0,
      );
      // 先檢查(每日 10 筆),通過才動照片。
      final store = ref.read(storeProvider);
      if (await store.countOnDay(widget.babySeq, draftRecord.day, exceptId: isNew ? null : id) >= Limits.recordsPerDay) {
        throw const InputProblem('這一天已經有 ${Limits.recordsPerDay} 筆紀錄了');
      }
      await store.db.transaction(() async {
        await services.photos.stageDraft(recordId: id, photos: d.photos);
        await store.saveRecord(draftRecord, isNew: isNew);
      });
      await services.photos.afterCommit(photos: d.photos, previous: _original?.photoIds ?? const []);
      AppLog.info(isNew ? 'record.added' : 'record.updated', {'photos': d.photos.length});
      services.sync.requestSoon();
      if (!mounted) return;
      if (isNew) {
        Navigator.pop(context);
      } else {
        final saved = await store.record(id);
        final catalog = await ref.read(catalogProvider.future);
        if (saved != null) {
          _original = saved;
          _setDraft(_fromRecord(saved, catalog));
        }
        setState(() => _mode = _Mode.view);
      }
    } on InputProblem catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e, st) {
      AppLog.error('record.save_failed', e, st);
      if (mounted) toast(context, '儲存失敗，請再試一次');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: '刪除這筆紀錄？', message: '刪除後無法復原。', ok: '刪除', danger: true);
    if (!ok || !mounted) return;
    final services = ref.read(servicesProvider);
    final record = _original!;
    // 先關掉這個視窗,再刪(月曆的當日清單會跟著更新)。
    Navigator.pop(context);
    await ref.read(storeProvider).deleteRecord(record.id);
    await services.photos.onRecordDeleted(record.photoIds);
    AppLog.info('record.deleted');
    services.sync.requestSoon();
  }
}

/// 照片縮圖:本機有就直接顯示;只在雲端的話先下載(沒網路時顯示提示)。
class PhotoThumb extends StatefulWidget {
  const PhotoThumb({super.key, required this.photo, required this.service, this.fit = BoxFit.cover});

  final DraftPhoto photo;
  final PhotoService service;
  final BoxFit fit;

  @override
  State<PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<PhotoThumb> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoThumb old) {
    super.didUpdateWidget(old);
    if (old.photo.id != widget.photo.id) _load();
  }

  void _load() => _file = widget.photo.file != null ? Future.value(widget.photo.file) : widget.service.resolve(widget.photo.id);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fit = widget.fit;
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(color: c.surface2, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final f = snap.data;
        if (f == null) {
          return Container(
            color: c.surface2,
            padding: const EdgeInsets.all(6),
            alignment: Alignment.center,
            child: Text('照片目前\n無法顯示', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          );
        }
        return Image.file(f, fit: fit, cacheWidth: fit == BoxFit.cover ? 256 : null);
      },
    );
  }
}
