import '../core/constants.dart';
import '../core/text.dart';
import '../core/time.dart';
import '../domain/record.dart';

/// 匯出格式第 1 版的 data.json(App 1.x;EXPORT_FORMAT_DRAFT.md 第 5 節)。
/// 後端 export_formats/v1.json 是同一份規則;兩邊都要通過 export_formats/samples/v1.json。
/// 第 0 版(上架前,App 0.x,沒有 digestive)的檔案匯入時由後端轉成第 1 版。
abstract final class ExportFormat {
  /// 格式版本 = App 的主版本號 x(SPEC 第 2 節)。改格式時要升 x,並在後端新增轉換程式。
  static const version = 1;

  static Map<String, Object?> encodeRecord(FeedRecord r, {required bool photosAsPaths}) => {
        'id': r.id,
        'time': TimeRules.isoMinute(r.timeUtcMs),
        'tz_offset': TimeRules.formatOffset(r.tzOffsetMinutes),
        'food_id': r.foodId,
        'prepared_amount': Amount.toJson(r.preparedCenti),
        'prepared_unit_id': r.preparedUnitId,
        'eaten_amount': Amount.toJson(r.eatenCenti),
        'eaten_unit_id': r.eatenUnitId,
        'allergy': r.allergy?.code,
        'reaction': r.reaction?.code,
        'digestive': r.digestive?.code,
        'note': r.note,
        'photos': [for (final id in r.photoIds) photosAsPaths ? 'photos/$id.jpg' : id],
        'created_at': TimeRules.isoMillis(r.createdAtMs),
        'updated_at': TimeRules.isoMillis(r.updatedAtMs),
      };

  /// 解析一筆紀錄;格式不對丟 FormatException(訊息給使用者看)。
  static FeedRecord decodeRecord(Map<String, Object?> j, {required int babySeq, required bool photosAsPaths}) {
    String str(String k) {
      final v = j[k];
      if (v is! String) throw FormatException('紀錄的 $k 格式不對');
      return v;
    }

    int integer(String k, {int min = 1}) {
      final v = j[k];
      if (v is! int || v < min) throw FormatException('紀錄的 $k 格式不對');
      return v;
    }

    int amount(String k) => Amount.fromJson(j[k]) ?? (throw FormatException('紀錄的 $k 要在 0~999.99 之間、最多 2 位小數'));

    final id = str('id');
    if (!isUuid4(id)) throw const FormatException('紀錄編號的格式不對');
    final time = str('time');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:00Z$').hasMatch(time)) throw const FormatException('紀錄時間的格式不對');
    final offset = TimeRules.parseOffset(str('tz_offset'));
    if (offset == null || offset < -12 * 60 || offset > 14 * 60 || offset % 15 != 0) {
      throw const FormatException('時區的格式不對');
    }
    final allergyCode = j['allergy'];
    final reactionCode = j['reaction'];
    // 雲端同步的紀錄可能來自還沒更新的手機(沒有這個欄位),當成沒填;匯入檔則由 parse() 要求一定要有。
    final digestiveCode = j['digestive'];
    if (allergyCode != null && !Allergy.values.any((a) => a.code == allergyCode)) {
      throw const FormatException('過敏狀況的值不對');
    }
    if (reactionCode != null && !Reaction.values.any((r) => r.code == reactionCode)) {
      throw const FormatException('用食反應的值不對');
    }
    if (digestiveCode != null && !Digestive.values.any((d) => d.code == digestiveCode)) {
      throw const FormatException('腹瀉或嘔吐的值不對');
    }
    final note = str('note');
    if (charCount(note) > Limits.noteMaxChars) throw const FormatException('備註超過 500 字');
    final photosRaw = j['photos'];
    if (photosRaw is! List || photosRaw.length > Limits.photosPerRecord) throw const FormatException('照片的格式不對');
    final photoIds = <String>[];
    for (final ph in photosRaw) {
      if (ph is! String) throw const FormatException('照片的格式不對');
      final pid = photosAsPaths ? RegExp(r'^photos/([0-9a-f\-]{36})\.jpg$').firstMatch(ph)?.group(1) : ph;
      if (pid == null || !isUuid4(pid)) throw const FormatException('照片路徑的格式不對');
      photoIds.add(pid);
    }
    final created = TimeRules.parseIso(str('created_at'));
    final updated = TimeRules.parseIso(str('updated_at'));
    final timeMs = TimeRules.parseIso(time);
    if (created == null || updated == null || timeMs == null) throw const FormatException('時間的格式不對');
    return FeedRecord(
      id: id,
      babySeq: babySeq,
      timeUtcMs: timeMs,
      tzOffsetMinutes: offset,
      foodId: integer('food_id'),
      preparedCenti: amount('prepared_amount'),
      preparedUnitId: integer('prepared_unit_id'),
      eatenCenti: amount('eaten_amount'),
      eatenUnitId: integer('eaten_unit_id'),
      allergy: Allergy.fromCode(allergyCode as String?),
      reaction: Reaction.fromCode(reactionCode as String?),
      digestive: Digestive.fromCode(digestiveCode as String?),
      note: note,
      photoIds: photoIds,
      createdAtMs: created,
      updatedAtMs: updated,
    );
  }

