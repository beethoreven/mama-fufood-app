// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BabiesTable extends Babies with TableInfo<$BabiesTable, BabyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BabiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cloudUpdatedAtMeta = const VerificationMeta(
    'cloudUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> cloudUpdatedAt = GeneratedColumn<int>(
    'cloud_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    name,
    createdAt,
    updatedAt,
    deleted,
    dirty,
    cloudUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'babies';
  @override
  VerificationContext validateIntegrity(
    Insertable<BabyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('cloud_updated_at')) {
      context.handle(
        _cloudUpdatedAtMeta,
        cloudUpdatedAt.isAcceptableOrUnknown(
          data['cloud_updated_at']!,
          _cloudUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  BabyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BabyRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      cloudUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cloud_updated_at'],
      ),
    );
  }

  @override
  $BabiesTable createAlias(String alias) {
    return $BabiesTable(attachedDatabase, alias);
  }
}

class BabyRow extends DataClass implements Insertable<BabyRow> {
  final int seq;
  final String name;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final bool dirty;
  final int? cloudUpdatedAt;
  const BabyRow({
    required this.seq,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    this.cloudUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || cloudUpdatedAt != null) {
      map['cloud_updated_at'] = Variable<int>(cloudUpdatedAt);
    }
    return map;
  }

  BabiesCompanion toCompanion(bool nullToAbsent) {
    return BabiesCompanion(
      seq: Value(seq),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      cloudUpdatedAt: cloudUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudUpdatedAt),
    );
  }

  factory BabyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BabyRow(
      seq: serializer.fromJson<int>(json['seq']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      cloudUpdatedAt: serializer.fromJson<int?>(json['cloudUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'cloudUpdatedAt': serializer.toJson<int?>(cloudUpdatedAt),
    };
  }

  BabyRow copyWith({
    int? seq,
    String? name,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    bool? dirty,
    Value<int?> cloudUpdatedAt = const Value.absent(),
  }) => BabyRow(
    seq: seq ?? this.seq,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    cloudUpdatedAt: cloudUpdatedAt.present
        ? cloudUpdatedAt.value
        : this.cloudUpdatedAt,
  );
  BabyRow copyWithCompanion(BabiesCompanion data) {
    return BabyRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      cloudUpdatedAt: data.cloudUpdatedAt.present
          ? data.cloudUpdatedAt.value
          : this.cloudUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BabyRow(')
          ..write('seq: $seq, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('cloudUpdatedAt: $cloudUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    name,
    createdAt,
    updatedAt,
    deleted,
    dirty,
    cloudUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BabyRow &&
          other.seq == this.seq &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.cloudUpdatedAt == this.cloudUpdatedAt);
}

class BabiesCompanion extends UpdateCompanion<BabyRow> {
  final Value<int> seq;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> cloudUpdatedAt;
  const BabiesCompanion({
    this.seq = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.cloudUpdatedAt = const Value.absent(),
  });
  BabiesCompanion.insert({
    this.seq = const Value.absent(),
    required String name,
    required int createdAt,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.cloudUpdatedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BabyRow> custom({
    Expression<int>? seq,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? cloudUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (cloudUpdatedAt != null) 'cloud_updated_at': cloudUpdatedAt,
    });
  }

  BabiesCompanion copyWith({
    Value<int>? seq,
    Value<String>? name,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int?>? cloudUpdatedAt,
  }) {
    return BabiesCompanion(
      seq: seq ?? this.seq,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (cloudUpdatedAt.present) {
      map['cloud_updated_at'] = Variable<int>(cloudUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BabiesCompanion(')
          ..write('seq: $seq, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('cloudUpdatedAt: $cloudUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _babySeqMeta = const VerificationMeta(
    'babySeq',
  );
  @override
  late final GeneratedColumn<int> babySeq = GeneratedColumn<int>(
    'baby_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeUtcMeta = const VerificationMeta(
    'timeUtc',
  );
  @override
  late final GeneratedColumn<int> timeUtc = GeneratedColumn<int>(
    'time_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMeta = const VerificationMeta(
    'tzOffset',
  );
  @override
  late final GeneratedColumn<int> tzOffset = GeneratedColumn<int>(
    'tz_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preparedCentiMeta = const VerificationMeta(
    'preparedCenti',
  );
  @override
  late final GeneratedColumn<int> preparedCenti = GeneratedColumn<int>(
    'prepared_centi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preparedUnitIdMeta = const VerificationMeta(
    'preparedUnitId',
  );
  @override
  late final GeneratedColumn<int> preparedUnitId = GeneratedColumn<int>(
    'prepared_unit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eatenCentiMeta = const VerificationMeta(
    'eatenCenti',
  );
  @override
  late final GeneratedColumn<int> eatenCenti = GeneratedColumn<int>(
    'eaten_centi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eatenUnitIdMeta = const VerificationMeta(
    'eatenUnitId',
  );
  @override
  late final GeneratedColumn<int> eatenUnitId = GeneratedColumn<int>(
    'eaten_unit_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allergyMeta = const VerificationMeta(
    'allergy',
  );
  @override
  late final GeneratedColumn<String> allergy = GeneratedColumn<String>(
    'allergy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionMeta = const VerificationMeta(
    'reaction',
  );
  @override
  late final GeneratedColumn<String> reaction = GeneratedColumn<String>(
    'reaction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _photoIdsMeta = const VerificationMeta(
    'photoIds',
  );
  @override
  late final GeneratedColumn<String> photoIds = GeneratedColumn<String>(
    'photo_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cloudUpdatedAtMeta = const VerificationMeta(
    'cloudUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> cloudUpdatedAt = GeneratedColumn<int>(
    'cloud_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    babySeq,
    timeUtc,
    tzOffset,
    localDay,
    foodId,
    preparedCenti,
    preparedUnitId,
    eatenCenti,
    eatenUnitId,
    allergy,
    reaction,
    note,
    photoIds,
    createdAt,
    updatedAt,
    deleted,
    dirty,
    cloudUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('baby_seq')) {
      context.handle(
        _babySeqMeta,
        babySeq.isAcceptableOrUnknown(data['baby_seq']!, _babySeqMeta),
      );
    } else if (isInserting) {
      context.missing(_babySeqMeta);
    }
    if (data.containsKey('time_utc')) {
      context.handle(
        _timeUtcMeta,
        timeUtc.isAcceptableOrUnknown(data['time_utc']!, _timeUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_timeUtcMeta);
    }
    if (data.containsKey('tz_offset')) {
      context.handle(
        _tzOffsetMeta,
        tzOffset.isAcceptableOrUnknown(data['tz_offset']!, _tzOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('prepared_centi')) {
      context.handle(
        _preparedCentiMeta,
        preparedCenti.isAcceptableOrUnknown(
          data['prepared_centi']!,
          _preparedCentiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preparedCentiMeta);
    }
    if (data.containsKey('prepared_unit_id')) {
      context.handle(
        _preparedUnitIdMeta,
        preparedUnitId.isAcceptableOrUnknown(
          data['prepared_unit_id']!,
          _preparedUnitIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_preparedUnitIdMeta);
    }
    if (data.containsKey('eaten_centi')) {
      context.handle(
        _eatenCentiMeta,
        eatenCenti.isAcceptableOrUnknown(data['eaten_centi']!, _eatenCentiMeta),
      );
    } else if (isInserting) {
      context.missing(_eatenCentiMeta);
    }
    if (data.containsKey('eaten_unit_id')) {
      context.handle(
        _eatenUnitIdMeta,
        eatenUnitId.isAcceptableOrUnknown(
          data['eaten_unit_id']!,
          _eatenUnitIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eatenUnitIdMeta);
    }
    if (data.containsKey('allergy')) {
      context.handle(
        _allergyMeta,
        allergy.isAcceptableOrUnknown(data['allergy']!, _allergyMeta),
      );
    }
    if (data.containsKey('reaction')) {
      context.handle(
        _reactionMeta,
        reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('photo_ids')) {
      context.handle(
        _photoIdsMeta,
        photoIds.isAcceptableOrUnknown(data['photo_ids']!, _photoIdsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('cloud_updated_at')) {
      context.handle(
        _cloudUpdatedAtMeta,
        cloudUpdatedAt.isAcceptableOrUnknown(
          data['cloud_updated_at']!,
          _cloudUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      babySeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baby_seq'],
      )!,
      timeUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_utc'],
      )!,
      tzOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      preparedCenti: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prepared_centi'],
      )!,
      preparedUnitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prepared_unit_id'],
      )!,
      eatenCenti: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eaten_centi'],
      )!,
      eatenUnitId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eaten_unit_id'],
      )!,
      allergy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allergy'],
      ),
      reaction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reaction'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      photoIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_ids'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      cloudUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cloud_updated_at'],
      ),
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final String id;
  final int babySeq;
  final int timeUtc;
  final int tzOffset;

  /// 月曆上的日期(yyyy-mm-dd),由 timeUtc + tzOffset 算出,存起來方便查詢。
  final String localDay;
  final int foodId;
  final int preparedCenti;
  final int preparedUnitId;
  final int eatenCenti;
  final int eatenUnitId;
  final String? allergy;
  final String? reaction;
  final String note;

  /// 照片的編號,依順序以逗號分隔(最多 3 張)。
  final String photoIds;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  /// 還沒上傳到雲端的修改。
  final bool dirty;

  /// 上次同步時雲端那一份的 updatedAt;用來分辨「雲端有沒有被別人改過」。
  final int? cloudUpdatedAt;
  const RecordRow({
    required this.id,
    required this.babySeq,
    required this.timeUtc,
    required this.tzOffset,
    required this.localDay,
    required this.foodId,
    required this.preparedCenti,
    required this.preparedUnitId,
    required this.eatenCenti,
    required this.eatenUnitId,
    this.allergy,
    this.reaction,
    required this.note,
    required this.photoIds,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    this.cloudUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['baby_seq'] = Variable<int>(babySeq);
    map['time_utc'] = Variable<int>(timeUtc);
    map['tz_offset'] = Variable<int>(tzOffset);
    map['local_day'] = Variable<String>(localDay);
    map['food_id'] = Variable<int>(foodId);
    map['prepared_centi'] = Variable<int>(preparedCenti);
    map['prepared_unit_id'] = Variable<int>(preparedUnitId);
    map['eaten_centi'] = Variable<int>(eatenCenti);
    map['eaten_unit_id'] = Variable<int>(eatenUnitId);
    if (!nullToAbsent || allergy != null) {
      map['allergy'] = Variable<String>(allergy);
    }
    if (!nullToAbsent || reaction != null) {
      map['reaction'] = Variable<String>(reaction);
    }
    map['note'] = Variable<String>(note);
    map['photo_ids'] = Variable<String>(photoIds);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || cloudUpdatedAt != null) {
      map['cloud_updated_at'] = Variable<int>(cloudUpdatedAt);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      babySeq: Value(babySeq),
      timeUtc: Value(timeUtc),
      tzOffset: Value(tzOffset),
      localDay: Value(localDay),
      foodId: Value(foodId),
      preparedCenti: Value(preparedCenti),
      preparedUnitId: Value(preparedUnitId),
      eatenCenti: Value(eatenCenti),
      eatenUnitId: Value(eatenUnitId),
      allergy: allergy == null && nullToAbsent
          ? const Value.absent()
          : Value(allergy),
      reaction: reaction == null && nullToAbsent
          ? const Value.absent()
          : Value(reaction),
      note: Value(note),
      photoIds: Value(photoIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      cloudUpdatedAt: cloudUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudUpdatedAt),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<String>(json['id']),
      babySeq: serializer.fromJson<int>(json['babySeq']),
      timeUtc: serializer.fromJson<int>(json['timeUtc']),
      tzOffset: serializer.fromJson<int>(json['tzOffset']),
      localDay: serializer.fromJson<String>(json['localDay']),
      foodId: serializer.fromJson<int>(json['foodId']),
      preparedCenti: serializer.fromJson<int>(json['preparedCenti']),
      preparedUnitId: serializer.fromJson<int>(json['preparedUnitId']),
      eatenCenti: serializer.fromJson<int>(json['eatenCenti']),
      eatenUnitId: serializer.fromJson<int>(json['eatenUnitId']),
      allergy: serializer.fromJson<String?>(json['allergy']),
      reaction: serializer.fromJson<String?>(json['reaction']),
      note: serializer.fromJson<String>(json['note']),
      photoIds: serializer.fromJson<String>(json['photoIds']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      cloudUpdatedAt: serializer.fromJson<int?>(json['cloudUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'babySeq': serializer.toJson<int>(babySeq),
      'timeUtc': serializer.toJson<int>(timeUtc),
      'tzOffset': serializer.toJson<int>(tzOffset),
      'localDay': serializer.toJson<String>(localDay),
      'foodId': serializer.toJson<int>(foodId),
      'preparedCenti': serializer.toJson<int>(preparedCenti),
      'preparedUnitId': serializer.toJson<int>(preparedUnitId),
      'eatenCenti': serializer.toJson<int>(eatenCenti),
      'eatenUnitId': serializer.toJson<int>(eatenUnitId),
      'allergy': serializer.toJson<String?>(allergy),
      'reaction': serializer.toJson<String?>(reaction),
      'note': serializer.toJson<String>(note),
      'photoIds': serializer.toJson<String>(photoIds),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'cloudUpdatedAt': serializer.toJson<int?>(cloudUpdatedAt),
    };
  }

  RecordRow copyWith({
    String? id,
    int? babySeq,
    int? timeUtc,
    int? tzOffset,
    String? localDay,
    int? foodId,
    int? preparedCenti,
    int? preparedUnitId,
    int? eatenCenti,
    int? eatenUnitId,
    Value<String?> allergy = const Value.absent(),
    Value<String?> reaction = const Value.absent(),
    String? note,
    String? photoIds,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    bool? dirty,
    Value<int?> cloudUpdatedAt = const Value.absent(),
  }) => RecordRow(
    id: id ?? this.id,
    babySeq: babySeq ?? this.babySeq,
    timeUtc: timeUtc ?? this.timeUtc,
    tzOffset: tzOffset ?? this.tzOffset,
    localDay: localDay ?? this.localDay,
    foodId: foodId ?? this.foodId,
    preparedCenti: preparedCenti ?? this.preparedCenti,
    preparedUnitId: preparedUnitId ?? this.preparedUnitId,
    eatenCenti: eatenCenti ?? this.eatenCenti,
    eatenUnitId: eatenUnitId ?? this.eatenUnitId,
    allergy: allergy.present ? allergy.value : this.allergy,
    reaction: reaction.present ? reaction.value : this.reaction,
    note: note ?? this.note,
    photoIds: photoIds ?? this.photoIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    cloudUpdatedAt: cloudUpdatedAt.present
        ? cloudUpdatedAt.value
        : this.cloudUpdatedAt,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      babySeq: data.babySeq.present ? data.babySeq.value : this.babySeq,
      timeUtc: data.timeUtc.present ? data.timeUtc.value : this.timeUtc,
      tzOffset: data.tzOffset.present ? data.tzOffset.value : this.tzOffset,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      preparedCenti: data.preparedCenti.present
          ? data.preparedCenti.value
          : this.preparedCenti,
      preparedUnitId: data.preparedUnitId.present
          ? data.preparedUnitId.value
          : this.preparedUnitId,
      eatenCenti: data.eatenCenti.present
          ? data.eatenCenti.value
          : this.eatenCenti,
      eatenUnitId: data.eatenUnitId.present
          ? data.eatenUnitId.value
          : this.eatenUnitId,
      allergy: data.allergy.present ? data.allergy.value : this.allergy,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      note: data.note.present ? data.note.value : this.note,
      photoIds: data.photoIds.present ? data.photoIds.value : this.photoIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      cloudUpdatedAt: data.cloudUpdatedAt.present
          ? data.cloudUpdatedAt.value
          : this.cloudUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('babySeq: $babySeq, ')
          ..write('timeUtc: $timeUtc, ')
          ..write('tzOffset: $tzOffset, ')
          ..write('localDay: $localDay, ')
          ..write('foodId: $foodId, ')
          ..write('preparedCenti: $preparedCenti, ')
          ..write('preparedUnitId: $preparedUnitId, ')
          ..write('eatenCenti: $eatenCenti, ')
          ..write('eatenUnitId: $eatenUnitId, ')
          ..write('allergy: $allergy, ')
          ..write('reaction: $reaction, ')
          ..write('note: $note, ')
          ..write('photoIds: $photoIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('cloudUpdatedAt: $cloudUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    babySeq,
    timeUtc,
    tzOffset,
    localDay,
    foodId,
    preparedCenti,
    preparedUnitId,
    eatenCenti,
    eatenUnitId,
    allergy,
    reaction,
    note,
    photoIds,
    createdAt,
    updatedAt,
    deleted,
    dirty,
    cloudUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.id == this.id &&
          other.babySeq == this.babySeq &&
          other.timeUtc == this.timeUtc &&
          other.tzOffset == this.tzOffset &&
          other.localDay == this.localDay &&
          other.foodId == this.foodId &&
          other.preparedCenti == this.preparedCenti &&
          other.preparedUnitId == this.preparedUnitId &&
          other.eatenCenti == this.eatenCenti &&
          other.eatenUnitId == this.eatenUnitId &&
          other.allergy == this.allergy &&
          other.reaction == this.reaction &&
          other.note == this.note &&
          other.photoIds == this.photoIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.cloudUpdatedAt == this.cloudUpdatedAt);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> id;
  final Value<int> babySeq;
  final Value<int> timeUtc;
  final Value<int> tzOffset;
  final Value<String> localDay;
  final Value<int> foodId;
  final Value<int> preparedCenti;
  final Value<int> preparedUnitId;
  final Value<int> eatenCenti;
  final Value<int> eatenUnitId;
  final Value<String?> allergy;
  final Value<String?> reaction;
  final Value<String> note;
  final Value<String> photoIds;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int?> cloudUpdatedAt;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.babySeq = const Value.absent(),
    this.timeUtc = const Value.absent(),
    this.tzOffset = const Value.absent(),
    this.localDay = const Value.absent(),
    this.foodId = const Value.absent(),
    this.preparedCenti = const Value.absent(),
    this.preparedUnitId = const Value.absent(),
    this.eatenCenti = const Value.absent(),
    this.eatenUnitId = const Value.absent(),
    this.allergy = const Value.absent(),
    this.reaction = const Value.absent(),
    this.note = const Value.absent(),
    this.photoIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.cloudUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required int babySeq,
    required int timeUtc,
    required int tzOffset,
    required String localDay,
    required int foodId,
    required int preparedCenti,
    required int preparedUnitId,
    required int eatenCenti,
    required int eatenUnitId,
    this.allergy = const Value.absent(),
    this.reaction = const Value.absent(),
    this.note = const Value.absent(),
    this.photoIds = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.cloudUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       babySeq = Value(babySeq),
       timeUtc = Value(timeUtc),
       tzOffset = Value(tzOffset),
       localDay = Value(localDay),
       foodId = Value(foodId),
       preparedCenti = Value(preparedCenti),
       preparedUnitId = Value(preparedUnitId),
       eatenCenti = Value(eatenCenti),
       eatenUnitId = Value(eatenUnitId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecordRow> custom({
    Expression<String>? id,
    Expression<int>? babySeq,
    Expression<int>? timeUtc,
    Expression<int>? tzOffset,
    Expression<String>? localDay,
    Expression<int>? foodId,
    Expression<int>? preparedCenti,
    Expression<int>? preparedUnitId,
    Expression<int>? eatenCenti,
    Expression<int>? eatenUnitId,
    Expression<String>? allergy,
    Expression<String>? reaction,
    Expression<String>? note,
    Expression<String>? photoIds,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? cloudUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (babySeq != null) 'baby_seq': babySeq,
      if (timeUtc != null) 'time_utc': timeUtc,
      if (tzOffset != null) 'tz_offset': tzOffset,
      if (localDay != null) 'local_day': localDay,
      if (foodId != null) 'food_id': foodId,
      if (preparedCenti != null) 'prepared_centi': preparedCenti,
      if (preparedUnitId != null) 'prepared_unit_id': preparedUnitId,
      if (eatenCenti != null) 'eaten_centi': eatenCenti,
      if (eatenUnitId != null) 'eaten_unit_id': eatenUnitId,
      if (allergy != null) 'allergy': allergy,
      if (reaction != null) 'reaction': reaction,
      if (note != null) 'note': note,
      if (photoIds != null) 'photo_ids': photoIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (cloudUpdatedAt != null) 'cloud_updated_at': cloudUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<int>? babySeq,
    Value<int>? timeUtc,
    Value<int>? tzOffset,
    Value<String>? localDay,
    Value<int>? foodId,
    Value<int>? preparedCenti,
    Value<int>? preparedUnitId,
    Value<int>? eatenCenti,
    Value<int>? eatenUnitId,
    Value<String?>? allergy,
    Value<String?>? reaction,
    Value<String>? note,
    Value<String>? photoIds,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int?>? cloudUpdatedAt,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      babySeq: babySeq ?? this.babySeq,
      timeUtc: timeUtc ?? this.timeUtc,
      tzOffset: tzOffset ?? this.tzOffset,
      localDay: localDay ?? this.localDay,
      foodId: foodId ?? this.foodId,
      preparedCenti: preparedCenti ?? this.preparedCenti,
      preparedUnitId: preparedUnitId ?? this.preparedUnitId,
      eatenCenti: eatenCenti ?? this.eatenCenti,
      eatenUnitId: eatenUnitId ?? this.eatenUnitId,
      allergy: allergy ?? this.allergy,
      reaction: reaction ?? this.reaction,
      note: note ?? this.note,
      photoIds: photoIds ?? this.photoIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (babySeq.present) {
      map['baby_seq'] = Variable<int>(babySeq.value);
    }
    if (timeUtc.present) {
      map['time_utc'] = Variable<int>(timeUtc.value);
    }
    if (tzOffset.present) {
      map['tz_offset'] = Variable<int>(tzOffset.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (preparedCenti.present) {
      map['prepared_centi'] = Variable<int>(preparedCenti.value);
    }
    if (preparedUnitId.present) {
      map['prepared_unit_id'] = Variable<int>(preparedUnitId.value);
    }
    if (eatenCenti.present) {
      map['eaten_centi'] = Variable<int>(eatenCenti.value);
    }
    if (eatenUnitId.present) {
      map['eaten_unit_id'] = Variable<int>(eatenUnitId.value);
    }
    if (allergy.present) {
      map['allergy'] = Variable<String>(allergy.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<String>(reaction.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (photoIds.present) {
      map['photo_ids'] = Variable<String>(photoIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (cloudUpdatedAt.present) {
      map['cloud_updated_at'] = Variable<int>(cloudUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('babySeq: $babySeq, ')
          ..write('timeUtc: $timeUtc, ')
          ..write('tzOffset: $tzOffset, ')
          ..write('localDay: $localDay, ')
          ..write('foodId: $foodId, ')
          ..write('preparedCenti: $preparedCenti, ')
          ..write('preparedUnitId: $preparedUnitId, ')
          ..write('eatenCenti: $eatenCenti, ')
          ..write('eatenUnitId: $eatenUnitId, ')
          ..write('allergy: $allergy, ')
          ..write('reaction: $reaction, ')
          ..write('note: $note, ')
          ..write('photoIds: $photoIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('cloudUpdatedAt: $cloudUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasLocalMeta = const VerificationMeta(
    'hasLocal',
  );
  @override
  late final GeneratedColumn<bool> hasLocal = GeneratedColumn<bool>(
    'has_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_local" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _cloudFileIdMeta = const VerificationMeta(
    'cloudFileId',
  );
  @override
  late final GeneratedColumn<String> cloudFileId = GeneratedColumn<String>(
    'cloud_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudMd5Meta = const VerificationMeta(
    'cloudMd5',
  );
  @override
  late final GeneratedColumn<String> cloudMd5 = GeneratedColumn<String>(
    'cloud_md5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deleteFromCloudMeta = const VerificationMeta(
    'deleteFromCloud',
  );
  @override
  late final GeneratedColumn<bool> deleteFromCloud = GeneratedColumn<bool>(
    'delete_from_cloud',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("delete_from_cloud" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    hasLocal,
    cloudFileId,
    cloudMd5,
    deleteFromCloud,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('has_local')) {
      context.handle(
        _hasLocalMeta,
        hasLocal.isAcceptableOrUnknown(data['has_local']!, _hasLocalMeta),
      );
    }
    if (data.containsKey('cloud_file_id')) {
      context.handle(
        _cloudFileIdMeta,
        cloudFileId.isAcceptableOrUnknown(
          data['cloud_file_id']!,
          _cloudFileIdMeta,
        ),
      );
    }
    if (data.containsKey('cloud_md5')) {
      context.handle(
        _cloudMd5Meta,
        cloudMd5.isAcceptableOrUnknown(data['cloud_md5']!, _cloudMd5Meta),
      );
    }
    if (data.containsKey('delete_from_cloud')) {
      context.handle(
        _deleteFromCloudMeta,
        deleteFromCloud.isAcceptableOrUnknown(
          data['delete_from_cloud']!,
          _deleteFromCloudMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      hasLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_local'],
      )!,
      cloudFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_file_id'],
      ),
      cloudMd5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_md5'],
      ),
      deleteFromCloud: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}delete_from_cloud'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final String id;
  final String recordId;
  final bool hasLocal;
  final String? cloudFileId;
  final String? cloudMd5;

  /// 紀錄或照片已經刪了,但雲端那一份還沒刪掉(登入後補刪)。
  final bool deleteFromCloud;
  final int createdAt;
  const PhotoRow({
    required this.id,
    required this.recordId,
    required this.hasLocal,
    this.cloudFileId,
    this.cloudMd5,
    required this.deleteFromCloud,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['record_id'] = Variable<String>(recordId);
    map['has_local'] = Variable<bool>(hasLocal);
    if (!nullToAbsent || cloudFileId != null) {
      map['cloud_file_id'] = Variable<String>(cloudFileId);
    }
    if (!nullToAbsent || cloudMd5 != null) {
      map['cloud_md5'] = Variable<String>(cloudMd5);
    }
    map['delete_from_cloud'] = Variable<bool>(deleteFromCloud);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      recordId: Value(recordId),
      hasLocal: Value(hasLocal),
      cloudFileId: cloudFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudFileId),
      cloudMd5: cloudMd5 == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudMd5),
      deleteFromCloud: Value(deleteFromCloud),
      createdAt: Value(createdAt),
    );
  }

  factory PhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      id: serializer.fromJson<String>(json['id']),
      recordId: serializer.fromJson<String>(json['recordId']),
      hasLocal: serializer.fromJson<bool>(json['hasLocal']),
      cloudFileId: serializer.fromJson<String?>(json['cloudFileId']),
      cloudMd5: serializer.fromJson<String?>(json['cloudMd5']),
      deleteFromCloud: serializer.fromJson<bool>(json['deleteFromCloud']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordId': serializer.toJson<String>(recordId),
      'hasLocal': serializer.toJson<bool>(hasLocal),
      'cloudFileId': serializer.toJson<String?>(cloudFileId),
      'cloudMd5': serializer.toJson<String?>(cloudMd5),
      'deleteFromCloud': serializer.toJson<bool>(deleteFromCloud),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PhotoRow copyWith({
    String? id,
    String? recordId,
    bool? hasLocal,
    Value<String?> cloudFileId = const Value.absent(),
    Value<String?> cloudMd5 = const Value.absent(),
    bool? deleteFromCloud,
    int? createdAt,
  }) => PhotoRow(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    hasLocal: hasLocal ?? this.hasLocal,
    cloudFileId: cloudFileId.present ? cloudFileId.value : this.cloudFileId,
    cloudMd5: cloudMd5.present ? cloudMd5.value : this.cloudMd5,
    deleteFromCloud: deleteFromCloud ?? this.deleteFromCloud,
    createdAt: createdAt ?? this.createdAt,
  );
  PhotoRow copyWithCompanion(PhotosCompanion data) {
    return PhotoRow(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      hasLocal: data.hasLocal.present ? data.hasLocal.value : this.hasLocal,
      cloudFileId: data.cloudFileId.present
          ? data.cloudFileId.value
          : this.cloudFileId,
      cloudMd5: data.cloudMd5.present ? data.cloudMd5.value : this.cloudMd5,
      deleteFromCloud: data.deleteFromCloud.present
          ? data.deleteFromCloud.value
          : this.deleteFromCloud,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('hasLocal: $hasLocal, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudMd5: $cloudMd5, ')
          ..write('deleteFromCloud: $deleteFromCloud, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordId,
    hasLocal,
    cloudFileId,
    cloudMd5,
    deleteFromCloud,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.hasLocal == this.hasLocal &&
          other.cloudFileId == this.cloudFileId &&
          other.cloudMd5 == this.cloudMd5 &&
          other.deleteFromCloud == this.deleteFromCloud &&
          other.createdAt == this.createdAt);
}

class PhotosCompanion extends UpdateCompanion<PhotoRow> {
  final Value<String> id;
  final Value<String> recordId;
  final Value<bool> hasLocal;
  final Value<String?> cloudFileId;
  final Value<String?> cloudMd5;
  final Value<bool> deleteFromCloud;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.hasLocal = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudMd5 = const Value.absent(),
    this.deleteFromCloud = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String id,
    required String recordId,
    this.hasLocal = const Value.absent(),
    this.cloudFileId = const Value.absent(),
    this.cloudMd5 = const Value.absent(),
    this.deleteFromCloud = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordId = Value(recordId),
       createdAt = Value(createdAt);
  static Insertable<PhotoRow> custom({
    Expression<String>? id,
    Expression<String>? recordId,
    Expression<bool>? hasLocal,
    Expression<String>? cloudFileId,
    Expression<String>? cloudMd5,
    Expression<bool>? deleteFromCloud,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (hasLocal != null) 'has_local': hasLocal,
      if (cloudFileId != null) 'cloud_file_id': cloudFileId,
      if (cloudMd5 != null) 'cloud_md5': cloudMd5,
      if (deleteFromCloud != null) 'delete_from_cloud': deleteFromCloud,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? recordId,
    Value<bool>? hasLocal,
    Value<String?>? cloudFileId,
    Value<String?>? cloudMd5,
    Value<bool>? deleteFromCloud,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      hasLocal: hasLocal ?? this.hasLocal,
      cloudFileId: cloudFileId ?? this.cloudFileId,
      cloudMd5: cloudMd5 ?? this.cloudMd5,
      deleteFromCloud: deleteFromCloud ?? this.deleteFromCloud,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (hasLocal.present) {
      map['has_local'] = Variable<bool>(hasLocal.value);
    }
    if (cloudFileId.present) {
      map['cloud_file_id'] = Variable<String>(cloudFileId.value);
    }
    if (cloudMd5.present) {
      map['cloud_md5'] = Variable<String>(cloudMd5.value);
    }
    if (deleteFromCloud.present) {
      map['delete_from_cloud'] = Variable<bool>(deleteFromCloud.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('hasLocal: $hasLocal, ')
          ..write('cloudFileId: $cloudFileId, ')
          ..write('cloudMd5: $cloudMd5, ')
          ..write('deleteFromCloud: $deleteFromCloud, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DatasetsTable extends Datasets
    with TableInfo<$DatasetsTable, DatasetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatasetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, version, formatVersion, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'datasets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatasetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  DatasetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatasetRow(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $DatasetsTable createAlias(String alias) {
    return $DatasetsTable(attachedDatabase, alias);
  }
}

class DatasetRow extends DataClass implements Insertable<DatasetRow> {
  final String name;
  final String version;
  final int formatVersion;
  final String content;
  const DatasetRow({
    required this.name,
    required this.version,
    required this.formatVersion,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    map['format_version'] = Variable<int>(formatVersion);
    map['content'] = Variable<String>(content);
    return map;
  }

  DatasetsCompanion toCompanion(bool nullToAbsent) {
    return DatasetsCompanion(
      name: Value(name),
      version: Value(version),
      formatVersion: Value(formatVersion),
      content: Value(content),
    );
  }

  factory DatasetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatasetRow(
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'content': serializer.toJson<String>(content),
    };
  }

  DatasetRow copyWith({
    String? name,
    String? version,
    int? formatVersion,
    String? content,
  }) => DatasetRow(
    name: name ?? this.name,
    version: version ?? this.version,
    formatVersion: formatVersion ?? this.formatVersion,
    content: content ?? this.content,
  );
  DatasetRow copyWithCompanion(DatasetsCompanion data) {
    return DatasetRow(
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatasetRow(')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, version, formatVersion, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetRow &&
          other.name == this.name &&
          other.version == this.version &&
          other.formatVersion == this.formatVersion &&
          other.content == this.content);
}

class DatasetsCompanion extends UpdateCompanion<DatasetRow> {
  final Value<String> name;
  final Value<String> version;
  final Value<int> formatVersion;
  final Value<String> content;
  final Value<int> rowid;
  const DatasetsCompanion({
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DatasetsCompanion.insert({
    required String name,
    required String version,
    required int formatVersion,
    required String content,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       version = Value(version),
       formatVersion = Value(formatVersion),
       content = Value(content);
  static Insertable<DatasetRow> custom({
    Expression<String>? name,
    Expression<String>? version,
    Expression<int>? formatVersion,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (formatVersion != null) 'format_version': formatVersion,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DatasetsCompanion copyWith({
    Value<String>? name,
    Value<String>? version,
    Value<int>? formatVersion,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return DatasetsCompanion(
      name: name ?? this.name,
      version: version ?? this.version,
      formatVersion: formatVersion ?? this.formatVersion,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatasetsCompanion(')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $BabiesTable babies = $BabiesTable(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DatasetsTable datasets = $DatasetsTable(this);
  late final Index recordsBabyDay = Index(
    'records_baby_day',
    'CREATE INDEX records_baby_day ON records (baby_seq, local_day)',
  );
  late final Index recordsBabyFood = Index(
    'records_baby_food',
    'CREATE INDEX records_baby_food ON records (baby_seq, food_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    babies,
    records,
    photos,
    settings,
    datasets,
    recordsBabyDay,
    recordsBabyFood,
  ];
}

typedef $$BabiesTableCreateCompanionBuilder = BabiesCompanion Function({
  Value<int> seq,
  required String name,
  required int createdAt,
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> cloudUpdatedAt,
});
typedef $$BabiesTableUpdateCompanionBuilder = BabiesCompanion Function({
  Value<int> seq,
  Value<String> name,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> cloudUpdatedAt,
});

class $$BabiesTableFilterComposer extends Composer<_$AppDb, $BabiesTable> {
  $$BabiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BabiesTableOrderingComposer extends Composer<_$AppDb, $BabiesTable> {
  $$BabiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BabiesTableAnnotationComposer extends Composer<_$AppDb, $BabiesTable> {
  $$BabiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => column,
  );
}

class $$BabiesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $BabiesTable,
          BabyRow,
          $$BabiesTableFilterComposer,
          $$BabiesTableOrderingComposer,
          $$BabiesTableAnnotationComposer,
          $$BabiesTableCreateCompanionBuilder,
          $$BabiesTableUpdateCompanionBuilder,
          (BabyRow, BaseReferences<_$AppDb, $BabiesTable, BabyRow>),
          BabyRow,
          PrefetchHooks Function()
        > {
  $$BabiesTableTableManager(_$AppDb db, $BabiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BabiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BabiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BabiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> cloudUpdatedAt = const Value.absent(),
              }) => BabiesCompanion(
                seq: seq,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                cloudUpdatedAt: cloudUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String name,
                required int createdAt,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> cloudUpdatedAt = const Value.absent(),
              }) => BabiesCompanion.insert(
                seq: seq,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                cloudUpdatedAt: cloudUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BabiesTable, BabyRow>(table),
                  BaseReferences<_$AppDb, $BabiesTable, BabyRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BabiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $BabiesTable,
      BabyRow,
      $$BabiesTableFilterComposer,
      $$BabiesTableOrderingComposer,
      $$BabiesTableAnnotationComposer,
      $$BabiesTableCreateCompanionBuilder,
      $$BabiesTableUpdateCompanionBuilder,
      (BabyRow, BaseReferences<_$AppDb, $BabiesTable, BabyRow>),
      BabyRow,
      PrefetchHooks Function()
    >;
typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String id,
  required int babySeq,
  required int timeUtc,
  required int tzOffset,
  required String localDay,
  required int foodId,
  required int preparedCenti,
  required int preparedUnitId,
  required int eatenCenti,
  required int eatenUnitId,
  Value<String?> allergy,
  Value<String?> reaction,
  Value<String> note,
  Value<String> photoIds,
  required int createdAt,
  required int updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> cloudUpdatedAt,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> id,
  Value<int> babySeq,
  Value<int> timeUtc,
  Value<int> tzOffset,
  Value<String> localDay,
  Value<int> foodId,
  Value<int> preparedCenti,
  Value<int> preparedUnitId,
  Value<int> eatenCenti,
  Value<int> eatenUnitId,
  Value<String?> allergy,
  Value<String?> reaction,
  Value<String> note,
  Value<String> photoIds,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int?> cloudUpdatedAt,
  Value<int> rowid,
});

class $$RecordsTableFilterComposer extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get babySeq => $composableBuilder(
    column: $table.babySeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeUtc => $composableBuilder(
    column: $table.timeUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffset => $composableBuilder(
    column: $table.tzOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preparedCenti => $composableBuilder(
    column: $table.preparedCenti,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get preparedUnitId => $composableBuilder(
    column: $table.preparedUnitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eatenCenti => $composableBuilder(
    column: $table.eatenCenti,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eatenUnitId => $composableBuilder(
    column: $table.eatenUnitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allergy => $composableBuilder(
    column: $table.allergy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoIds => $composableBuilder(
    column: $table.photoIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordsTableOrderingComposer extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get babySeq => $composableBuilder(
    column: $table.babySeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeUtc => $composableBuilder(
    column: $table.timeUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffset => $composableBuilder(
    column: $table.tzOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preparedCenti => $composableBuilder(
    column: $table.preparedCenti,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get preparedUnitId => $composableBuilder(
    column: $table.preparedUnitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eatenCenti => $composableBuilder(
    column: $table.eatenCenti,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eatenUnitId => $composableBuilder(
    column: $table.eatenUnitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allergy => $composableBuilder(
    column: $table.allergy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoIds => $composableBuilder(
    column: $table.photoIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDb, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get babySeq =>
      $composableBuilder(column: $table.babySeq, builder: (column) => column);

  GeneratedColumn<int> get timeUtc =>
      $composableBuilder(column: $table.timeUtc, builder: (column) => column);

  GeneratedColumn<int> get tzOffset =>
      $composableBuilder(column: $table.tzOffset, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<int> get foodId =>
      $composableBuilder(column: $table.foodId, builder: (column) => column);

  GeneratedColumn<int> get preparedCenti => $composableBuilder(
    column: $table.preparedCenti,
    builder: (column) => column,
  );

  GeneratedColumn<int> get preparedUnitId => $composableBuilder(
    column: $table.preparedUnitId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eatenCenti => $composableBuilder(
    column: $table.eatenCenti,
    builder: (column) => column,
  );

  GeneratedColumn<int> get eatenUnitId => $composableBuilder(
    column: $table.eatenUnitId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get allergy =>
      $composableBuilder(column: $table.allergy, builder: (column) => column);

  GeneratedColumn<String> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get photoIds =>
      $composableBuilder(column: $table.photoIds, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get cloudUpdatedAt => $composableBuilder(
    column: $table.cloudUpdatedAt,
    builder: (column) => column,
  );
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (RecordRow, BaseReferences<_$AppDb, $RecordsTable, RecordRow>),
          RecordRow,
          PrefetchHooks Function()
        > {
  $$RecordsTableTableManager(_$AppDb db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> babySeq = const Value.absent(),
                Value<int> timeUtc = const Value.absent(),
                Value<int> tzOffset = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<int> preparedCenti = const Value.absent(),
                Value<int> preparedUnitId = const Value.absent(),
                Value<int> eatenCenti = const Value.absent(),
                Value<int> eatenUnitId = const Value.absent(),
                Value<String?> allergy = const Value.absent(),
                Value<String?> reaction = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> photoIds = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> cloudUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                babySeq: babySeq,
                timeUtc: timeUtc,
                tzOffset: tzOffset,
                localDay: localDay,
                foodId: foodId,
                preparedCenti: preparedCenti,
                preparedUnitId: preparedUnitId,
                eatenCenti: eatenCenti,
                eatenUnitId: eatenUnitId,
                allergy: allergy,
                reaction: reaction,
                note: note,
                photoIds: photoIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                cloudUpdatedAt: cloudUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int babySeq,
                required int timeUtc,
                required int tzOffset,
                required String localDay,
                required int foodId,
                required int preparedCenti,
                required int preparedUnitId,
                required int eatenCenti,
                required int eatenUnitId,
                Value<String?> allergy = const Value.absent(),
                Value<String?> reaction = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> photoIds = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int?> cloudUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                babySeq: babySeq,
                timeUtc: timeUtc,
                tzOffset: tzOffset,
                localDay: localDay,
                foodId: foodId,
                preparedCenti: preparedCenti,
                preparedUnitId: preparedUnitId,
                eatenCenti: eatenCenti,
                eatenUnitId: eatenUnitId,
                allergy: allergy,
                reaction: reaction,
                note: note,
                photoIds: photoIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                cloudUpdatedAt: cloudUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, RecordRow>(table),
                  BaseReferences<_$AppDb, $RecordsTable, RecordRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, BaseReferences<_$AppDb, $RecordsTable, RecordRow>),
      RecordRow,
      PrefetchHooks Function()
    >;
typedef $$PhotosTableCreateCompanionBuilder = PhotosCompanion Function({
  required String id,
  required String recordId,
  Value<bool> hasLocal,
  Value<String?> cloudFileId,
  Value<String?> cloudMd5,
  Value<bool> deleteFromCloud,
  required int createdAt,
  Value<int> rowid,
});
typedef $$PhotosTableUpdateCompanionBuilder = PhotosCompanion Function({
  Value<String> id,
  Value<String> recordId,
  Value<bool> hasLocal,
  Value<String?> cloudFileId,
  Value<String?> cloudMd5,
  Value<bool> deleteFromCloud,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$PhotosTableFilterComposer extends Composer<_$AppDb, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLocal => $composableBuilder(
    column: $table.hasLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudFileId => $composableBuilder(
    column: $table.cloudFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudMd5 => $composableBuilder(
    column: $table.cloudMd5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleteFromCloud => $composableBuilder(
    column: $table.deleteFromCloud,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotosTableOrderingComposer extends Composer<_$AppDb, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLocal => $composableBuilder(
    column: $table.hasLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudFileId => $composableBuilder(
    column: $table.cloudFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudMd5 => $composableBuilder(
    column: $table.cloudMd5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleteFromCloud => $composableBuilder(
    column: $table.deleteFromCloud,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosTableAnnotationComposer extends Composer<_$AppDb, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<bool> get hasLocal =>
      $composableBuilder(column: $table.hasLocal, builder: (column) => column);

  GeneratedColumn<String> get cloudFileId => $composableBuilder(
    column: $table.cloudFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cloudMd5 =>
      $composableBuilder(column: $table.cloudMd5, builder: (column) => column);

  GeneratedColumn<bool> get deleteFromCloud => $composableBuilder(
    column: $table.deleteFromCloud,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PhotosTable,
          PhotoRow,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (PhotoRow, BaseReferences<_$AppDb, $PhotosTable, PhotoRow>),
          PhotoRow,
          PrefetchHooks Function()
        > {
  $$PhotosTableTableManager(_$AppDb db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<bool> hasLocal = const Value.absent(),
                Value<String?> cloudFileId = const Value.absent(),
                Value<String?> cloudMd5 = const Value.absent(),
                Value<bool> deleteFromCloud = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                id: id,
                recordId: recordId,
                hasLocal: hasLocal,
                cloudFileId: cloudFileId,
                cloudMd5: cloudMd5,
                deleteFromCloud: deleteFromCloud,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordId,
                Value<bool> hasLocal = const Value.absent(),
                Value<String?> cloudFileId = const Value.absent(),
                Value<String?> cloudMd5 = const Value.absent(),
                Value<bool> deleteFromCloud = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                id: id,
                recordId: recordId,
                hasLocal: hasLocal,
                cloudFileId: cloudFileId,
                cloudMd5: cloudMd5,
                deleteFromCloud: deleteFromCloud,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotosTable, PhotoRow>(table),
                  BaseReferences<_$AppDb, $PhotosTable, PhotoRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PhotosTable,
      PhotoRow,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (PhotoRow, BaseReferences<_$AppDb, $PhotosTable, PhotoRow>),
      PhotoRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDb, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$AppDb, $SettingsTable, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDb db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDb, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDb, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$DatasetsTableCreateCompanionBuilder = DatasetsCompanion Function({
  required String name,
  required String version,
  required int formatVersion,
  required String content,
  Value<int> rowid,
});
typedef $$DatasetsTableUpdateCompanionBuilder = DatasetsCompanion Function({
  Value<String> name,
  Value<String> version,
  Value<int> formatVersion,
  Value<String> content,
  Value<int> rowid,
});

class $$DatasetsTableFilterComposer extends Composer<_$AppDb, $DatasetsTable> {
  $$DatasetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatasetsTableOrderingComposer
    extends Composer<_$AppDb, $DatasetsTable> {
  $$DatasetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatasetsTableAnnotationComposer
    extends Composer<_$AppDb, $DatasetsTable> {
  $$DatasetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$DatasetsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $DatasetsTable,
          DatasetRow,
          $$DatasetsTableFilterComposer,
          $$DatasetsTableOrderingComposer,
          $$DatasetsTableAnnotationComposer,
          $$DatasetsTableCreateCompanionBuilder,
          $$DatasetsTableUpdateCompanionBuilder,
          (DatasetRow, BaseReferences<_$AppDb, $DatasetsTable, DatasetRow>),
          DatasetRow,
          PrefetchHooks Function()
        > {
  $$DatasetsTableTableManager(_$AppDb db, $DatasetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatasetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatasetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatasetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DatasetsCompanion(
                name: name,
                version: version,
                formatVersion: formatVersion,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String version,
                required int formatVersion,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => DatasetsCompanion.insert(
                name: name,
                version: version,
                formatVersion: formatVersion,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatasetsTable, DatasetRow>(table),
                  BaseReferences<_$AppDb, $DatasetsTable, DatasetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatasetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $DatasetsTable,
      DatasetRow,
      $$DatasetsTableFilterComposer,
      $$DatasetsTableOrderingComposer,
      $$DatasetsTableAnnotationComposer,
      $$DatasetsTableCreateCompanionBuilder,
      $$DatasetsTableUpdateCompanionBuilder,
      (DatasetRow, BaseReferences<_$AppDb, $DatasetsTable, DatasetRow>),
      DatasetRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$BabiesTableTableManager get babies =>
      $$BabiesTableTableManager(_db, _db.babies);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DatasetsTableTableManager get datasets =>
      $$DatasetsTableTableManager(_db, _db.datasets);
}
