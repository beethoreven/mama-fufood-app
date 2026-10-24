import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// 資料列的類別名稱都加上 Row:`Record` 會和 Dart 內建的 Record 型別撞名,`Baby` 會和畫面用的 Baby 撞名。

/// 本機資料庫(SPEC 第 4 節:紀錄永遠存本機,斷網不影響一般使用)。
///
/// - 每筆紀錄有 UUID 與最後修改時間;刪除用標記(避免同步後「復活」)。
/// - 時間存 UTC,並同時存記錄當下的時區偏移。
/// - 檔案放在 App 的 files/db/,Android 自動備份只備份這個資料夾
///   (android/app/src/main/res/xml/,照片、診斷記錄、待送的意見回饋都不備份)。

/// 寶寶。序號是「第幾個寶寶」,新增時往後加、刪除後不重複使用(SPEC 第 4 節「匯出檔內容」)。
/// 不另外給隱藏編號;寶寶以名字辨識,改名就當成不同的寶寶。
@DataClassName('BabyRow')
class Babies extends Table {
  IntColumn get seq => integer()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  IntColumn get cloudUpdatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {seq};
}

@DataClassName('RecordRow')
@TableIndex(name: 'records_baby_day', columns: {#babySeq, #localDay})
@TableIndex(name: 'records_baby_food', columns: {#babySeq, #foodId})
class Records extends Table {
  TextColumn get id => text()();
  IntColumn get babySeq => integer()();
  IntColumn get timeUtc => integer()();
  IntColumn get tzOffset => integer()();
  /// 月曆上的日期(yyyy-mm-dd),由 timeUtc + tzOffset 算出,存起來方便查詢。
  TextColumn get localDay => text()();
  IntColumn get foodId => integer()();
  IntColumn get preparedCenti => integer()();
  IntColumn get preparedUnitId => integer()();
  IntColumn get eatenCenti => integer()();
  IntColumn get eatenUnitId => integer()();
  TextColumn get allergy => text().nullable()();
  TextColumn get reaction => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  /// 照片的編號,依順序以逗號分隔(最多 3 張)。
  TextColumn get photoIds => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  /// 還沒上傳到雲端的修改。
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  /// 上次同步時雲端那一份的 updatedAt;用來分辨「雲端有沒有被別人改過」。
  IntColumn get cloudUpdatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 照片的存放狀態。照片本身是 files/photos/{id}.jpg,或只在雲端。
@DataClassName('PhotoRow')
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get recordId => text()();
  BoolColumn get hasLocal => boolean().withDefault(const Constant(true))();
  TextColumn get cloudFileId => text().nullable()();
  TextColumn get cloudMd5 => text().nullable()();
  /// 紀錄或照片已經刪了,但雲端那一份還沒刪掉(登入後補刪)。
  BoolColumn get deleteFromCloud => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 下載到的公用資料(沒有的話用 App 內建的初始檔)。
@DataClassName('DatasetRow')
class Datasets extends Table {
  TextColumn get name => text()();
  TextColumn get version => text()();
  IntColumn get formatVersion => integer()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {name};
}

@DriftDatabase(tables: [Babies, Records, Photos, Settings, Datasets])
class AppDb extends _$AppDb {
  AppDb(super.e);

  /// 正式的資料庫檔:files/db/mff.sqlite。
  factory AppDb.open() => AppDb(driftDatabase(
        name: 'mff',
        native: DriftNativeOptions(databasePath: () async {
          final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'db'));
          await dir.create(recursive: true);
          return p.join(dir.path, 'mff.sqlite');
        }),
      ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