  static const _recordKeys = {
    'id', 'time', 'tz_offset', 'food_id', 'prepared_amount', 'prepared_unit_id', 'eaten_amount', 'eaten_unit_id',
    'allergy', 'reaction', 'digestive', 'note', 'photos', 'created_at', 'updated_at',
  };

  /// 整份 data.json 的檢查(匯入第 7 步)。回傳解析好的寶寶與紀錄;不合就丟 FormatException。
  static ParsedExport parse(Map<String, Object?> data) {
    if (data['format_version'] != version) throw const FormatException('格式版本不對');
    final unknownTop = data.keys.toSet().difference({'format_version', 'settings', 'babies'});
    if (unknownTop.isNotEmpty) throw const FormatException('檔案裡有不認得的欄位');
    final settings = data['settings'];
    if (settings is! Map) throw const FormatException('設定的格式不對');
    final week = settings['week_start'];
    final theme = settings['theme'];
    if (!const ['monday', 'sunday'].contains(week) || !const ['dark', 'light', 'system'].contains(theme)) {
      throw const FormatException('設定的值不對');
    }
    final babiesRaw = data['babies'];
    if (babiesRaw is! List || babiesRaw.isEmpty || babiesRaw.length > Limits.maxBabies) {
      throw const FormatException('寶寶要有 1~8 個');
    }
    final babies = <ParsedBaby>[];
    final seenIds = <String>{};
    final seenPhotos = <String>{};
    final seenNames = <String>{};
    final seenSeq = <int>{};
    for (final b in babiesRaw) {
      if (b is! Map) throw const FormatException('寶寶的格式不對');
      final seq = b['seq'];
      final name = b['name'];
      final records = b['records'];
      if (seq is! int || seq < 1 || !seenSeq.add(seq)) throw const FormatException('寶寶序號不對或重複');
      if (name is! String || name.isEmpty || charCount(name) > Limits.babyNameMaxChars || !seenNames.add(name)) {
        throw const FormatException('寶寶名稱不對或重複');
      }
      if (records is! List) throw const FormatException('紀錄的格式不對');
      final parsed = <FeedRecord>[];
      for (final r in records) {
        if (r is! Map) throw const FormatException('紀錄的格式不對');
        final m = r.cast<String, Object?>();
        if (!m.keys.toSet().containsAll(_recordKeys) || m.keys.toSet().difference(_recordKeys).isNotEmpty) {
          throw const FormatException('紀錄的欄位不對');
        }
        final rec = decodeRecord(m, babySeq: seq, photosAsPaths: true);
        if (!seenIds.add(rec.id)) throw const FormatException('紀錄編號重複');
        for (final ph in rec.photoIds) {
          if (!seenPhotos.add(ph)) throw const FormatException('照片重複出現');
        }
        parsed.add(rec);
      }
      babies.add(ParsedBaby(seq: seq, name: name, records: parsed));
    }
    return ParsedExport(weekStart: week as String, theme: theme as String, babies: babies, photoIds: seenPhotos);
  }
}

class ParsedBaby {
  const ParsedBaby({required this.seq, required this.name, required this.records});

  final int seq;
  final String name;
  final List<FeedRecord> records;
}

class ParsedExport {
  const ParsedExport({required this.weekStart, required this.theme, required this.babies, required this.photoIds});

  final String weekStart;
  final String theme;
  final List<ParsedBaby> babies;
  final Set<String> photoIds;
}
