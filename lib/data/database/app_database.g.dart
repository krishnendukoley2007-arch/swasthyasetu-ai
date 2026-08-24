// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PatientsTable extends Patients
    with TableInfo<$PatientsTable, PatientRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScreenedAtMeta = const VerificationMeta(
    'lastScreenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScreenedAt =
      GeneratedColumn<DateTime>(
        'last_screened_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _vulnerabilityFlagsMeta =
      const VerificationMeta('vulnerabilityFlags');
  @override
  late final GeneratedColumn<String> vulnerabilityFlags =
      GeneratedColumn<String>(
        'vulnerability_flags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    age,
    sex,
    location,
    phone,
    notes,
    createdAt,
    lastScreenedAt,
    vulnerabilityFlags,
    isDemo,
    syncStatus,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patients';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatientRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    } else if (isInserting) {
      context.missing(_sexMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
    if (data.containsKey('last_screened_at')) {
      context.handle(
        _lastScreenedAtMeta,
        lastScreenedAt.isAcceptableOrUnknown(
          data['last_screened_at']!,
          _lastScreenedAtMeta,
        ),
      );
    }
    if (data.containsKey('vulnerability_flags')) {
      context.handle(
        _vulnerabilityFlagsMeta,
        vulnerabilityFlags.isAcceptableOrUnknown(
          data['vulnerability_flags']!,
          _vulnerabilityFlagsMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatientRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastScreenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_screened_at'],
      ),
      vulnerabilityFlags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vulnerability_flags'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $PatientsTable createAlias(String alias) {
    return $PatientsTable(attachedDatabase, alias);
  }
}

class PatientRow extends DataClass implements Insertable<PatientRow> {
  final String id;
  final String name;
  final int age;
  final String sex;
  final String? location;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastScreenedAt;

  /// JSON array of vulnerability flag ids: `elderly`, `chronic`, `pregnant`,
  /// `infant`, `immunocompromised`. These shift rule thresholds — see
  /// `RiskEngine.thresholdsFor`.
  final String vulnerabilityFlags;
  final bool isDemo;
  final String syncStatus;
  final int retryCount;
  const PatientRow({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    this.location,
    this.phone,
    this.notes,
    required this.createdAt,
    this.lastScreenedAt,
    required this.vulnerabilityFlags,
    required this.isDemo,
    required this.syncStatus,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['age'] = Variable<int>(age);
    map['sex'] = Variable<String>(sex);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastScreenedAt != null) {
      map['last_screened_at'] = Variable<DateTime>(lastScreenedAt);
    }
    map['vulnerability_flags'] = Variable<String>(vulnerabilityFlags);
    map['is_demo'] = Variable<bool>(isDemo);
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  PatientsCompanion toCompanion(bool nullToAbsent) {
    return PatientsCompanion(
      id: Value(id),
      name: Value(name),
      age: Value(age),
      sex: Value(sex),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      lastScreenedAt: lastScreenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScreenedAt),
      vulnerabilityFlags: Value(vulnerabilityFlags),
      isDemo: Value(isDemo),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
    );
  }

  factory PatientRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      age: serializer.fromJson<int>(json['age']),
      sex: serializer.fromJson<String>(json['sex']),
      location: serializer.fromJson<String?>(json['location']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastScreenedAt: serializer.fromJson<DateTime?>(json['lastScreenedAt']),
      vulnerabilityFlags: serializer.fromJson<String>(
        json['vulnerabilityFlags'],
      ),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'age': serializer.toJson<int>(age),
      'sex': serializer.toJson<String>(sex),
      'location': serializer.toJson<String?>(location),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastScreenedAt': serializer.toJson<DateTime?>(lastScreenedAt),
      'vulnerabilityFlags': serializer.toJson<String>(vulnerabilityFlags),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  PatientRow copyWith({
    String? id,
    String? name,
    int? age,
    String? sex,
    Value<String?> location = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastScreenedAt = const Value.absent(),
    String? vulnerabilityFlags,
    bool? isDemo,
    String? syncStatus,
    int? retryCount,
  }) => PatientRow(
    id: id ?? this.id,
    name: name ?? this.name,
    age: age ?? this.age,
    sex: sex ?? this.sex,
    location: location.present ? location.value : this.location,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    lastScreenedAt: lastScreenedAt.present
        ? lastScreenedAt.value
        : this.lastScreenedAt,
    vulnerabilityFlags: vulnerabilityFlags ?? this.vulnerabilityFlags,
    isDemo: isDemo ?? this.isDemo,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
  );
  PatientRow copyWithCompanion(PatientsCompanion data) {
    return PatientRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      age: data.age.present ? data.age.value : this.age,
      sex: data.sex.present ? data.sex.value : this.sex,
      location: data.location.present ? data.location.value : this.location,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastScreenedAt: data.lastScreenedAt.present
          ? data.lastScreenedAt.value
          : this.lastScreenedAt,
      vulnerabilityFlags: data.vulnerabilityFlags.present
          ? data.vulnerabilityFlags.value
          : this.vulnerabilityFlags,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('sex: $sex, ')
          ..write('location: $location, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastScreenedAt: $lastScreenedAt, ')
          ..write('vulnerabilityFlags: $vulnerabilityFlags, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    age,
    sex,
    location,
    phone,
    notes,
    createdAt,
    lastScreenedAt,
    vulnerabilityFlags,
    isDemo,
    syncStatus,
    retryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.age == this.age &&
          other.sex == this.sex &&
          other.location == this.location &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.lastScreenedAt == this.lastScreenedAt &&
          other.vulnerabilityFlags == this.vulnerabilityFlags &&
          other.isDemo == this.isDemo &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount);
}

class PatientsCompanion extends UpdateCompanion<PatientRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> age;
  final Value<String> sex;
  final Value<String?> location;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastScreenedAt;
  final Value<String> vulnerabilityFlags;
  final Value<bool> isDemo;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<int> rowid;
  const PatientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.age = const Value.absent(),
    this.sex = const Value.absent(),
    this.location = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastScreenedAt = const Value.absent(),
    this.vulnerabilityFlags = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatientsCompanion.insert({
    required String id,
    required String name,
    required int age,
    required String sex,
    this.location = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.lastScreenedAt = const Value.absent(),
    this.vulnerabilityFlags = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       age = Value(age),
       sex = Value(sex),
       createdAt = Value(createdAt);
  static Insertable<PatientRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? age,
    Expression<String>? sex,
    Expression<String>? location,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastScreenedAt,
    Expression<String>? vulnerabilityFlags,
    Expression<bool>? isDemo,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (sex != null) 'sex': sex,
      if (location != null) 'location': location,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (lastScreenedAt != null) 'last_screened_at': lastScreenedAt,
      if (vulnerabilityFlags != null) 'vulnerability_flags': vulnerabilityFlags,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatientsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? age,
    Value<String>? sex,
    Value<String?>? location,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastScreenedAt,
    Value<String>? vulnerabilityFlags,
    Value<bool>? isDemo,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return PatientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastScreenedAt: lastScreenedAt ?? this.lastScreenedAt,
      vulnerabilityFlags: vulnerabilityFlags ?? this.vulnerabilityFlags,
      isDemo: isDemo ?? this.isDemo,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastScreenedAt.present) {
      map['last_screened_at'] = Variable<DateTime>(lastScreenedAt.value);
    }
    if (vulnerabilityFlags.present) {
      map['vulnerability_flags'] = Variable<String>(vulnerabilityFlags.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('sex: $sex, ')
          ..write('location: $location, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastScreenedAt: $lastScreenedAt, ')
          ..write('vulnerabilityFlags: $vulnerabilityFlags, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScreeningsTable extends Screenings
    with TableInfo<$ScreeningsTable, ScreeningRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScreeningsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientIdMeta = const VerificationMeta(
    'patientId',
  );
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
    'patient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNKNOWN'),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heartRateMeta = const VerificationMeta(
    'heartRate',
  );
  @override
  late final GeneratedColumn<int> heartRate = GeneratedColumn<int>(
    'heart_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spo2Meta = const VerificationMeta('spo2');
  @override
  late final GeneratedColumn<int> spo2 = GeneratedColumn<int>(
    'spo2',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ecgRhythmMeta = const VerificationMeta(
    'ecgRhythm',
  );
  @override
  late final GeneratedColumn<String> ecgRhythm = GeneratedColumn<String>(
    'ecg_rhythm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNKNOWN'),
  );
  static const VerificationMeta _ecgQualityScoreMeta = const VerificationMeta(
    'ecgQualityScore',
  );
  @override
  late final GeneratedColumn<double> ecgQualityScore = GeneratedColumn<double>(
    'ecg_quality_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _rrIntervalMsMeta = const VerificationMeta(
    'rrIntervalMs',
  );
  @override
  late final GeneratedColumn<int> rrIntervalMs = GeneratedColumn<int>(
    'rr_interval_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pttMsMeta = const VerificationMeta('pttMs');
  @override
  late final GeneratedColumn<int> pttMs = GeneratedColumn<int>(
    'ptt_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _estimatedSystolicMeta = const VerificationMeta(
    'estimatedSystolic',
  );
  @override
  late final GeneratedColumn<int> estimatedSystolic = GeneratedColumn<int>(
    'estimated_systolic',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _estimatedDiastolicMeta =
      const VerificationMeta('estimatedDiastolic');
  @override
  late final GeneratedColumn<int> estimatedDiastolic = GeneratedColumn<int>(
    'estimated_diastolic',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bpConfidenceMeta = const VerificationMeta(
    'bpConfidence',
  );
  @override
  late final GeneratedColumn<String> bpConfidence = GeneratedColumn<String>(
    'bp_confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EXPERIMENTAL'),
  );
  static const VerificationMeta _bpCalibratedAtMeta = const VerificationMeta(
    'bpCalibratedAt',
  );
  @override
  late final GeneratedColumn<DateTime> bpCalibratedAt =
      GeneratedColumn<DateTime>(
        'bp_calibrated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _symptomsMeta = const VerificationMeta(
    'symptoms',
  );
  @override
  late final GeneratedColumn<String> symptoms = GeneratedColumn<String>(
    'symptoms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _symptomDurationMeta = const VerificationMeta(
    'symptomDuration',
  );
  @override
  late final GeneratedColumn<String> symptomDuration = GeneratedColumn<String>(
    'symptom_duration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _symptomNotesMeta = const VerificationMeta(
    'symptomNotes',
  );
  @override
  late final GeneratedColumn<String> symptomNotes = GeneratedColumn<String>(
    'symptom_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _riskLevelMeta = const VerificationMeta(
    'riskLevel',
  );
  @override
  late final GeneratedColumn<String> riskLevel = GeneratedColumn<String>(
    'risk_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _riskScoreMeta = const VerificationMeta(
    'riskScore',
  );
  @override
  late final GeneratedColumn<int> riskScore = GeneratedColumn<int>(
    'risk_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggeredRulesMeta = const VerificationMeta(
    'triggeredRules',
  );
  @override
  late final GeneratedColumn<String> triggeredRules = GeneratedColumn<String>(
    'triggered_rules',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _recommendedActionMeta = const VerificationMeta(
    'recommendedAction',
  );
  @override
  late final GeneratedColumn<String> recommendedAction =
      GeneratedColumn<String>(
        'recommended_action',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _escalationLevelMeta = const VerificationMeta(
    'escalationLevel',
  );
  @override
  late final GeneratedColumn<String> escalationLevel = GeneratedColumn<String>(
    'escalation_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NONE'),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    patientId,
    deviceId,
    timestamp,
    heartRate,
    spo2,
    temperature,
    ecgRhythm,
    ecgQualityScore,
    rrIntervalMs,
    pttMs,
    estimatedSystolic,
    estimatedDiastolic,
    bpConfidence,
    bpCalibratedAt,
    symptoms,
    symptomDuration,
    symptomNotes,
    riskLevel,
    riskScore,
    triggeredRules,
    recommendedAction,
    escalationLevel,
    latitude,
    longitude,
    syncStatus,
    retryCount,
    isDemo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'screenings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScreeningRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(
        _patientIdMeta,
        patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('heart_rate')) {
      context.handle(
        _heartRateMeta,
        heartRate.isAcceptableOrUnknown(data['heart_rate']!, _heartRateMeta),
      );
    } else if (isInserting) {
      context.missing(_heartRateMeta);
    }
    if (data.containsKey('spo2')) {
      context.handle(
        _spo2Meta,
        spo2.isAcceptableOrUnknown(data['spo2']!, _spo2Meta),
      );
    } else if (isInserting) {
      context.missing(_spo2Meta);
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_temperatureMeta);
    }
    if (data.containsKey('ecg_rhythm')) {
      context.handle(
        _ecgRhythmMeta,
        ecgRhythm.isAcceptableOrUnknown(data['ecg_rhythm']!, _ecgRhythmMeta),
      );
    }
    if (data.containsKey('ecg_quality_score')) {
      context.handle(
        _ecgQualityScoreMeta,
        ecgQualityScore.isAcceptableOrUnknown(
          data['ecg_quality_score']!,
          _ecgQualityScoreMeta,
        ),
      );
    }
    if (data.containsKey('rr_interval_ms')) {
      context.handle(
        _rrIntervalMsMeta,
        rrIntervalMs.isAcceptableOrUnknown(
          data['rr_interval_ms']!,
          _rrIntervalMsMeta,
        ),
      );
    }
    if (data.containsKey('ptt_ms')) {
      context.handle(
        _pttMsMeta,
        pttMs.isAcceptableOrUnknown(data['ptt_ms']!, _pttMsMeta),
      );
    }
    if (data.containsKey('estimated_systolic')) {
      context.handle(
        _estimatedSystolicMeta,
        estimatedSystolic.isAcceptableOrUnknown(
          data['estimated_systolic']!,
          _estimatedSystolicMeta,
        ),
      );
    }
    if (data.containsKey('estimated_diastolic')) {
      context.handle(
        _estimatedDiastolicMeta,
        estimatedDiastolic.isAcceptableOrUnknown(
          data['estimated_diastolic']!,
          _estimatedDiastolicMeta,
        ),
      );
    }
    if (data.containsKey('bp_confidence')) {
      context.handle(
        _bpConfidenceMeta,
        bpConfidence.isAcceptableOrUnknown(
          data['bp_confidence']!,
          _bpConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('bp_calibrated_at')) {
      context.handle(
        _bpCalibratedAtMeta,
        bpCalibratedAt.isAcceptableOrUnknown(
          data['bp_calibrated_at']!,
          _bpCalibratedAtMeta,
        ),
      );
    }
    if (data.containsKey('symptoms')) {
      context.handle(
        _symptomsMeta,
        symptoms.isAcceptableOrUnknown(data['symptoms']!, _symptomsMeta),
      );
    }
    if (data.containsKey('symptom_duration')) {
      context.handle(
        _symptomDurationMeta,
        symptomDuration.isAcceptableOrUnknown(
          data['symptom_duration']!,
          _symptomDurationMeta,
        ),
      );
    }
    if (data.containsKey('symptom_notes')) {
      context.handle(
        _symptomNotesMeta,
        symptomNotes.isAcceptableOrUnknown(
          data['symptom_notes']!,
          _symptomNotesMeta,
        ),
      );
    }
    if (data.containsKey('risk_level')) {
      context.handle(
        _riskLevelMeta,
        riskLevel.isAcceptableOrUnknown(data['risk_level']!, _riskLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_riskLevelMeta);
    }
    if (data.containsKey('risk_score')) {
      context.handle(
        _riskScoreMeta,
        riskScore.isAcceptableOrUnknown(data['risk_score']!, _riskScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_riskScoreMeta);
    }
    if (data.containsKey('triggered_rules')) {
      context.handle(
        _triggeredRulesMeta,
        triggeredRules.isAcceptableOrUnknown(
          data['triggered_rules']!,
          _triggeredRulesMeta,
        ),
      );
    }
    if (data.containsKey('recommended_action')) {
      context.handle(
        _recommendedActionMeta,
        recommendedAction.isAcceptableOrUnknown(
          data['recommended_action']!,
          _recommendedActionMeta,
        ),
      );
    }
    if (data.containsKey('escalation_level')) {
      context.handle(
        _escalationLevelMeta,
        escalationLevel.isAcceptableOrUnknown(
          data['escalation_level']!,
          _escalationLevelMeta,
        ),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScreeningRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScreeningRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      patientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      heartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heart_rate'],
      )!,
      spo2: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spo2'],
      )!,
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      )!,
      ecgRhythm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ecg_rhythm'],
      )!,
      ecgQualityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ecg_quality_score'],
      )!,
      rrIntervalMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rr_interval_ms'],
      )!,
      pttMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ptt_ms'],
      )!,
      estimatedSystolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_systolic'],
      )!,
      estimatedDiastolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_diastolic'],
      )!,
      bpConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bp_confidence'],
      )!,
      bpCalibratedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}bp_calibrated_at'],
      ),
      symptoms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptoms'],
      )!,
      symptomDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptom_duration'],
      ),
      symptomNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptom_notes'],
      ),
      riskLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk_level'],
      )!,
      riskScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}risk_score'],
      )!,
      triggeredRules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triggered_rules'],
      )!,
      recommendedAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recommended_action'],
      )!,
      escalationLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}escalation_level'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
    );
  }

  @override
  $ScreeningsTable createAlias(String alias) {
    return $ScreeningsTable(attachedDatabase, alias);
  }
}

class ScreeningRow extends DataClass implements Insertable<ScreeningRow> {
  final String id;
  final String patientId;
  final String deviceId;
  final DateTime timestamp;
  final int heartRate;
  final int spo2;
  final double temperature;
  final String ecgRhythm;
  final double ecgQualityScore;
  final int rrIntervalMs;
  final int pttMs;
  final int estimatedSystolic;
  final int estimatedDiastolic;
  final String bpConfidence;
  final DateTime? bpCalibratedAt;
  final String symptoms;
  final String? symptomDuration;
  final String? symptomNotes;
  final String riskLevel;
  final int riskScore;
  final String triggeredRules;
  final String recommendedAction;
  final String escalationLevel;
  final double? latitude;
  final double? longitude;
  final String syncStatus;
  final int retryCount;
  final bool isDemo;
  const ScreeningRow({
    required this.id,
    required this.patientId,
    required this.deviceId,
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.ecgRhythm,
    required this.ecgQualityScore,
    required this.rrIntervalMs,
    required this.pttMs,
    required this.estimatedSystolic,
    required this.estimatedDiastolic,
    required this.bpConfidence,
    this.bpCalibratedAt,
    required this.symptoms,
    this.symptomDuration,
    this.symptomNotes,
    required this.riskLevel,
    required this.riskScore,
    required this.triggeredRules,
    required this.recommendedAction,
    required this.escalationLevel,
    this.latitude,
    this.longitude,
    required this.syncStatus,
    required this.retryCount,
    required this.isDemo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['patient_id'] = Variable<String>(patientId);
    map['device_id'] = Variable<String>(deviceId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['heart_rate'] = Variable<int>(heartRate);
    map['spo2'] = Variable<int>(spo2);
    map['temperature'] = Variable<double>(temperature);
    map['ecg_rhythm'] = Variable<String>(ecgRhythm);
    map['ecg_quality_score'] = Variable<double>(ecgQualityScore);
    map['rr_interval_ms'] = Variable<int>(rrIntervalMs);
    map['ptt_ms'] = Variable<int>(pttMs);
    map['estimated_systolic'] = Variable<int>(estimatedSystolic);
    map['estimated_diastolic'] = Variable<int>(estimatedDiastolic);
    map['bp_confidence'] = Variable<String>(bpConfidence);
    if (!nullToAbsent || bpCalibratedAt != null) {
      map['bp_calibrated_at'] = Variable<DateTime>(bpCalibratedAt);
    }
    map['symptoms'] = Variable<String>(symptoms);
    if (!nullToAbsent || symptomDuration != null) {
      map['symptom_duration'] = Variable<String>(symptomDuration);
    }
    if (!nullToAbsent || symptomNotes != null) {
      map['symptom_notes'] = Variable<String>(symptomNotes);
    }
    map['risk_level'] = Variable<String>(riskLevel);
    map['risk_score'] = Variable<int>(riskScore);
    map['triggered_rules'] = Variable<String>(triggeredRules);
    map['recommended_action'] = Variable<String>(recommendedAction);
    map['escalation_level'] = Variable<String>(escalationLevel);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    map['is_demo'] = Variable<bool>(isDemo);
    return map;
  }

  ScreeningsCompanion toCompanion(bool nullToAbsent) {
    return ScreeningsCompanion(
      id: Value(id),
      patientId: Value(patientId),
      deviceId: Value(deviceId),
      timestamp: Value(timestamp),
      heartRate: Value(heartRate),
      spo2: Value(spo2),
      temperature: Value(temperature),
      ecgRhythm: Value(ecgRhythm),
      ecgQualityScore: Value(ecgQualityScore),
      rrIntervalMs: Value(rrIntervalMs),
      pttMs: Value(pttMs),
      estimatedSystolic: Value(estimatedSystolic),
      estimatedDiastolic: Value(estimatedDiastolic),
      bpConfidence: Value(bpConfidence),
      bpCalibratedAt: bpCalibratedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(bpCalibratedAt),
      symptoms: Value(symptoms),
      symptomDuration: symptomDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(symptomDuration),
      symptomNotes: symptomNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(symptomNotes),
      riskLevel: Value(riskLevel),
      riskScore: Value(riskScore),
      triggeredRules: Value(triggeredRules),
      recommendedAction: Value(recommendedAction),
      escalationLevel: Value(escalationLevel),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      isDemo: Value(isDemo),
    );
  }

  factory ScreeningRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScreeningRow(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String>(json['patientId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      heartRate: serializer.fromJson<int>(json['heartRate']),
      spo2: serializer.fromJson<int>(json['spo2']),
      temperature: serializer.fromJson<double>(json['temperature']),
      ecgRhythm: serializer.fromJson<String>(json['ecgRhythm']),
      ecgQualityScore: serializer.fromJson<double>(json['ecgQualityScore']),
      rrIntervalMs: serializer.fromJson<int>(json['rrIntervalMs']),
      pttMs: serializer.fromJson<int>(json['pttMs']),
      estimatedSystolic: serializer.fromJson<int>(json['estimatedSystolic']),
      estimatedDiastolic: serializer.fromJson<int>(json['estimatedDiastolic']),
      bpConfidence: serializer.fromJson<String>(json['bpConfidence']),
      bpCalibratedAt: serializer.fromJson<DateTime?>(json['bpCalibratedAt']),
      symptoms: serializer.fromJson<String>(json['symptoms']),
      symptomDuration: serializer.fromJson<String?>(json['symptomDuration']),
      symptomNotes: serializer.fromJson<String?>(json['symptomNotes']),
      riskLevel: serializer.fromJson<String>(json['riskLevel']),
      riskScore: serializer.fromJson<int>(json['riskScore']),
      triggeredRules: serializer.fromJson<String>(json['triggeredRules']),
      recommendedAction: serializer.fromJson<String>(json['recommendedAction']),
      escalationLevel: serializer.fromJson<String>(json['escalationLevel']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String>(patientId),
      'deviceId': serializer.toJson<String>(deviceId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'heartRate': serializer.toJson<int>(heartRate),
      'spo2': serializer.toJson<int>(spo2),
      'temperature': serializer.toJson<double>(temperature),
      'ecgRhythm': serializer.toJson<String>(ecgRhythm),
      'ecgQualityScore': serializer.toJson<double>(ecgQualityScore),
      'rrIntervalMs': serializer.toJson<int>(rrIntervalMs),
      'pttMs': serializer.toJson<int>(pttMs),
      'estimatedSystolic': serializer.toJson<int>(estimatedSystolic),
      'estimatedDiastolic': serializer.toJson<int>(estimatedDiastolic),
      'bpConfidence': serializer.toJson<String>(bpConfidence),
      'bpCalibratedAt': serializer.toJson<DateTime?>(bpCalibratedAt),
      'symptoms': serializer.toJson<String>(symptoms),
      'symptomDuration': serializer.toJson<String?>(symptomDuration),
      'symptomNotes': serializer.toJson<String?>(symptomNotes),
      'riskLevel': serializer.toJson<String>(riskLevel),
      'riskScore': serializer.toJson<int>(riskScore),
      'triggeredRules': serializer.toJson<String>(triggeredRules),
      'recommendedAction': serializer.toJson<String>(recommendedAction),
      'escalationLevel': serializer.toJson<String>(escalationLevel),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'isDemo': serializer.toJson<bool>(isDemo),
    };
  }

  ScreeningRow copyWith({
    String? id,
    String? patientId,
    String? deviceId,
    DateTime? timestamp,
    int? heartRate,
    int? spo2,
    double? temperature,
    String? ecgRhythm,
    double? ecgQualityScore,
    int? rrIntervalMs,
    int? pttMs,
    int? estimatedSystolic,
    int? estimatedDiastolic,
    String? bpConfidence,
    Value<DateTime?> bpCalibratedAt = const Value.absent(),
    String? symptoms,
    Value<String?> symptomDuration = const Value.absent(),
    Value<String?> symptomNotes = const Value.absent(),
    String? riskLevel,
    int? riskScore,
    String? triggeredRules,
    String? recommendedAction,
    String? escalationLevel,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    String? syncStatus,
    int? retryCount,
    bool? isDemo,
  }) => ScreeningRow(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    deviceId: deviceId ?? this.deviceId,
    timestamp: timestamp ?? this.timestamp,
    heartRate: heartRate ?? this.heartRate,
    spo2: spo2 ?? this.spo2,
    temperature: temperature ?? this.temperature,
    ecgRhythm: ecgRhythm ?? this.ecgRhythm,
    ecgQualityScore: ecgQualityScore ?? this.ecgQualityScore,
    rrIntervalMs: rrIntervalMs ?? this.rrIntervalMs,
    pttMs: pttMs ?? this.pttMs,
    estimatedSystolic: estimatedSystolic ?? this.estimatedSystolic,
    estimatedDiastolic: estimatedDiastolic ?? this.estimatedDiastolic,
    bpConfidence: bpConfidence ?? this.bpConfidence,
    bpCalibratedAt: bpCalibratedAt.present
        ? bpCalibratedAt.value
        : this.bpCalibratedAt,
    symptoms: symptoms ?? this.symptoms,
    symptomDuration: symptomDuration.present
        ? symptomDuration.value
        : this.symptomDuration,
    symptomNotes: symptomNotes.present ? symptomNotes.value : this.symptomNotes,
    riskLevel: riskLevel ?? this.riskLevel,
    riskScore: riskScore ?? this.riskScore,
    triggeredRules: triggeredRules ?? this.triggeredRules,
    recommendedAction: recommendedAction ?? this.recommendedAction,
    escalationLevel: escalationLevel ?? this.escalationLevel,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    isDemo: isDemo ?? this.isDemo,
  );
  ScreeningRow copyWithCompanion(ScreeningsCompanion data) {
    return ScreeningRow(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      heartRate: data.heartRate.present ? data.heartRate.value : this.heartRate,
      spo2: data.spo2.present ? data.spo2.value : this.spo2,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      ecgRhythm: data.ecgRhythm.present ? data.ecgRhythm.value : this.ecgRhythm,
      ecgQualityScore: data.ecgQualityScore.present
          ? data.ecgQualityScore.value
          : this.ecgQualityScore,
      rrIntervalMs: data.rrIntervalMs.present
          ? data.rrIntervalMs.value
          : this.rrIntervalMs,
      pttMs: data.pttMs.present ? data.pttMs.value : this.pttMs,
      estimatedSystolic: data.estimatedSystolic.present
          ? data.estimatedSystolic.value
          : this.estimatedSystolic,
      estimatedDiastolic: data.estimatedDiastolic.present
          ? data.estimatedDiastolic.value
          : this.estimatedDiastolic,
      bpConfidence: data.bpConfidence.present
          ? data.bpConfidence.value
          : this.bpConfidence,
      bpCalibratedAt: data.bpCalibratedAt.present
          ? data.bpCalibratedAt.value
          : this.bpCalibratedAt,
      symptoms: data.symptoms.present ? data.symptoms.value : this.symptoms,
      symptomDuration: data.symptomDuration.present
          ? data.symptomDuration.value
          : this.symptomDuration,
      symptomNotes: data.symptomNotes.present
          ? data.symptomNotes.value
          : this.symptomNotes,
      riskLevel: data.riskLevel.present ? data.riskLevel.value : this.riskLevel,
      riskScore: data.riskScore.present ? data.riskScore.value : this.riskScore,
      triggeredRules: data.triggeredRules.present
          ? data.triggeredRules.value
          : this.triggeredRules,
      recommendedAction: data.recommendedAction.present
          ? data.recommendedAction.value
          : this.recommendedAction,
      escalationLevel: data.escalationLevel.present
          ? data.escalationLevel.value
          : this.escalationLevel,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScreeningRow(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('deviceId: $deviceId, ')
          ..write('timestamp: $timestamp, ')
          ..write('heartRate: $heartRate, ')
          ..write('spo2: $spo2, ')
          ..write('temperature: $temperature, ')
          ..write('ecgRhythm: $ecgRhythm, ')
          ..write('ecgQualityScore: $ecgQualityScore, ')
          ..write('rrIntervalMs: $rrIntervalMs, ')
          ..write('pttMs: $pttMs, ')
          ..write('estimatedSystolic: $estimatedSystolic, ')
          ..write('estimatedDiastolic: $estimatedDiastolic, ')
          ..write('bpConfidence: $bpConfidence, ')
          ..write('bpCalibratedAt: $bpCalibratedAt, ')
          ..write('symptoms: $symptoms, ')
          ..write('symptomDuration: $symptomDuration, ')
          ..write('symptomNotes: $symptomNotes, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('riskScore: $riskScore, ')
          ..write('triggeredRules: $triggeredRules, ')
          ..write('recommendedAction: $recommendedAction, ')
          ..write('escalationLevel: $escalationLevel, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('isDemo: $isDemo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    patientId,
    deviceId,
    timestamp,
    heartRate,
    spo2,
    temperature,
    ecgRhythm,
    ecgQualityScore,
    rrIntervalMs,
    pttMs,
    estimatedSystolic,
    estimatedDiastolic,
    bpConfidence,
    bpCalibratedAt,
    symptoms,
    symptomDuration,
    symptomNotes,
    riskLevel,
    riskScore,
    triggeredRules,
    recommendedAction,
    escalationLevel,
    latitude,
    longitude,
    syncStatus,
    retryCount,
    isDemo,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScreeningRow &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.deviceId == this.deviceId &&
          other.timestamp == this.timestamp &&
          other.heartRate == this.heartRate &&
          other.spo2 == this.spo2 &&
          other.temperature == this.temperature &&
          other.ecgRhythm == this.ecgRhythm &&
          other.ecgQualityScore == this.ecgQualityScore &&
          other.rrIntervalMs == this.rrIntervalMs &&
          other.pttMs == this.pttMs &&
          other.estimatedSystolic == this.estimatedSystolic &&
          other.estimatedDiastolic == this.estimatedDiastolic &&
          other.bpConfidence == this.bpConfidence &&
          other.bpCalibratedAt == this.bpCalibratedAt &&
          other.symptoms == this.symptoms &&
          other.symptomDuration == this.symptomDuration &&
          other.symptomNotes == this.symptomNotes &&
          other.riskLevel == this.riskLevel &&
          other.riskScore == this.riskScore &&
          other.triggeredRules == this.triggeredRules &&
          other.recommendedAction == this.recommendedAction &&
          other.escalationLevel == this.escalationLevel &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.isDemo == this.isDemo);
}

class ScreeningsCompanion extends UpdateCompanion<ScreeningRow> {
  final Value<String> id;
  final Value<String> patientId;
  final Value<String> deviceId;
  final Value<DateTime> timestamp;
  final Value<int> heartRate;
  final Value<int> spo2;
  final Value<double> temperature;
  final Value<String> ecgRhythm;
  final Value<double> ecgQualityScore;
  final Value<int> rrIntervalMs;
  final Value<int> pttMs;
  final Value<int> estimatedSystolic;
  final Value<int> estimatedDiastolic;
  final Value<String> bpConfidence;
  final Value<DateTime?> bpCalibratedAt;
  final Value<String> symptoms;
  final Value<String?> symptomDuration;
  final Value<String?> symptomNotes;
  final Value<String> riskLevel;
  final Value<int> riskScore;
  final Value<String> triggeredRules;
  final Value<String> recommendedAction;
  final Value<String> escalationLevel;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<bool> isDemo;
  final Value<int> rowid;
  const ScreeningsCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.temperature = const Value.absent(),
    this.ecgRhythm = const Value.absent(),
    this.ecgQualityScore = const Value.absent(),
    this.rrIntervalMs = const Value.absent(),
    this.pttMs = const Value.absent(),
    this.estimatedSystolic = const Value.absent(),
    this.estimatedDiastolic = const Value.absent(),
    this.bpConfidence = const Value.absent(),
    this.bpCalibratedAt = const Value.absent(),
    this.symptoms = const Value.absent(),
    this.symptomDuration = const Value.absent(),
    this.symptomNotes = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.riskScore = const Value.absent(),
    this.triggeredRules = const Value.absent(),
    this.recommendedAction = const Value.absent(),
    this.escalationLevel = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScreeningsCompanion.insert({
    required String id,
    required String patientId,
    this.deviceId = const Value.absent(),
    required DateTime timestamp,
    required int heartRate,
    required int spo2,
    required double temperature,
    this.ecgRhythm = const Value.absent(),
    this.ecgQualityScore = const Value.absent(),
    this.rrIntervalMs = const Value.absent(),
    this.pttMs = const Value.absent(),
    this.estimatedSystolic = const Value.absent(),
    this.estimatedDiastolic = const Value.absent(),
    this.bpConfidence = const Value.absent(),
    this.bpCalibratedAt = const Value.absent(),
    this.symptoms = const Value.absent(),
    this.symptomDuration = const Value.absent(),
    this.symptomNotes = const Value.absent(),
    required String riskLevel,
    required int riskScore,
    this.triggeredRules = const Value.absent(),
    this.recommendedAction = const Value.absent(),
    this.escalationLevel = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       patientId = Value(patientId),
       timestamp = Value(timestamp),
       heartRate = Value(heartRate),
       spo2 = Value(spo2),
       temperature = Value(temperature),
       riskLevel = Value(riskLevel),
       riskScore = Value(riskScore);
  static Insertable<ScreeningRow> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<String>? deviceId,
    Expression<DateTime>? timestamp,
    Expression<int>? heartRate,
    Expression<int>? spo2,
    Expression<double>? temperature,
    Expression<String>? ecgRhythm,
    Expression<double>? ecgQualityScore,
    Expression<int>? rrIntervalMs,
    Expression<int>? pttMs,
    Expression<int>? estimatedSystolic,
    Expression<int>? estimatedDiastolic,
    Expression<String>? bpConfidence,
    Expression<DateTime>? bpCalibratedAt,
    Expression<String>? symptoms,
    Expression<String>? symptomDuration,
    Expression<String>? symptomNotes,
    Expression<String>? riskLevel,
    Expression<int>? riskScore,
    Expression<String>? triggeredRules,
    Expression<String>? recommendedAction,
    Expression<String>? escalationLevel,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<bool>? isDemo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (deviceId != null) 'device_id': deviceId,
      if (timestamp != null) 'timestamp': timestamp,
      if (heartRate != null) 'heart_rate': heartRate,
      if (spo2 != null) 'spo2': spo2,
      if (temperature != null) 'temperature': temperature,
      if (ecgRhythm != null) 'ecg_rhythm': ecgRhythm,
      if (ecgQualityScore != null) 'ecg_quality_score': ecgQualityScore,
      if (rrIntervalMs != null) 'rr_interval_ms': rrIntervalMs,
      if (pttMs != null) 'ptt_ms': pttMs,
      if (estimatedSystolic != null) 'estimated_systolic': estimatedSystolic,
      if (estimatedDiastolic != null) 'estimated_diastolic': estimatedDiastolic,
      if (bpConfidence != null) 'bp_confidence': bpConfidence,
      if (bpCalibratedAt != null) 'bp_calibrated_at': bpCalibratedAt,
      if (symptoms != null) 'symptoms': symptoms,
      if (symptomDuration != null) 'symptom_duration': symptomDuration,
      if (symptomNotes != null) 'symptom_notes': symptomNotes,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (riskScore != null) 'risk_score': riskScore,
      if (triggeredRules != null) 'triggered_rules': triggeredRules,
      if (recommendedAction != null) 'recommended_action': recommendedAction,
      if (escalationLevel != null) 'escalation_level': escalationLevel,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (isDemo != null) 'is_demo': isDemo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScreeningsCompanion copyWith({
    Value<String>? id,
    Value<String>? patientId,
    Value<String>? deviceId,
    Value<DateTime>? timestamp,
    Value<int>? heartRate,
    Value<int>? spo2,
    Value<double>? temperature,
    Value<String>? ecgRhythm,
    Value<double>? ecgQualityScore,
    Value<int>? rrIntervalMs,
    Value<int>? pttMs,
    Value<int>? estimatedSystolic,
    Value<int>? estimatedDiastolic,
    Value<String>? bpConfidence,
    Value<DateTime?>? bpCalibratedAt,
    Value<String>? symptoms,
    Value<String?>? symptomDuration,
    Value<String?>? symptomNotes,
    Value<String>? riskLevel,
    Value<int>? riskScore,
    Value<String>? triggeredRules,
    Value<String>? recommendedAction,
    Value<String>? escalationLevel,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String>? syncStatus,
    Value<int>? retryCount,
    Value<bool>? isDemo,
    Value<int>? rowid,
  }) {
    return ScreeningsCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      temperature: temperature ?? this.temperature,
      ecgRhythm: ecgRhythm ?? this.ecgRhythm,
      ecgQualityScore: ecgQualityScore ?? this.ecgQualityScore,
      rrIntervalMs: rrIntervalMs ?? this.rrIntervalMs,
      pttMs: pttMs ?? this.pttMs,
      estimatedSystolic: estimatedSystolic ?? this.estimatedSystolic,
      estimatedDiastolic: estimatedDiastolic ?? this.estimatedDiastolic,
      bpConfidence: bpConfidence ?? this.bpConfidence,
      bpCalibratedAt: bpCalibratedAt ?? this.bpCalibratedAt,
      symptoms: symptoms ?? this.symptoms,
      symptomDuration: symptomDuration ?? this.symptomDuration,
      symptomNotes: symptomNotes ?? this.symptomNotes,
      riskLevel: riskLevel ?? this.riskLevel,
      riskScore: riskScore ?? this.riskScore,
      triggeredRules: triggeredRules ?? this.triggeredRules,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      isDemo: isDemo ?? this.isDemo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (heartRate.present) {
      map['heart_rate'] = Variable<int>(heartRate.value);
    }
    if (spo2.present) {
      map['spo2'] = Variable<int>(spo2.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (ecgRhythm.present) {
      map['ecg_rhythm'] = Variable<String>(ecgRhythm.value);
    }
    if (ecgQualityScore.present) {
      map['ecg_quality_score'] = Variable<double>(ecgQualityScore.value);
    }
    if (rrIntervalMs.present) {
      map['rr_interval_ms'] = Variable<int>(rrIntervalMs.value);
    }
    if (pttMs.present) {
      map['ptt_ms'] = Variable<int>(pttMs.value);
    }
    if (estimatedSystolic.present) {
      map['estimated_systolic'] = Variable<int>(estimatedSystolic.value);
    }
    if (estimatedDiastolic.present) {
      map['estimated_diastolic'] = Variable<int>(estimatedDiastolic.value);
    }
    if (bpConfidence.present) {
      map['bp_confidence'] = Variable<String>(bpConfidence.value);
    }
    if (bpCalibratedAt.present) {
      map['bp_calibrated_at'] = Variable<DateTime>(bpCalibratedAt.value);
    }
    if (symptoms.present) {
      map['symptoms'] = Variable<String>(symptoms.value);
    }
    if (symptomDuration.present) {
      map['symptom_duration'] = Variable<String>(symptomDuration.value);
    }
    if (symptomNotes.present) {
      map['symptom_notes'] = Variable<String>(symptomNotes.value);
    }
    if (riskLevel.present) {
      map['risk_level'] = Variable<String>(riskLevel.value);
    }
    if (riskScore.present) {
      map['risk_score'] = Variable<int>(riskScore.value);
    }
    if (triggeredRules.present) {
      map['triggered_rules'] = Variable<String>(triggeredRules.value);
    }
    if (recommendedAction.present) {
      map['recommended_action'] = Variable<String>(recommendedAction.value);
    }
    if (escalationLevel.present) {
      map['escalation_level'] = Variable<String>(escalationLevel.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScreeningsCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('deviceId: $deviceId, ')
          ..write('timestamp: $timestamp, ')
          ..write('heartRate: $heartRate, ')
          ..write('spo2: $spo2, ')
          ..write('temperature: $temperature, ')
          ..write('ecgRhythm: $ecgRhythm, ')
          ..write('ecgQualityScore: $ecgQualityScore, ')
          ..write('rrIntervalMs: $rrIntervalMs, ')
          ..write('pttMs: $pttMs, ')
          ..write('estimatedSystolic: $estimatedSystolic, ')
          ..write('estimatedDiastolic: $estimatedDiastolic, ')
          ..write('bpConfidence: $bpConfidence, ')
          ..write('bpCalibratedAt: $bpCalibratedAt, ')
          ..write('symptoms: $symptoms, ')
          ..write('symptomDuration: $symptomDuration, ')
          ..write('symptomNotes: $symptomNotes, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('riskScore: $riskScore, ')
          ..write('triggeredRules: $triggeredRules, ')
          ..write('recommendedAction: $recommendedAction, ')
          ..write('escalationLevel: $escalationLevel, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('isDemo: $isDemo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WaveformBlobsTable extends WaveformBlobs
    with TableInfo<$WaveformBlobsTable, WaveformBlobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaveformBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _screeningIdMeta = const VerificationMeta(
    'screeningId',
  );
  @override
  late final GeneratedColumn<String> screeningId = GeneratedColumn<String>(
    'screening_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDownsampledMeta = const VerificationMeta(
    'isDownsampled',
  );
  @override
  late final GeneratedColumn<bool> isDownsampled = GeneratedColumn<bool>(
    'is_downsampled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_downsampled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    screeningId,
    type,
    filePath,
    durationMs,
    sampleRate,
    sizeBytes,
    isDownsampled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'waveform_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaveformBlobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('screening_id')) {
      context.handle(
        _screeningIdMeta,
        screeningId.isAcceptableOrUnknown(
          data['screening_id']!,
          _screeningIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_screeningIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    } else if (isInserting) {
      context.missing(_sampleRateMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('is_downsampled')) {
      context.handle(
        _isDownsampledMeta,
        isDownsampled.isAcceptableOrUnknown(
          data['is_downsampled']!,
          _isDownsampledMeta,
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
  Set<GeneratedColumn> get $primaryKey => {screeningId, type};
  @override
  WaveformBlobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaveformBlobRow(
      screeningId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}screening_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      isDownsampled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_downsampled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WaveformBlobsTable createAlias(String alias) {
    return $WaveformBlobsTable(attachedDatabase, alias);
  }
}

class WaveformBlobRow extends DataClass implements Insertable<WaveformBlobRow> {
  final String screeningId;
  final String type;
  final String filePath;
  final int durationMs;
  final int sampleRate;
  final int sizeBytes;
  final bool isDownsampled;
  final DateTime createdAt;
  const WaveformBlobRow({
    required this.screeningId,
    required this.type,
    required this.filePath,
    required this.durationMs,
    required this.sampleRate,
    required this.sizeBytes,
    required this.isDownsampled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['screening_id'] = Variable<String>(screeningId);
    map['type'] = Variable<String>(type);
    map['file_path'] = Variable<String>(filePath);
    map['duration_ms'] = Variable<int>(durationMs);
    map['sample_rate'] = Variable<int>(sampleRate);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['is_downsampled'] = Variable<bool>(isDownsampled);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WaveformBlobsCompanion toCompanion(bool nullToAbsent) {
    return WaveformBlobsCompanion(
      screeningId: Value(screeningId),
      type: Value(type),
      filePath: Value(filePath),
      durationMs: Value(durationMs),
      sampleRate: Value(sampleRate),
      sizeBytes: Value(sizeBytes),
      isDownsampled: Value(isDownsampled),
      createdAt: Value(createdAt),
    );
  }

  factory WaveformBlobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaveformBlobRow(
      screeningId: serializer.fromJson<String>(json['screeningId']),
      type: serializer.fromJson<String>(json['type']),
      filePath: serializer.fromJson<String>(json['filePath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      sampleRate: serializer.fromJson<int>(json['sampleRate']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      isDownsampled: serializer.fromJson<bool>(json['isDownsampled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'screeningId': serializer.toJson<String>(screeningId),
      'type': serializer.toJson<String>(type),
      'filePath': serializer.toJson<String>(filePath),
      'durationMs': serializer.toJson<int>(durationMs),
      'sampleRate': serializer.toJson<int>(sampleRate),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'isDownsampled': serializer.toJson<bool>(isDownsampled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WaveformBlobRow copyWith({
    String? screeningId,
    String? type,
    String? filePath,
    int? durationMs,
    int? sampleRate,
    int? sizeBytes,
    bool? isDownsampled,
    DateTime? createdAt,
  }) => WaveformBlobRow(
    screeningId: screeningId ?? this.screeningId,
    type: type ?? this.type,
    filePath: filePath ?? this.filePath,
    durationMs: durationMs ?? this.durationMs,
    sampleRate: sampleRate ?? this.sampleRate,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    isDownsampled: isDownsampled ?? this.isDownsampled,
    createdAt: createdAt ?? this.createdAt,
  );
  WaveformBlobRow copyWithCompanion(WaveformBlobsCompanion data) {
    return WaveformBlobRow(
      screeningId: data.screeningId.present
          ? data.screeningId.value
          : this.screeningId,
      type: data.type.present ? data.type.value : this.type,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      isDownsampled: data.isDownsampled.present
          ? data.isDownsampled.value
          : this.isDownsampled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaveformBlobRow(')
          ..write('screeningId: $screeningId, ')
          ..write('type: $type, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownsampled: $isDownsampled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    screeningId,
    type,
    filePath,
    durationMs,
    sampleRate,
    sizeBytes,
    isDownsampled,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaveformBlobRow &&
          other.screeningId == this.screeningId &&
          other.type == this.type &&
          other.filePath == this.filePath &&
          other.durationMs == this.durationMs &&
          other.sampleRate == this.sampleRate &&
          other.sizeBytes == this.sizeBytes &&
          other.isDownsampled == this.isDownsampled &&
          other.createdAt == this.createdAt);
}

class WaveformBlobsCompanion extends UpdateCompanion<WaveformBlobRow> {
  final Value<String> screeningId;
  final Value<String> type;
  final Value<String> filePath;
  final Value<int> durationMs;
  final Value<int> sampleRate;
  final Value<int> sizeBytes;
  final Value<bool> isDownsampled;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WaveformBlobsCompanion({
    this.screeningId = const Value.absent(),
    this.type = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.isDownsampled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WaveformBlobsCompanion.insert({
    required String screeningId,
    required String type,
    required String filePath,
    required int durationMs,
    required int sampleRate,
    this.sizeBytes = const Value.absent(),
    this.isDownsampled = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : screeningId = Value(screeningId),
       type = Value(type),
       filePath = Value(filePath),
       durationMs = Value(durationMs),
       sampleRate = Value(sampleRate),
       createdAt = Value(createdAt);
  static Insertable<WaveformBlobRow> custom({
    Expression<String>? screeningId,
    Expression<String>? type,
    Expression<String>? filePath,
    Expression<int>? durationMs,
    Expression<int>? sampleRate,
    Expression<int>? sizeBytes,
    Expression<bool>? isDownsampled,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (screeningId != null) 'screening_id': screeningId,
      if (type != null) 'type': type,
      if (filePath != null) 'file_path': filePath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (isDownsampled != null) 'is_downsampled': isDownsampled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WaveformBlobsCompanion copyWith({
    Value<String>? screeningId,
    Value<String>? type,
    Value<String>? filePath,
    Value<int>? durationMs,
    Value<int>? sampleRate,
    Value<int>? sizeBytes,
    Value<bool>? isDownsampled,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WaveformBlobsCompanion(
      screeningId: screeningId ?? this.screeningId,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      sampleRate: sampleRate ?? this.sampleRate,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDownsampled: isDownsampled ?? this.isDownsampled,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (screeningId.present) {
      map['screening_id'] = Variable<String>(screeningId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (isDownsampled.present) {
      map['is_downsampled'] = Variable<bool>(isDownsampled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaveformBlobsCompanion(')
          ..write('screeningId: $screeningId, ')
          ..write('type: $type, ')
          ..write('filePath: $filePath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isDownsampled: $isDownsampled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, DeviceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _macAddressMeta = const VerificationMeta(
    'macAddress',
  );
  @override
  late final GeneratedColumn<String> macAddress = GeneratedColumn<String>(
    'mac_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _batteryPercentMeta = const VerificationMeta(
    'batteryPercent',
  );
  @override
  late final GeneratedColumn<int> batteryPercent = GeneratedColumn<int>(
    'battery_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isConnectedMeta = const VerificationMeta(
    'isConnected',
  );
  @override
  late final GeneratedColumn<bool> isConnected = GeneratedColumn<bool>(
    'is_connected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_connected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _firmwareVersionMeta = const VerificationMeta(
    'firmwareVersion',
  );
  @override
  late final GeneratedColumn<String> firmwareVersion = GeneratedColumn<String>(
    'firmware_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNKNOWN'),
  );
  static const VerificationMeta _calibrationDateMeta = const VerificationMeta(
    'calibrationDate',
  );
  @override
  late final GeneratedColumn<DateTime> calibrationDate =
      GeneratedColumn<DateTime>(
        'calibration_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _calibrationSystolicMeta =
      const VerificationMeta('calibrationSystolic');
  @override
  late final GeneratedColumn<int> calibrationSystolic = GeneratedColumn<int>(
    'calibration_systolic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calibrationDiastolicMeta =
      const VerificationMeta('calibrationDiastolic');
  @override
  late final GeneratedColumn<int> calibrationDiastolic = GeneratedColumn<int>(
    'calibration_diastolic',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    macAddress,
    batteryPercent,
    isConnected,
    lastConnectedAt,
    firmwareVersion,
    calibrationDate,
    calibrationSystolic,
    calibrationDiastolic,
    isDemo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mac_address')) {
      context.handle(
        _macAddressMeta,
        macAddress.isAcceptableOrUnknown(data['mac_address']!, _macAddressMeta),
      );
    }
    if (data.containsKey('battery_percent')) {
      context.handle(
        _batteryPercentMeta,
        batteryPercent.isAcceptableOrUnknown(
          data['battery_percent']!,
          _batteryPercentMeta,
        ),
      );
    }
    if (data.containsKey('is_connected')) {
      context.handle(
        _isConnectedMeta,
        isConnected.isAcceptableOrUnknown(
          data['is_connected']!,
          _isConnectedMeta,
        ),
      );
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    if (data.containsKey('firmware_version')) {
      context.handle(
        _firmwareVersionMeta,
        firmwareVersion.isAcceptableOrUnknown(
          data['firmware_version']!,
          _firmwareVersionMeta,
        ),
      );
    }
    if (data.containsKey('calibration_date')) {
      context.handle(
        _calibrationDateMeta,
        calibrationDate.isAcceptableOrUnknown(
          data['calibration_date']!,
          _calibrationDateMeta,
        ),
      );
    }
    if (data.containsKey('calibration_systolic')) {
      context.handle(
        _calibrationSystolicMeta,
        calibrationSystolic.isAcceptableOrUnknown(
          data['calibration_systolic']!,
          _calibrationSystolicMeta,
        ),
      );
    }
    if (data.containsKey('calibration_diastolic')) {
      context.handle(
        _calibrationDiastolicMeta,
        calibrationDiastolic.isAcceptableOrUnknown(
          data['calibration_diastolic']!,
          _calibrationDiastolicMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      macAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac_address'],
      )!,
      batteryPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_percent'],
      )!,
      isConnected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_connected'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      ),
      firmwareVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firmware_version'],
      )!,
      calibrationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calibration_date'],
      ),
      calibrationSystolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calibration_systolic'],
      ),
      calibrationDiastolic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calibration_diastolic'],
      ),
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class DeviceRow extends DataClass implements Insertable<DeviceRow> {
  final String id;
  final String name;
  final String macAddress;
  final int batteryPercent;
  final bool isConnected;
  final DateTime? lastConnectedAt;
  final String firmwareVersion;

  /// Last time cuffless BP was calibrated against a reference cuff.
  final DateTime? calibrationDate;
  final int? calibrationSystolic;
  final int? calibrationDiastolic;
  final bool isDemo;
  const DeviceRow({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.batteryPercent,
    required this.isConnected,
    this.lastConnectedAt,
    required this.firmwareVersion,
    this.calibrationDate,
    this.calibrationSystolic,
    this.calibrationDiastolic,
    required this.isDemo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['mac_address'] = Variable<String>(macAddress);
    map['battery_percent'] = Variable<int>(batteryPercent);
    map['is_connected'] = Variable<bool>(isConnected);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    }
    map['firmware_version'] = Variable<String>(firmwareVersion);
    if (!nullToAbsent || calibrationDate != null) {
      map['calibration_date'] = Variable<DateTime>(calibrationDate);
    }
    if (!nullToAbsent || calibrationSystolic != null) {
      map['calibration_systolic'] = Variable<int>(calibrationSystolic);
    }
    if (!nullToAbsent || calibrationDiastolic != null) {
      map['calibration_diastolic'] = Variable<int>(calibrationDiastolic);
    }
    map['is_demo'] = Variable<bool>(isDemo);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      name: Value(name),
      macAddress: Value(macAddress),
      batteryPercent: Value(batteryPercent),
      isConnected: Value(isConnected),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
      firmwareVersion: Value(firmwareVersion),
      calibrationDate: calibrationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(calibrationDate),
      calibrationSystolic: calibrationSystolic == null && nullToAbsent
          ? const Value.absent()
          : Value(calibrationSystolic),
      calibrationDiastolic: calibrationDiastolic == null && nullToAbsent
          ? const Value.absent()
          : Value(calibrationDiastolic),
      isDemo: Value(isDemo),
    );
  }

  factory DeviceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      macAddress: serializer.fromJson<String>(json['macAddress']),
      batteryPercent: serializer.fromJson<int>(json['batteryPercent']),
      isConnected: serializer.fromJson<bool>(json['isConnected']),
      lastConnectedAt: serializer.fromJson<DateTime?>(json['lastConnectedAt']),
      firmwareVersion: serializer.fromJson<String>(json['firmwareVersion']),
      calibrationDate: serializer.fromJson<DateTime?>(json['calibrationDate']),
      calibrationSystolic: serializer.fromJson<int?>(
        json['calibrationSystolic'],
      ),
      calibrationDiastolic: serializer.fromJson<int?>(
        json['calibrationDiastolic'],
      ),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'macAddress': serializer.toJson<String>(macAddress),
      'batteryPercent': serializer.toJson<int>(batteryPercent),
      'isConnected': serializer.toJson<bool>(isConnected),
      'lastConnectedAt': serializer.toJson<DateTime?>(lastConnectedAt),
      'firmwareVersion': serializer.toJson<String>(firmwareVersion),
      'calibrationDate': serializer.toJson<DateTime?>(calibrationDate),
      'calibrationSystolic': serializer.toJson<int?>(calibrationSystolic),
      'calibrationDiastolic': serializer.toJson<int?>(calibrationDiastolic),
      'isDemo': serializer.toJson<bool>(isDemo),
    };
  }

  DeviceRow copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? batteryPercent,
    bool? isConnected,
    Value<DateTime?> lastConnectedAt = const Value.absent(),
    String? firmwareVersion,
    Value<DateTime?> calibrationDate = const Value.absent(),
    Value<int?> calibrationSystolic = const Value.absent(),
    Value<int?> calibrationDiastolic = const Value.absent(),
    bool? isDemo,
  }) => DeviceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    macAddress: macAddress ?? this.macAddress,
    batteryPercent: batteryPercent ?? this.batteryPercent,
    isConnected: isConnected ?? this.isConnected,
    lastConnectedAt: lastConnectedAt.present
        ? lastConnectedAt.value
        : this.lastConnectedAt,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    calibrationDate: calibrationDate.present
        ? calibrationDate.value
        : this.calibrationDate,
    calibrationSystolic: calibrationSystolic.present
        ? calibrationSystolic.value
        : this.calibrationSystolic,
    calibrationDiastolic: calibrationDiastolic.present
        ? calibrationDiastolic.value
        : this.calibrationDiastolic,
    isDemo: isDemo ?? this.isDemo,
  );
  DeviceRow copyWithCompanion(DevicesCompanion data) {
    return DeviceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      macAddress: data.macAddress.present
          ? data.macAddress.value
          : this.macAddress,
      batteryPercent: data.batteryPercent.present
          ? data.batteryPercent.value
          : this.batteryPercent,
      isConnected: data.isConnected.present
          ? data.isConnected.value
          : this.isConnected,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
      firmwareVersion: data.firmwareVersion.present
          ? data.firmwareVersion.value
          : this.firmwareVersion,
      calibrationDate: data.calibrationDate.present
          ? data.calibrationDate.value
          : this.calibrationDate,
      calibrationSystolic: data.calibrationSystolic.present
          ? data.calibrationSystolic.value
          : this.calibrationSystolic,
      calibrationDiastolic: data.calibrationDiastolic.present
          ? data.calibrationDiastolic.value
          : this.calibrationDiastolic,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('macAddress: $macAddress, ')
          ..write('batteryPercent: $batteryPercent, ')
          ..write('isConnected: $isConnected, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('calibrationDate: $calibrationDate, ')
          ..write('calibrationSystolic: $calibrationSystolic, ')
          ..write('calibrationDiastolic: $calibrationDiastolic, ')
          ..write('isDemo: $isDemo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    macAddress,
    batteryPercent,
    isConnected,
    lastConnectedAt,
    firmwareVersion,
    calibrationDate,
    calibrationSystolic,
    calibrationDiastolic,
    isDemo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.macAddress == this.macAddress &&
          other.batteryPercent == this.batteryPercent &&
          other.isConnected == this.isConnected &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.firmwareVersion == this.firmwareVersion &&
          other.calibrationDate == this.calibrationDate &&
          other.calibrationSystolic == this.calibrationSystolic &&
          other.calibrationDiastolic == this.calibrationDiastolic &&
          other.isDemo == this.isDemo);
}

class DevicesCompanion extends UpdateCompanion<DeviceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> macAddress;
  final Value<int> batteryPercent;
  final Value<bool> isConnected;
  final Value<DateTime?> lastConnectedAt;
  final Value<String> firmwareVersion;
  final Value<DateTime?> calibrationDate;
  final Value<int?> calibrationSystolic;
  final Value<int?> calibrationDiastolic;
  final Value<bool> isDemo;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.batteryPercent = const Value.absent(),
    this.isConnected = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.calibrationDate = const Value.absent(),
    this.calibrationSystolic = const Value.absent(),
    this.calibrationDiastolic = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String name,
    this.macAddress = const Value.absent(),
    this.batteryPercent = const Value.absent(),
    this.isConnected = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.calibrationDate = const Value.absent(),
    this.calibrationSystolic = const Value.absent(),
    this.calibrationDiastolic = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DeviceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? macAddress,
    Expression<int>? batteryPercent,
    Expression<bool>? isConnected,
    Expression<DateTime>? lastConnectedAt,
    Expression<String>? firmwareVersion,
    Expression<DateTime>? calibrationDate,
    Expression<int>? calibrationSystolic,
    Expression<int>? calibrationDiastolic,
    Expression<bool>? isDemo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (macAddress != null) 'mac_address': macAddress,
      if (batteryPercent != null) 'battery_percent': batteryPercent,
      if (isConnected != null) 'is_connected': isConnected,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (calibrationDate != null) 'calibration_date': calibrationDate,
      if (calibrationSystolic != null)
        'calibration_systolic': calibrationSystolic,
      if (calibrationDiastolic != null)
        'calibration_diastolic': calibrationDiastolic,
      if (isDemo != null) 'is_demo': isDemo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? macAddress,
    Value<int>? batteryPercent,
    Value<bool>? isConnected,
    Value<DateTime?>? lastConnectedAt,
    Value<String>? firmwareVersion,
    Value<DateTime?>? calibrationDate,
    Value<int?>? calibrationSystolic,
    Value<int?>? calibrationDiastolic,
    Value<bool>? isDemo,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isConnected: isConnected ?? this.isConnected,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      calibrationDate: calibrationDate ?? this.calibrationDate,
      calibrationSystolic: calibrationSystolic ?? this.calibrationSystolic,
      calibrationDiastolic: calibrationDiastolic ?? this.calibrationDiastolic,
      isDemo: isDemo ?? this.isDemo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (macAddress.present) {
      map['mac_address'] = Variable<String>(macAddress.value);
    }
    if (batteryPercent.present) {
      map['battery_percent'] = Variable<int>(batteryPercent.value);
    }
    if (isConnected.present) {
      map['is_connected'] = Variable<bool>(isConnected.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (firmwareVersion.present) {
      map['firmware_version'] = Variable<String>(firmwareVersion.value);
    }
    if (calibrationDate.present) {
      map['calibration_date'] = Variable<DateTime>(calibrationDate.value);
    }
    if (calibrationSystolic.present) {
      map['calibration_systolic'] = Variable<int>(calibrationSystolic.value);
    }
    if (calibrationDiastolic.present) {
      map['calibration_diastolic'] = Variable<int>(calibrationDiastolic.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('macAddress: $macAddress, ')
          ..write('batteryPercent: $batteryPercent, ')
          ..write('isConnected: $isConnected, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('calibrationDate: $calibrationDate, ')
          ..write('calibrationSystolic: $calibrationSystolic, ')
          ..write('calibrationDiastolic: $calibrationDiastolic, ')
          ..write('isDemo: $isDemo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'table_name',
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
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    recordId,
    operation,
    queuedAt,
    attempts,
    lastError,
    status,
    lastAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['table_name']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueRow extends DataClass implements Insertable<SyncQueueRow> {
  final String id;

  /// `table_name` — the getter can't be called `tableName`, that's taken by
  /// drift's own `Table` API.
  final String entity;
  final String recordId;
  final String operation;
  final DateTime queuedAt;
  final int attempts;
  final String? lastError;
  final String status;
  final DateTime? lastAttemptAt;
  const SyncQueueRow({
    required this.id,
    required this.entity,
    required this.recordId,
    required this.operation,
    required this.queuedAt,
    required this.attempts,
    this.lastError,
    required this.status,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_name'] = Variable<String>(entity);
    map['record_id'] = Variable<String>(recordId);
    map['operation'] = Variable<String>(operation);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      entity: Value(entity),
      recordId: Value(recordId),
      operation: Value(operation),
      queuedAt: Value(queuedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory SyncQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueRow(
      id: serializer.fromJson<String>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      recordId: serializer.fromJson<String>(json['recordId']),
      operation: serializer.fromJson<String>(json['operation']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entity': serializer.toJson<String>(entity),
      'recordId': serializer.toJson<String>(recordId),
      'operation': serializer.toJson<String>(operation),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  SyncQueueRow copyWith({
    String? id,
    String? entity,
    String? recordId,
    String? operation,
    DateTime? queuedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    String? status,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => SyncQueueRow(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    recordId: recordId ?? this.recordId,
    operation: operation ?? this.operation,
    queuedAt: queuedAt ?? this.queuedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
  );
  SyncQueueRow copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueRow(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      operation: data.operation.present ? data.operation.value : this.operation,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueRow(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    recordId,
    operation,
    queuedAt,
    attempts,
    lastError,
    status,
    lastAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueRow &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.recordId == this.recordId &&
          other.operation == this.operation &&
          other.queuedAt == this.queuedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.status == this.status &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueRow> {
  final Value<String> id;
  final Value<String> entity;
  final Value<String> recordId;
  final Value<String> operation;
  final Value<DateTime> queuedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.recordId = const Value.absent(),
    this.operation = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String id,
    required String entity,
    required String recordId,
    required String operation,
    required DateTime queuedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entity = Value(entity),
       recordId = Value(recordId),
       operation = Value(operation),
       queuedAt = Value(queuedAt);
  static Insertable<SyncQueueRow> custom({
    Expression<String>? id,
    Expression<String>? entity,
    Expression<String>? recordId,
    Expression<String>? operation,
    Expression<DateTime>? queuedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'table_name': entity,
      if (recordId != null) 'record_id': recordId,
      if (operation != null) 'operation': operation,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? entity,
    Value<String>? recordId,
    Value<String>? operation,
    Value<DateTime>? queuedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String>? status,
    Value<DateTime?>? lastAttemptAt,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      recordId: recordId ?? this.recordId,
      operation: operation ?? this.operation,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entity.present) {
      map['table_name'] = Variable<String>(entity.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('operation: $operation, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuidelineCacheTable extends GuidelineCache
    with TableInfo<$GuidelineCacheTable, GuidelineChunkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuidelineCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chunkIdMeta = const VerificationMeta(
    'chunkId',
  );
  @override
  late final GeneratedColumn<String> chunkId = GeneratedColumn<String>(
    'chunk_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keywordsMeta = const VerificationMeta(
    'keywords',
  );
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
    'keywords',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ruleTagsMeta = const VerificationMeta(
    'ruleTags',
  );
  @override
  late final GeneratedColumn<String> ruleTags = GeneratedColumn<String>(
    'rule_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    chunkId,
    source,
    title,
    body,
    keywords,
    ruleTags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guideline_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuidelineChunkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chunk_id')) {
      context.handle(
        _chunkIdMeta,
        chunkId.isAcceptableOrUnknown(data['chunk_id']!, _chunkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('keywords')) {
      context.handle(
        _keywordsMeta,
        keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta),
      );
    }
    if (data.containsKey('rule_tags')) {
      context.handle(
        _ruleTagsMeta,
        ruleTags.isAcceptableOrUnknown(data['rule_tags']!, _ruleTagsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chunkId};
  @override
  GuidelineChunkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuidelineChunkRow(
      chunkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chunk_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      keywords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords'],
      )!,
      ruleTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_tags'],
      )!,
    );
  }

  @override
  $GuidelineCacheTable createAlias(String alias) {
    return $GuidelineCacheTable(attachedDatabase, alias);
  }
}

class GuidelineChunkRow extends DataClass
    implements Insertable<GuidelineChunkRow> {
  final String chunkId;
  final String source;
  final String title;

  /// Can't be named `text` — collides with drift's `Table.text()` builder.
  final String body;

  /// Space-separated normalised terms, precomputed at seed time so retrieval
  /// doesn't re-tokenise the whole corpus on every query.
  final String keywords;

  /// JSON array of rule ids this chunk explains, e.g. `["spo2_critical"]`.
  final String ruleTags;
  const GuidelineChunkRow({
    required this.chunkId,
    required this.source,
    required this.title,
    required this.body,
    required this.keywords,
    required this.ruleTags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chunk_id'] = Variable<String>(chunkId);
    map['source'] = Variable<String>(source);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['keywords'] = Variable<String>(keywords);
    map['rule_tags'] = Variable<String>(ruleTags);
    return map;
  }

  GuidelineCacheCompanion toCompanion(bool nullToAbsent) {
    return GuidelineCacheCompanion(
      chunkId: Value(chunkId),
      source: Value(source),
      title: Value(title),
      body: Value(body),
      keywords: Value(keywords),
      ruleTags: Value(ruleTags),
    );
  }

  factory GuidelineChunkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuidelineChunkRow(
      chunkId: serializer.fromJson<String>(json['chunkId']),
      source: serializer.fromJson<String>(json['source']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      keywords: serializer.fromJson<String>(json['keywords']),
      ruleTags: serializer.fromJson<String>(json['ruleTags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chunkId': serializer.toJson<String>(chunkId),
      'source': serializer.toJson<String>(source),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'keywords': serializer.toJson<String>(keywords),
      'ruleTags': serializer.toJson<String>(ruleTags),
    };
  }

  GuidelineChunkRow copyWith({
    String? chunkId,
    String? source,
    String? title,
    String? body,
    String? keywords,
    String? ruleTags,
  }) => GuidelineChunkRow(
    chunkId: chunkId ?? this.chunkId,
    source: source ?? this.source,
    title: title ?? this.title,
    body: body ?? this.body,
    keywords: keywords ?? this.keywords,
    ruleTags: ruleTags ?? this.ruleTags,
  );
  GuidelineChunkRow copyWithCompanion(GuidelineCacheCompanion data) {
    return GuidelineChunkRow(
      chunkId: data.chunkId.present ? data.chunkId.value : this.chunkId,
      source: data.source.present ? data.source.value : this.source,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      ruleTags: data.ruleTags.present ? data.ruleTags.value : this.ruleTags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuidelineChunkRow(')
          ..write('chunkId: $chunkId, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('keywords: $keywords, ')
          ..write('ruleTags: $ruleTags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(chunkId, source, title, body, keywords, ruleTags);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuidelineChunkRow &&
          other.chunkId == this.chunkId &&
          other.source == this.source &&
          other.title == this.title &&
          other.body == this.body &&
          other.keywords == this.keywords &&
          other.ruleTags == this.ruleTags);
}

class GuidelineCacheCompanion extends UpdateCompanion<GuidelineChunkRow> {
  final Value<String> chunkId;
  final Value<String> source;
  final Value<String> title;
  final Value<String> body;
  final Value<String> keywords;
  final Value<String> ruleTags;
  final Value<int> rowid;
  const GuidelineCacheCompanion({
    this.chunkId = const Value.absent(),
    this.source = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.keywords = const Value.absent(),
    this.ruleTags = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuidelineCacheCompanion.insert({
    required String chunkId,
    required String source,
    this.title = const Value.absent(),
    required String body,
    this.keywords = const Value.absent(),
    this.ruleTags = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chunkId = Value(chunkId),
       source = Value(source),
       body = Value(body);
  static Insertable<GuidelineChunkRow> custom({
    Expression<String>? chunkId,
    Expression<String>? source,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? keywords,
    Expression<String>? ruleTags,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chunkId != null) 'chunk_id': chunkId,
      if (source != null) 'source': source,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (keywords != null) 'keywords': keywords,
      if (ruleTags != null) 'rule_tags': ruleTags,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuidelineCacheCompanion copyWith({
    Value<String>? chunkId,
    Value<String>? source,
    Value<String>? title,
    Value<String>? body,
    Value<String>? keywords,
    Value<String>? ruleTags,
    Value<int>? rowid,
  }) {
    return GuidelineCacheCompanion(
      chunkId: chunkId ?? this.chunkId,
      source: source ?? this.source,
      title: title ?? this.title,
      body: body ?? this.body,
      keywords: keywords ?? this.keywords,
      ruleTags: ruleTags ?? this.ruleTags,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chunkId.present) {
      map['chunk_id'] = Variable<String>(chunkId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (ruleTags.present) {
      map['rule_tags'] = Variable<String>(ruleTags.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuidelineCacheCompanion(')
          ..write('chunkId: $chunkId, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('keywords: $keywords, ')
          ..write('ruleTags: $ruleTags, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExplanationsTable extends Explanations
    with TableInfo<$ExplanationsTable, ExplanationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExplanationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _screeningIdMeta = const VerificationMeta(
    'screeningId',
  );
  @override
  late final GeneratedColumn<String> screeningId = GeneratedColumn<String>(
    'screening_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _whyThisLevelMeta = const VerificationMeta(
    'whyThisLevel',
  );
  @override
  late final GeneratedColumn<String> whyThisLevel = GeneratedColumn<String>(
    'why_this_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _safeNextStepsMeta = const VerificationMeta(
    'safeNextSteps',
  );
  @override
  late final GeneratedColumn<String> safeNextSteps = GeneratedColumn<String>(
    'safe_next_steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _whenToEscalateMeta = const VerificationMeta(
    'whenToEscalate',
  );
  @override
  late final GeneratedColumn<String> whenToEscalate = GeneratedColumn<String>(
    'when_to_escalate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionsToAskMeta = const VerificationMeta(
    'questionsToAsk',
  );
  @override
  late final GeneratedColumn<String> questionsToAsk = GeneratedColumn<String>(
    'questions_to_ask',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _citationsMeta = const VerificationMeta(
    'citations',
  );
  @override
  late final GeneratedColumn<String> citations = GeneratedColumn<String>(
    'citations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _disclaimerMeta = const VerificationMeta(
    'disclaimer',
  );
  @override
  late final GeneratedColumn<String> disclaimer = GeneratedColumn<String>(
    'disclaimer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
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
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    screeningId,
    source,
    summary,
    whyThisLevel,
    safeNextSteps,
    whenToEscalate,
    questionsToAsk,
    citations,
    disclaimer,
    modelName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'explanations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExplanationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('screening_id')) {
      context.handle(
        _screeningIdMeta,
        screeningId.isAcceptableOrUnknown(
          data['screening_id']!,
          _screeningIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_screeningIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('why_this_level')) {
      context.handle(
        _whyThisLevelMeta,
        whyThisLevel.isAcceptableOrUnknown(
          data['why_this_level']!,
          _whyThisLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_whyThisLevelMeta);
    }
    if (data.containsKey('safe_next_steps')) {
      context.handle(
        _safeNextStepsMeta,
        safeNextSteps.isAcceptableOrUnknown(
          data['safe_next_steps']!,
          _safeNextStepsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_safeNextStepsMeta);
    }
    if (data.containsKey('when_to_escalate')) {
      context.handle(
        _whenToEscalateMeta,
        whenToEscalate.isAcceptableOrUnknown(
          data['when_to_escalate']!,
          _whenToEscalateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_whenToEscalateMeta);
    }
    if (data.containsKey('questions_to_ask')) {
      context.handle(
        _questionsToAskMeta,
        questionsToAsk.isAcceptableOrUnknown(
          data['questions_to_ask']!,
          _questionsToAskMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionsToAskMeta);
    }
    if (data.containsKey('citations')) {
      context.handle(
        _citationsMeta,
        citations.isAcceptableOrUnknown(data['citations']!, _citationsMeta),
      );
    }
    if (data.containsKey('disclaimer')) {
      context.handle(
        _disclaimerMeta,
        disclaimer.isAcceptableOrUnknown(data['disclaimer']!, _disclaimerMeta),
      );
    } else if (isInserting) {
      context.missing(_disclaimerMeta);
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
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
  Set<GeneratedColumn> get $primaryKey => {screeningId, source};
  @override
  ExplanationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExplanationRow(
      screeningId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}screening_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      whyThisLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}why_this_level'],
      )!,
      safeNextSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}safe_next_steps'],
      )!,
      whenToEscalate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}when_to_escalate'],
      )!,
      questionsToAsk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions_to_ask'],
      )!,
      citations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations'],
      )!,
      disclaimer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disclaimer'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExplanationsTable createAlias(String alias) {
    return $ExplanationsTable(attachedDatabase, alias);
  }
}

class ExplanationRow extends DataClass implements Insertable<ExplanationRow> {
  final String screeningId;
  final String source;
  final String summary;
  final String whyThisLevel;
  final String safeNextSteps;
  final String whenToEscalate;
  final String questionsToAsk;
  final String citations;
  final String disclaimer;
  final String modelName;
  final DateTime createdAt;
  const ExplanationRow({
    required this.screeningId,
    required this.source,
    required this.summary,
    required this.whyThisLevel,
    required this.safeNextSteps,
    required this.whenToEscalate,
    required this.questionsToAsk,
    required this.citations,
    required this.disclaimer,
    required this.modelName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['screening_id'] = Variable<String>(screeningId);
    map['source'] = Variable<String>(source);
    map['summary'] = Variable<String>(summary);
    map['why_this_level'] = Variable<String>(whyThisLevel);
    map['safe_next_steps'] = Variable<String>(safeNextSteps);
    map['when_to_escalate'] = Variable<String>(whenToEscalate);
    map['questions_to_ask'] = Variable<String>(questionsToAsk);
    map['citations'] = Variable<String>(citations);
    map['disclaimer'] = Variable<String>(disclaimer);
    map['model_name'] = Variable<String>(modelName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExplanationsCompanion toCompanion(bool nullToAbsent) {
    return ExplanationsCompanion(
      screeningId: Value(screeningId),
      source: Value(source),
      summary: Value(summary),
      whyThisLevel: Value(whyThisLevel),
      safeNextSteps: Value(safeNextSteps),
      whenToEscalate: Value(whenToEscalate),
      questionsToAsk: Value(questionsToAsk),
      citations: Value(citations),
      disclaimer: Value(disclaimer),
      modelName: Value(modelName),
      createdAt: Value(createdAt),
    );
  }

  factory ExplanationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExplanationRow(
      screeningId: serializer.fromJson<String>(json['screeningId']),
      source: serializer.fromJson<String>(json['source']),
      summary: serializer.fromJson<String>(json['summary']),
      whyThisLevel: serializer.fromJson<String>(json['whyThisLevel']),
      safeNextSteps: serializer.fromJson<String>(json['safeNextSteps']),
      whenToEscalate: serializer.fromJson<String>(json['whenToEscalate']),
      questionsToAsk: serializer.fromJson<String>(json['questionsToAsk']),
      citations: serializer.fromJson<String>(json['citations']),
      disclaimer: serializer.fromJson<String>(json['disclaimer']),
      modelName: serializer.fromJson<String>(json['modelName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'screeningId': serializer.toJson<String>(screeningId),
      'source': serializer.toJson<String>(source),
      'summary': serializer.toJson<String>(summary),
      'whyThisLevel': serializer.toJson<String>(whyThisLevel),
      'safeNextSteps': serializer.toJson<String>(safeNextSteps),
      'whenToEscalate': serializer.toJson<String>(whenToEscalate),
      'questionsToAsk': serializer.toJson<String>(questionsToAsk),
      'citations': serializer.toJson<String>(citations),
      'disclaimer': serializer.toJson<String>(disclaimer),
      'modelName': serializer.toJson<String>(modelName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExplanationRow copyWith({
    String? screeningId,
    String? source,
    String? summary,
    String? whyThisLevel,
    String? safeNextSteps,
    String? whenToEscalate,
    String? questionsToAsk,
    String? citations,
    String? disclaimer,
    String? modelName,
    DateTime? createdAt,
  }) => ExplanationRow(
    screeningId: screeningId ?? this.screeningId,
    source: source ?? this.source,
    summary: summary ?? this.summary,
    whyThisLevel: whyThisLevel ?? this.whyThisLevel,
    safeNextSteps: safeNextSteps ?? this.safeNextSteps,
    whenToEscalate: whenToEscalate ?? this.whenToEscalate,
    questionsToAsk: questionsToAsk ?? this.questionsToAsk,
    citations: citations ?? this.citations,
    disclaimer: disclaimer ?? this.disclaimer,
    modelName: modelName ?? this.modelName,
    createdAt: createdAt ?? this.createdAt,
  );
  ExplanationRow copyWithCompanion(ExplanationsCompanion data) {
    return ExplanationRow(
      screeningId: data.screeningId.present
          ? data.screeningId.value
          : this.screeningId,
      source: data.source.present ? data.source.value : this.source,
      summary: data.summary.present ? data.summary.value : this.summary,
      whyThisLevel: data.whyThisLevel.present
          ? data.whyThisLevel.value
          : this.whyThisLevel,
      safeNextSteps: data.safeNextSteps.present
          ? data.safeNextSteps.value
          : this.safeNextSteps,
      whenToEscalate: data.whenToEscalate.present
          ? data.whenToEscalate.value
          : this.whenToEscalate,
      questionsToAsk: data.questionsToAsk.present
          ? data.questionsToAsk.value
          : this.questionsToAsk,
      citations: data.citations.present ? data.citations.value : this.citations,
      disclaimer: data.disclaimer.present
          ? data.disclaimer.value
          : this.disclaimer,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExplanationRow(')
          ..write('screeningId: $screeningId, ')
          ..write('source: $source, ')
          ..write('summary: $summary, ')
          ..write('whyThisLevel: $whyThisLevel, ')
          ..write('safeNextSteps: $safeNextSteps, ')
          ..write('whenToEscalate: $whenToEscalate, ')
          ..write('questionsToAsk: $questionsToAsk, ')
          ..write('citations: $citations, ')
          ..write('disclaimer: $disclaimer, ')
          ..write('modelName: $modelName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    screeningId,
    source,
    summary,
    whyThisLevel,
    safeNextSteps,
    whenToEscalate,
    questionsToAsk,
    citations,
    disclaimer,
    modelName,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExplanationRow &&
          other.screeningId == this.screeningId &&
          other.source == this.source &&
          other.summary == this.summary &&
          other.whyThisLevel == this.whyThisLevel &&
          other.safeNextSteps == this.safeNextSteps &&
          other.whenToEscalate == this.whenToEscalate &&
          other.questionsToAsk == this.questionsToAsk &&
          other.citations == this.citations &&
          other.disclaimer == this.disclaimer &&
          other.modelName == this.modelName &&
          other.createdAt == this.createdAt);
}

class ExplanationsCompanion extends UpdateCompanion<ExplanationRow> {
  final Value<String> screeningId;
  final Value<String> source;
  final Value<String> summary;
  final Value<String> whyThisLevel;
  final Value<String> safeNextSteps;
  final Value<String> whenToEscalate;
  final Value<String> questionsToAsk;
  final Value<String> citations;
  final Value<String> disclaimer;
  final Value<String> modelName;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExplanationsCompanion({
    this.screeningId = const Value.absent(),
    this.source = const Value.absent(),
    this.summary = const Value.absent(),
    this.whyThisLevel = const Value.absent(),
    this.safeNextSteps = const Value.absent(),
    this.whenToEscalate = const Value.absent(),
    this.questionsToAsk = const Value.absent(),
    this.citations = const Value.absent(),
    this.disclaimer = const Value.absent(),
    this.modelName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExplanationsCompanion.insert({
    required String screeningId,
    required String source,
    required String summary,
    required String whyThisLevel,
    required String safeNextSteps,
    required String whenToEscalate,
    required String questionsToAsk,
    this.citations = const Value.absent(),
    required String disclaimer,
    this.modelName = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : screeningId = Value(screeningId),
       source = Value(source),
       summary = Value(summary),
       whyThisLevel = Value(whyThisLevel),
       safeNextSteps = Value(safeNextSteps),
       whenToEscalate = Value(whenToEscalate),
       questionsToAsk = Value(questionsToAsk),
       disclaimer = Value(disclaimer),
       createdAt = Value(createdAt);
  static Insertable<ExplanationRow> custom({
    Expression<String>? screeningId,
    Expression<String>? source,
    Expression<String>? summary,
    Expression<String>? whyThisLevel,
    Expression<String>? safeNextSteps,
    Expression<String>? whenToEscalate,
    Expression<String>? questionsToAsk,
    Expression<String>? citations,
    Expression<String>? disclaimer,
    Expression<String>? modelName,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (screeningId != null) 'screening_id': screeningId,
      if (source != null) 'source': source,
      if (summary != null) 'summary': summary,
      if (whyThisLevel != null) 'why_this_level': whyThisLevel,
      if (safeNextSteps != null) 'safe_next_steps': safeNextSteps,
      if (whenToEscalate != null) 'when_to_escalate': whenToEscalate,
      if (questionsToAsk != null) 'questions_to_ask': questionsToAsk,
      if (citations != null) 'citations': citations,
      if (disclaimer != null) 'disclaimer': disclaimer,
      if (modelName != null) 'model_name': modelName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExplanationsCompanion copyWith({
    Value<String>? screeningId,
    Value<String>? source,
    Value<String>? summary,
    Value<String>? whyThisLevel,
    Value<String>? safeNextSteps,
    Value<String>? whenToEscalate,
    Value<String>? questionsToAsk,
    Value<String>? citations,
    Value<String>? disclaimer,
    Value<String>? modelName,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExplanationsCompanion(
      screeningId: screeningId ?? this.screeningId,
      source: source ?? this.source,
      summary: summary ?? this.summary,
      whyThisLevel: whyThisLevel ?? this.whyThisLevel,
      safeNextSteps: safeNextSteps ?? this.safeNextSteps,
      whenToEscalate: whenToEscalate ?? this.whenToEscalate,
      questionsToAsk: questionsToAsk ?? this.questionsToAsk,
      citations: citations ?? this.citations,
      disclaimer: disclaimer ?? this.disclaimer,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (screeningId.present) {
      map['screening_id'] = Variable<String>(screeningId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (whyThisLevel.present) {
      map['why_this_level'] = Variable<String>(whyThisLevel.value);
    }
    if (safeNextSteps.present) {
      map['safe_next_steps'] = Variable<String>(safeNextSteps.value);
    }
    if (whenToEscalate.present) {
      map['when_to_escalate'] = Variable<String>(whenToEscalate.value);
    }
    if (questionsToAsk.present) {
      map['questions_to_ask'] = Variable<String>(questionsToAsk.value);
    }
    if (citations.present) {
      map['citations'] = Variable<String>(citations.value);
    }
    if (disclaimer.present) {
      map['disclaimer'] = Variable<String>(disclaimer.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExplanationsCompanion(')
          ..write('screeningId: $screeningId, ')
          ..write('source: $source, ')
          ..write('summary: $summary, ')
          ..write('whyThisLevel: $whyThisLevel, ')
          ..write('safeNextSteps: $safeNextSteps, ')
          ..write('whenToEscalate: $whenToEscalate, ')
          ..write('questionsToAsk: $questionsToAsk, ')
          ..write('citations: $citations, ')
          ..write('disclaimer: $disclaimer, ')
          ..write('modelName: $modelName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmergencyContactsTable extends EmergencyContacts
    with TableInfo<$EmergencyContactsTable, EmergencyContactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmergencyContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    relation,
    isPrimary,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'emergency_contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmergencyContactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmergencyContactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmergencyContactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $EmergencyContactsTable createAlias(String alias) {
    return $EmergencyContactsTable(attachedDatabase, alias);
  }
}

class EmergencyContactRow extends DataClass
    implements Insertable<EmergencyContactRow> {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;
  final int sortOrder;
  const EmergencyContactRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isPrimary,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['relation'] = Variable<String>(relation);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  EmergencyContactsCompanion toCompanion(bool nullToAbsent) {
    return EmergencyContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      relation: Value(relation),
      isPrimary: Value(isPrimary),
      sortOrder: Value(sortOrder),
    );
  }

  factory EmergencyContactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmergencyContactRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      relation: serializer.fromJson<String>(json['relation']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'relation': serializer.toJson<String>(relation),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  EmergencyContactRow copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    bool? isPrimary,
    int? sortOrder,
  }) => EmergencyContactRow(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    isPrimary: isPrimary ?? this.isPrimary,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  EmergencyContactRow copyWithCompanion(EmergencyContactsCompanion data) {
    return EmergencyContactRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      relation: data.relation.present ? data.relation.value : this.relation,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmergencyContactRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relation: $relation, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, phone, relation, isPrimary, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmergencyContactRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.relation == this.relation &&
          other.isPrimary == this.isPrimary &&
          other.sortOrder == this.sortOrder);
}

class EmergencyContactsCompanion extends UpdateCompanion<EmergencyContactRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> relation;
  final Value<bool> isPrimary;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const EmergencyContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.relation = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmergencyContactsCompanion.insert({
    required String id,
    required String name,
    required String phone,
    this.relation = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       phone = Value(phone);
  static Insertable<EmergencyContactRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? relation,
    Expression<bool>? isPrimary,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (relation != null) 'relation': relation,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmergencyContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? relation,
    Value<bool>? isPrimary,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return EmergencyContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      isPrimary: isPrimary ?? this.isPrimary,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmergencyContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relation: $relation, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SosEventsTable extends SosEvents
    with TableInfo<$SosEventsTable, SosEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SosEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientIdMeta = const VerificationMeta(
    'patientId',
  );
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
    'patient_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _screeningIdMeta = const VerificationMeta(
    'screeningId',
  );
  @override
  late final GeneratedColumn<String> screeningId = GeneratedColumn<String>(
    'screening_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerMeta = const VerificationMeta(
    'trigger',
  );
  @override
  late final GeneratedColumn<String> trigger = GeneratedColumn<String>(
    'trigger',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggeredAtMeta = const VerificationMeta(
    'triggeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> triggeredAt = GeneratedColumn<DateTime>(
    'triggered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactsNotifiedMeta = const VerificationMeta(
    'contactsNotified',
  );
  @override
  late final GeneratedColumn<String> contactsNotified = GeneratedColumn<String>(
    'contacts_notified',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('DISPATCHED'),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    patientId,
    screeningId,
    trigger,
    triggeredAt,
    contactsNotified,
    message,
    status,
    latitude,
    longitude,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sos_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SosEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(
        _patientIdMeta,
        patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta),
      );
    }
    if (data.containsKey('screening_id')) {
      context.handle(
        _screeningIdMeta,
        screeningId.isAcceptableOrUnknown(
          data['screening_id']!,
          _screeningIdMeta,
        ),
      );
    }
    if (data.containsKey('trigger')) {
      context.handle(
        _triggerMeta,
        trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta),
      );
    } else if (isInserting) {
      context.missing(_triggerMeta);
    }
    if (data.containsKey('triggered_at')) {
      context.handle(
        _triggeredAtMeta,
        triggeredAt.isAcceptableOrUnknown(
          data['triggered_at']!,
          _triggeredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggeredAtMeta);
    }
    if (data.containsKey('contacts_notified')) {
      context.handle(
        _contactsNotifiedMeta,
        contactsNotified.isAcceptableOrUnknown(
          data['contacts_notified']!,
          _contactsNotifiedMeta,
        ),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SosEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SosEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      patientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_id'],
      ),
      screeningId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}screening_id'],
      ),
      trigger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger'],
      )!,
      triggeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}triggered_at'],
      )!,
      contactsNotified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contacts_notified'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
    );
  }

  @override
  $SosEventsTable createAlias(String alias) {
    return $SosEventsTable(attachedDatabase, alias);
  }
}

class SosEventRow extends DataClass implements Insertable<SosEventRow> {
  final String id;
  final String? patientId;
  final String? screeningId;

  /// MANUAL | FALL_DETECTED | HIGH_RISK
  final String trigger;
  final DateTime triggeredAt;

  /// JSON array of `{name, phone}` actually dispatched to.
  final String contactsNotified;
  final String message;

  /// DISPATCHED | CANCELLED | FAILED
  final String status;
  final double? latitude;
  final double? longitude;
  const SosEventRow({
    required this.id,
    this.patientId,
    this.screeningId,
    required this.trigger,
    required this.triggeredAt,
    required this.contactsNotified,
    required this.message,
    required this.status,
    this.latitude,
    this.longitude,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || patientId != null) {
      map['patient_id'] = Variable<String>(patientId);
    }
    if (!nullToAbsent || screeningId != null) {
      map['screening_id'] = Variable<String>(screeningId);
    }
    map['trigger'] = Variable<String>(trigger);
    map['triggered_at'] = Variable<DateTime>(triggeredAt);
    map['contacts_notified'] = Variable<String>(contactsNotified);
    map['message'] = Variable<String>(message);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    return map;
  }

  SosEventsCompanion toCompanion(bool nullToAbsent) {
    return SosEventsCompanion(
      id: Value(id),
      patientId: patientId == null && nullToAbsent
          ? const Value.absent()
          : Value(patientId),
      screeningId: screeningId == null && nullToAbsent
          ? const Value.absent()
          : Value(screeningId),
      trigger: Value(trigger),
      triggeredAt: Value(triggeredAt),
      contactsNotified: Value(contactsNotified),
      message: Value(message),
      status: Value(status),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
    );
  }

  factory SosEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SosEventRow(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String?>(json['patientId']),
      screeningId: serializer.fromJson<String?>(json['screeningId']),
      trigger: serializer.fromJson<String>(json['trigger']),
      triggeredAt: serializer.fromJson<DateTime>(json['triggeredAt']),
      contactsNotified: serializer.fromJson<String>(json['contactsNotified']),
      message: serializer.fromJson<String>(json['message']),
      status: serializer.fromJson<String>(json['status']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String?>(patientId),
      'screeningId': serializer.toJson<String?>(screeningId),
      'trigger': serializer.toJson<String>(trigger),
      'triggeredAt': serializer.toJson<DateTime>(triggeredAt),
      'contactsNotified': serializer.toJson<String>(contactsNotified),
      'message': serializer.toJson<String>(message),
      'status': serializer.toJson<String>(status),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
    };
  }

  SosEventRow copyWith({
    String? id,
    Value<String?> patientId = const Value.absent(),
    Value<String?> screeningId = const Value.absent(),
    String? trigger,
    DateTime? triggeredAt,
    String? contactsNotified,
    String? message,
    String? status,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
  }) => SosEventRow(
    id: id ?? this.id,
    patientId: patientId.present ? patientId.value : this.patientId,
    screeningId: screeningId.present ? screeningId.value : this.screeningId,
    trigger: trigger ?? this.trigger,
    triggeredAt: triggeredAt ?? this.triggeredAt,
    contactsNotified: contactsNotified ?? this.contactsNotified,
    message: message ?? this.message,
    status: status ?? this.status,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
  );
  SosEventRow copyWithCompanion(SosEventsCompanion data) {
    return SosEventRow(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      screeningId: data.screeningId.present
          ? data.screeningId.value
          : this.screeningId,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      triggeredAt: data.triggeredAt.present
          ? data.triggeredAt.value
          : this.triggeredAt,
      contactsNotified: data.contactsNotified.present
          ? data.contactsNotified.value
          : this.contactsNotified,
      message: data.message.present ? data.message.value : this.message,
      status: data.status.present ? data.status.value : this.status,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SosEventRow(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('screeningId: $screeningId, ')
          ..write('trigger: $trigger, ')
          ..write('triggeredAt: $triggeredAt, ')
          ..write('contactsNotified: $contactsNotified, ')
          ..write('message: $message, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    patientId,
    screeningId,
    trigger,
    triggeredAt,
    contactsNotified,
    message,
    status,
    latitude,
    longitude,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SosEventRow &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.screeningId == this.screeningId &&
          other.trigger == this.trigger &&
          other.triggeredAt == this.triggeredAt &&
          other.contactsNotified == this.contactsNotified &&
          other.message == this.message &&
          other.status == this.status &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class SosEventsCompanion extends UpdateCompanion<SosEventRow> {
  final Value<String> id;
  final Value<String?> patientId;
  final Value<String?> screeningId;
  final Value<String> trigger;
  final Value<DateTime> triggeredAt;
  final Value<String> contactsNotified;
  final Value<String> message;
  final Value<String> status;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> rowid;
  const SosEventsCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.screeningId = const Value.absent(),
    this.trigger = const Value.absent(),
    this.triggeredAt = const Value.absent(),
    this.contactsNotified = const Value.absent(),
    this.message = const Value.absent(),
    this.status = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SosEventsCompanion.insert({
    required String id,
    this.patientId = const Value.absent(),
    this.screeningId = const Value.absent(),
    required String trigger,
    required DateTime triggeredAt,
    this.contactsNotified = const Value.absent(),
    this.message = const Value.absent(),
    this.status = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trigger = Value(trigger),
       triggeredAt = Value(triggeredAt);
  static Insertable<SosEventRow> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<String>? screeningId,
    Expression<String>? trigger,
    Expression<DateTime>? triggeredAt,
    Expression<String>? contactsNotified,
    Expression<String>? message,
    Expression<String>? status,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (screeningId != null) 'screening_id': screeningId,
      if (trigger != null) 'trigger': trigger,
      if (triggeredAt != null) 'triggered_at': triggeredAt,
      if (contactsNotified != null) 'contacts_notified': contactsNotified,
      if (message != null) 'message': message,
      if (status != null) 'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SosEventsCompanion copyWith({
    Value<String>? id,
    Value<String?>? patientId,
    Value<String?>? screeningId,
    Value<String>? trigger,
    Value<DateTime>? triggeredAt,
    Value<String>? contactsNotified,
    Value<String>? message,
    Value<String>? status,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int>? rowid,
  }) {
    return SosEventsCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      screeningId: screeningId ?? this.screeningId,
      trigger: trigger ?? this.trigger,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      message: message ?? this.message,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (screeningId.present) {
      map['screening_id'] = Variable<String>(screeningId.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
    }
    if (triggeredAt.present) {
      map['triggered_at'] = Variable<DateTime>(triggeredAt.value);
    }
    if (contactsNotified.present) {
      map['contacts_notified'] = Variable<String>(contactsNotified.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SosEventsCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('screeningId: $screeningId, ')
          ..write('trigger: $trigger, ')
          ..write('triggeredAt: $triggeredAt, ')
          ..write('contactsNotified: $contactsNotified, ')
          ..write('message: $message, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'app_settings';
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
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
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

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
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
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
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

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
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

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PatientsTable patients = $PatientsTable(this);
  late final $ScreeningsTable screenings = $ScreeningsTable(this);
  late final $WaveformBlobsTable waveformBlobs = $WaveformBlobsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $GuidelineCacheTable guidelineCache = $GuidelineCacheTable(this);
  late final $ExplanationsTable explanations = $ExplanationsTable(this);
  late final $EmergencyContactsTable emergencyContacts =
      $EmergencyContactsTable(this);
  late final $SosEventsTable sosEvents = $SosEventsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    patients,
    screenings,
    waveformBlobs,
    devices,
    syncQueue,
    guidelineCache,
    explanations,
    emergencyContacts,
    sosEvents,
    appSettings,
  ];
}

typedef $$PatientsTableCreateCompanionBuilder =
    PatientsCompanion Function({
      required String id,
      required String name,
      required int age,
      required String sex,
      Value<String?> location,
      Value<String?> phone,
      Value<String?> notes,
      required DateTime createdAt,
      Value<DateTime?> lastScreenedAt,
      Value<String> vulnerabilityFlags,
      Value<bool> isDemo,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$PatientsTableUpdateCompanionBuilder =
    PatientsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> age,
      Value<String> sex,
      Value<String?> location,
      Value<String?> phone,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime?> lastScreenedAt,
      Value<String> vulnerabilityFlags,
      Value<bool> isDemo,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$PatientsTableFilterComposer
    extends Composer<_$AppDatabase, $PatientsTable> {
  $$PatientsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScreenedAt => $composableBuilder(
    column: $table.lastScreenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vulnerabilityFlags => $composableBuilder(
    column: $table.vulnerabilityFlags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatientsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatientsTable> {
  $$PatientsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScreenedAt => $composableBuilder(
    column: $table.lastScreenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vulnerabilityFlags => $composableBuilder(
    column: $table.vulnerabilityFlags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatientsTable> {
  $$PatientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScreenedAt => $composableBuilder(
    column: $table.lastScreenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vulnerabilityFlags => $composableBuilder(
    column: $table.vulnerabilityFlags,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$PatientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatientsTable,
          PatientRow,
          $$PatientsTableFilterComposer,
          $$PatientsTableOrderingComposer,
          $$PatientsTableAnnotationComposer,
          $$PatientsTableCreateCompanionBuilder,
          $$PatientsTableUpdateCompanionBuilder,
          (
            PatientRow,
            BaseReferences<_$AppDatabase, $PatientsTable, PatientRow>,
          ),
          PatientRow,
          PrefetchHooks Function()
        > {
  $$PatientsTableTableManager(_$AppDatabase db, $PatientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> sex = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastScreenedAt = const Value.absent(),
                Value<String> vulnerabilityFlags = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatientsCompanion(
                id: id,
                name: name,
                age: age,
                sex: sex,
                location: location,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                lastScreenedAt: lastScreenedAt,
                vulnerabilityFlags: vulnerabilityFlags,
                isDemo: isDemo,
                syncStatus: syncStatus,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int age,
                required String sex,
                Value<String?> location = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastScreenedAt = const Value.absent(),
                Value<String> vulnerabilityFlags = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatientsCompanion.insert(
                id: id,
                name: name,
                age: age,
                sex: sex,
                location: location,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                lastScreenedAt: lastScreenedAt,
                vulnerabilityFlags: vulnerabilityFlags,
                isDemo: isDemo,
                syncStatus: syncStatus,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatientsTable,
      PatientRow,
      $$PatientsTableFilterComposer,
      $$PatientsTableOrderingComposer,
      $$PatientsTableAnnotationComposer,
      $$PatientsTableCreateCompanionBuilder,
      $$PatientsTableUpdateCompanionBuilder,
      (PatientRow, BaseReferences<_$AppDatabase, $PatientsTable, PatientRow>),
      PatientRow,
      PrefetchHooks Function()
    >;
typedef $$ScreeningsTableCreateCompanionBuilder =
    ScreeningsCompanion Function({
      required String id,
      required String patientId,
      Value<String> deviceId,
      required DateTime timestamp,
      required int heartRate,
      required int spo2,
      required double temperature,
      Value<String> ecgRhythm,
      Value<double> ecgQualityScore,
      Value<int> rrIntervalMs,
      Value<int> pttMs,
      Value<int> estimatedSystolic,
      Value<int> estimatedDiastolic,
      Value<String> bpConfidence,
      Value<DateTime?> bpCalibratedAt,
      Value<String> symptoms,
      Value<String?> symptomDuration,
      Value<String?> symptomNotes,
      required String riskLevel,
      required int riskScore,
      Value<String> triggeredRules,
      Value<String> recommendedAction,
      Value<String> escalationLevel,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<bool> isDemo,
      Value<int> rowid,
    });
typedef $$ScreeningsTableUpdateCompanionBuilder =
    ScreeningsCompanion Function({
      Value<String> id,
      Value<String> patientId,
      Value<String> deviceId,
      Value<DateTime> timestamp,
      Value<int> heartRate,
      Value<int> spo2,
      Value<double> temperature,
      Value<String> ecgRhythm,
      Value<double> ecgQualityScore,
      Value<int> rrIntervalMs,
      Value<int> pttMs,
      Value<int> estimatedSystolic,
      Value<int> estimatedDiastolic,
      Value<String> bpConfidence,
      Value<DateTime?> bpCalibratedAt,
      Value<String> symptoms,
      Value<String?> symptomDuration,
      Value<String?> symptomNotes,
      Value<String> riskLevel,
      Value<int> riskScore,
      Value<String> triggeredRules,
      Value<String> recommendedAction,
      Value<String> escalationLevel,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String> syncStatus,
      Value<int> retryCount,
      Value<bool> isDemo,
      Value<int> rowid,
    });

class $$ScreeningsTableFilterComposer
    extends Composer<_$AppDatabase, $ScreeningsTable> {
  $$ScreeningsTableFilterComposer({
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

  ColumnFilters<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heartRate => $composableBuilder(
    column: $table.heartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ecgRhythm => $composableBuilder(
    column: $table.ecgRhythm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ecgQualityScore => $composableBuilder(
    column: $table.ecgQualityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rrIntervalMs => $composableBuilder(
    column: $table.rrIntervalMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pttMs => $composableBuilder(
    column: $table.pttMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedSystolic => $composableBuilder(
    column: $table.estimatedSystolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedDiastolic => $composableBuilder(
    column: $table.estimatedDiastolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bpConfidence => $composableBuilder(
    column: $table.bpConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get bpCalibratedAt => $composableBuilder(
    column: $table.bpCalibratedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symptoms => $composableBuilder(
    column: $table.symptoms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symptomDuration => $composableBuilder(
    column: $table.symptomDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symptomNotes => $composableBuilder(
    column: $table.symptomNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get riskScore => $composableBuilder(
    column: $table.riskScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggeredRules => $composableBuilder(
    column: $table.triggeredRules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recommendedAction => $composableBuilder(
    column: $table.recommendedAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScreeningsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScreeningsTable> {
  $$ScreeningsTableOrderingComposer({
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

  ColumnOrderings<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heartRate => $composableBuilder(
    column: $table.heartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ecgRhythm => $composableBuilder(
    column: $table.ecgRhythm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ecgQualityScore => $composableBuilder(
    column: $table.ecgQualityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rrIntervalMs => $composableBuilder(
    column: $table.rrIntervalMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pttMs => $composableBuilder(
    column: $table.pttMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedSystolic => $composableBuilder(
    column: $table.estimatedSystolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedDiastolic => $composableBuilder(
    column: $table.estimatedDiastolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bpConfidence => $composableBuilder(
    column: $table.bpConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get bpCalibratedAt => $composableBuilder(
    column: $table.bpCalibratedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symptoms => $composableBuilder(
    column: $table.symptoms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symptomDuration => $composableBuilder(
    column: $table.symptomDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symptomNotes => $composableBuilder(
    column: $table.symptomNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get riskScore => $composableBuilder(
    column: $table.riskScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggeredRules => $composableBuilder(
    column: $table.triggeredRules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recommendedAction => $composableBuilder(
    column: $table.recommendedAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScreeningsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScreeningsTable> {
  $$ScreeningsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get heartRate =>
      $composableBuilder(column: $table.heartRate, builder: (column) => column);

  GeneratedColumn<int> get spo2 =>
      $composableBuilder(column: $table.spo2, builder: (column) => column);

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ecgRhythm =>
      $composableBuilder(column: $table.ecgRhythm, builder: (column) => column);

  GeneratedColumn<double> get ecgQualityScore => $composableBuilder(
    column: $table.ecgQualityScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rrIntervalMs => $composableBuilder(
    column: $table.rrIntervalMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pttMs =>
      $composableBuilder(column: $table.pttMs, builder: (column) => column);

  GeneratedColumn<int> get estimatedSystolic => $composableBuilder(
    column: $table.estimatedSystolic,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedDiastolic => $composableBuilder(
    column: $table.estimatedDiastolic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bpConfidence => $composableBuilder(
    column: $table.bpConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get bpCalibratedAt => $composableBuilder(
    column: $table.bpCalibratedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symptoms =>
      $composableBuilder(column: $table.symptoms, builder: (column) => column);

  GeneratedColumn<String> get symptomDuration => $composableBuilder(
    column: $table.symptomDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symptomNotes => $composableBuilder(
    column: $table.symptomNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get riskLevel =>
      $composableBuilder(column: $table.riskLevel, builder: (column) => column);

  GeneratedColumn<int> get riskScore =>
      $composableBuilder(column: $table.riskScore, builder: (column) => column);

  GeneratedColumn<String> get triggeredRules => $composableBuilder(
    column: $table.triggeredRules,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recommendedAction => $composableBuilder(
    column: $table.recommendedAction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);
}

class $$ScreeningsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScreeningsTable,
          ScreeningRow,
          $$ScreeningsTableFilterComposer,
          $$ScreeningsTableOrderingComposer,
          $$ScreeningsTableAnnotationComposer,
          $$ScreeningsTableCreateCompanionBuilder,
          $$ScreeningsTableUpdateCompanionBuilder,
          (
            ScreeningRow,
            BaseReferences<_$AppDatabase, $ScreeningsTable, ScreeningRow>,
          ),
          ScreeningRow,
          PrefetchHooks Function()
        > {
  $$ScreeningsTableTableManager(_$AppDatabase db, $ScreeningsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScreeningsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScreeningsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScreeningsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> patientId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> heartRate = const Value.absent(),
                Value<int> spo2 = const Value.absent(),
                Value<double> temperature = const Value.absent(),
                Value<String> ecgRhythm = const Value.absent(),
                Value<double> ecgQualityScore = const Value.absent(),
                Value<int> rrIntervalMs = const Value.absent(),
                Value<int> pttMs = const Value.absent(),
                Value<int> estimatedSystolic = const Value.absent(),
                Value<int> estimatedDiastolic = const Value.absent(),
                Value<String> bpConfidence = const Value.absent(),
                Value<DateTime?> bpCalibratedAt = const Value.absent(),
                Value<String> symptoms = const Value.absent(),
                Value<String?> symptomDuration = const Value.absent(),
                Value<String?> symptomNotes = const Value.absent(),
                Value<String> riskLevel = const Value.absent(),
                Value<int> riskScore = const Value.absent(),
                Value<String> triggeredRules = const Value.absent(),
                Value<String> recommendedAction = const Value.absent(),
                Value<String> escalationLevel = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScreeningsCompanion(
                id: id,
                patientId: patientId,
                deviceId: deviceId,
                timestamp: timestamp,
                heartRate: heartRate,
                spo2: spo2,
                temperature: temperature,
                ecgRhythm: ecgRhythm,
                ecgQualityScore: ecgQualityScore,
                rrIntervalMs: rrIntervalMs,
                pttMs: pttMs,
                estimatedSystolic: estimatedSystolic,
                estimatedDiastolic: estimatedDiastolic,
                bpConfidence: bpConfidence,
                bpCalibratedAt: bpCalibratedAt,
                symptoms: symptoms,
                symptomDuration: symptomDuration,
                symptomNotes: symptomNotes,
                riskLevel: riskLevel,
                riskScore: riskScore,
                triggeredRules: triggeredRules,
                recommendedAction: recommendedAction,
                escalationLevel: escalationLevel,
                latitude: latitude,
                longitude: longitude,
                syncStatus: syncStatus,
                retryCount: retryCount,
                isDemo: isDemo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String patientId,
                Value<String> deviceId = const Value.absent(),
                required DateTime timestamp,
                required int heartRate,
                required int spo2,
                required double temperature,
                Value<String> ecgRhythm = const Value.absent(),
                Value<double> ecgQualityScore = const Value.absent(),
                Value<int> rrIntervalMs = const Value.absent(),
                Value<int> pttMs = const Value.absent(),
                Value<int> estimatedSystolic = const Value.absent(),
                Value<int> estimatedDiastolic = const Value.absent(),
                Value<String> bpConfidence = const Value.absent(),
                Value<DateTime?> bpCalibratedAt = const Value.absent(),
                Value<String> symptoms = const Value.absent(),
                Value<String?> symptomDuration = const Value.absent(),
                Value<String?> symptomNotes = const Value.absent(),
                required String riskLevel,
                required int riskScore,
                Value<String> triggeredRules = const Value.absent(),
                Value<String> recommendedAction = const Value.absent(),
                Value<String> escalationLevel = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScreeningsCompanion.insert(
                id: id,
                patientId: patientId,
                deviceId: deviceId,
                timestamp: timestamp,
                heartRate: heartRate,
                spo2: spo2,
                temperature: temperature,
                ecgRhythm: ecgRhythm,
                ecgQualityScore: ecgQualityScore,
                rrIntervalMs: rrIntervalMs,
                pttMs: pttMs,
                estimatedSystolic: estimatedSystolic,
                estimatedDiastolic: estimatedDiastolic,
                bpConfidence: bpConfidence,
                bpCalibratedAt: bpCalibratedAt,
                symptoms: symptoms,
                symptomDuration: symptomDuration,
                symptomNotes: symptomNotes,
                riskLevel: riskLevel,
                riskScore: riskScore,
                triggeredRules: triggeredRules,
                recommendedAction: recommendedAction,
                escalationLevel: escalationLevel,
                latitude: latitude,
                longitude: longitude,
                syncStatus: syncStatus,
                retryCount: retryCount,
                isDemo: isDemo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScreeningsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScreeningsTable,
      ScreeningRow,
      $$ScreeningsTableFilterComposer,
      $$ScreeningsTableOrderingComposer,
      $$ScreeningsTableAnnotationComposer,
      $$ScreeningsTableCreateCompanionBuilder,
      $$ScreeningsTableUpdateCompanionBuilder,
      (
        ScreeningRow,
        BaseReferences<_$AppDatabase, $ScreeningsTable, ScreeningRow>,
      ),
      ScreeningRow,
      PrefetchHooks Function()
    >;
typedef $$WaveformBlobsTableCreateCompanionBuilder =
    WaveformBlobsCompanion Function({
      required String screeningId,
      required String type,
      required String filePath,
      required int durationMs,
      required int sampleRate,
      Value<int> sizeBytes,
      Value<bool> isDownsampled,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WaveformBlobsTableUpdateCompanionBuilder =
    WaveformBlobsCompanion Function({
      Value<String> screeningId,
      Value<String> type,
      Value<String> filePath,
      Value<int> durationMs,
      Value<int> sampleRate,
      Value<int> sizeBytes,
      Value<bool> isDownsampled,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WaveformBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $WaveformBlobsTable> {
  $$WaveformBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDownsampled => $composableBuilder(
    column: $table.isDownsampled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WaveformBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $WaveformBlobsTable> {
  $$WaveformBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDownsampled => $composableBuilder(
    column: $table.isDownsampled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaveformBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaveformBlobsTable> {
  $$WaveformBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get isDownsampled => $composableBuilder(
    column: $table.isDownsampled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WaveformBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaveformBlobsTable,
          WaveformBlobRow,
          $$WaveformBlobsTableFilterComposer,
          $$WaveformBlobsTableOrderingComposer,
          $$WaveformBlobsTableAnnotationComposer,
          $$WaveformBlobsTableCreateCompanionBuilder,
          $$WaveformBlobsTableUpdateCompanionBuilder,
          (
            WaveformBlobRow,
            BaseReferences<_$AppDatabase, $WaveformBlobsTable, WaveformBlobRow>,
          ),
          WaveformBlobRow,
          PrefetchHooks Function()
        > {
  $$WaveformBlobsTableTableManager(_$AppDatabase db, $WaveformBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaveformBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaveformBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaveformBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> screeningId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> sampleRate = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<bool> isDownsampled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WaveformBlobsCompanion(
                screeningId: screeningId,
                type: type,
                filePath: filePath,
                durationMs: durationMs,
                sampleRate: sampleRate,
                sizeBytes: sizeBytes,
                isDownsampled: isDownsampled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String screeningId,
                required String type,
                required String filePath,
                required int durationMs,
                required int sampleRate,
                Value<int> sizeBytes = const Value.absent(),
                Value<bool> isDownsampled = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WaveformBlobsCompanion.insert(
                screeningId: screeningId,
                type: type,
                filePath: filePath,
                durationMs: durationMs,
                sampleRate: sampleRate,
                sizeBytes: sizeBytes,
                isDownsampled: isDownsampled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WaveformBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaveformBlobsTable,
      WaveformBlobRow,
      $$WaveformBlobsTableFilterComposer,
      $$WaveformBlobsTableOrderingComposer,
      $$WaveformBlobsTableAnnotationComposer,
      $$WaveformBlobsTableCreateCompanionBuilder,
      $$WaveformBlobsTableUpdateCompanionBuilder,
      (
        WaveformBlobRow,
        BaseReferences<_$AppDatabase, $WaveformBlobsTable, WaveformBlobRow>,
      ),
      WaveformBlobRow,
      PrefetchHooks Function()
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      required String name,
      Value<String> macAddress,
      Value<int> batteryPercent,
      Value<bool> isConnected,
      Value<DateTime?> lastConnectedAt,
      Value<String> firmwareVersion,
      Value<DateTime?> calibrationDate,
      Value<int?> calibrationSystolic,
      Value<int?> calibrationDiastolic,
      Value<bool> isDemo,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> macAddress,
      Value<int> batteryPercent,
      Value<bool> isConnected,
      Value<DateTime?> lastConnectedAt,
      Value<String> firmwareVersion,
      Value<DateTime?> calibrationDate,
      Value<int?> calibrationSystolic,
      Value<int?> calibrationDiastolic,
      Value<bool> isDemo,
      Value<int> rowid,
    });

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batteryPercent => $composableBuilder(
    column: $table.batteryPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get calibrationDate => $composableBuilder(
    column: $table.calibrationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calibrationSystolic => $composableBuilder(
    column: $table.calibrationSystolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calibrationDiastolic => $composableBuilder(
    column: $table.calibrationDiastolic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batteryPercent => $composableBuilder(
    column: $table.batteryPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calibrationDate => $composableBuilder(
    column: $table.calibrationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calibrationSystolic => $composableBuilder(
    column: $table.calibrationSystolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calibrationDiastolic => $composableBuilder(
    column: $table.calibrationDiastolic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get batteryPercent => $composableBuilder(
    column: $table.batteryPercent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get calibrationDate => $composableBuilder(
    column: $table.calibrationDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calibrationSystolic => $composableBuilder(
    column: $table.calibrationSystolic,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calibrationDiastolic => $composableBuilder(
    column: $table.calibrationDiastolic,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          DeviceRow,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (DeviceRow, BaseReferences<_$AppDatabase, $DevicesTable, DeviceRow>),
          DeviceRow,
          PrefetchHooks Function()
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> macAddress = const Value.absent(),
                Value<int> batteryPercent = const Value.absent(),
                Value<bool> isConnected = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String> firmwareVersion = const Value.absent(),
                Value<DateTime?> calibrationDate = const Value.absent(),
                Value<int?> calibrationSystolic = const Value.absent(),
                Value<int?> calibrationDiastolic = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                name: name,
                macAddress: macAddress,
                batteryPercent: batteryPercent,
                isConnected: isConnected,
                lastConnectedAt: lastConnectedAt,
                firmwareVersion: firmwareVersion,
                calibrationDate: calibrationDate,
                calibrationSystolic: calibrationSystolic,
                calibrationDiastolic: calibrationDiastolic,
                isDemo: isDemo,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> macAddress = const Value.absent(),
                Value<int> batteryPercent = const Value.absent(),
                Value<bool> isConnected = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String> firmwareVersion = const Value.absent(),
                Value<DateTime?> calibrationDate = const Value.absent(),
                Value<int?> calibrationSystolic = const Value.absent(),
                Value<int?> calibrationDiastolic = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                name: name,
                macAddress: macAddress,
                batteryPercent: batteryPercent,
                isConnected: isConnected,
                lastConnectedAt: lastConnectedAt,
                firmwareVersion: firmwareVersion,
                calibrationDate: calibrationDate,
                calibrationSystolic: calibrationSystolic,
                calibrationDiastolic: calibrationDiastolic,
                isDemo: isDemo,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      DeviceRow,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (DeviceRow, BaseReferences<_$AppDatabase, $DevicesTable, DeviceRow>),
      DeviceRow,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String id,
      required String entity,
      required String recordId,
      required String operation,
      required DateTime queuedAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<String> status,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> id,
      Value<String> entity,
      Value<String> recordId,
      Value<String> operation,
      Value<DateTime> queuedAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<String> status,
      Value<DateTime?> lastAttemptAt,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueRow,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueRow,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
          ),
          SyncQueueRow,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                entity: entity,
                recordId: recordId,
                operation: operation,
                queuedAt: queuedAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entity,
                required String recordId,
                required String operation,
                required DateTime queuedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                entity: entity,
                recordId: recordId,
                operation: operation,
                queuedAt: queuedAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                lastAttemptAt: lastAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueRow,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueRow,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueRow>,
      ),
      SyncQueueRow,
      PrefetchHooks Function()
    >;
typedef $$GuidelineCacheTableCreateCompanionBuilder =
    GuidelineCacheCompanion Function({
      required String chunkId,
      required String source,
      Value<String> title,
      required String body,
      Value<String> keywords,
      Value<String> ruleTags,
      Value<int> rowid,
    });
typedef $$GuidelineCacheTableUpdateCompanionBuilder =
    GuidelineCacheCompanion Function({
      Value<String> chunkId,
      Value<String> source,
      Value<String> title,
      Value<String> body,
      Value<String> keywords,
      Value<String> ruleTags,
      Value<int> rowid,
    });

class $$GuidelineCacheTableFilterComposer
    extends Composer<_$AppDatabase, $GuidelineCacheTable> {
  $$GuidelineCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chunkId => $composableBuilder(
    column: $table.chunkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleTags => $composableBuilder(
    column: $table.ruleTags,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuidelineCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $GuidelineCacheTable> {
  $$GuidelineCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chunkId => $composableBuilder(
    column: $table.chunkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleTags => $composableBuilder(
    column: $table.ruleTags,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuidelineCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $GuidelineCacheTable> {
  $$GuidelineCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chunkId =>
      $composableBuilder(column: $table.chunkId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<String> get ruleTags =>
      $composableBuilder(column: $table.ruleTags, builder: (column) => column);
}

class $$GuidelineCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GuidelineCacheTable,
          GuidelineChunkRow,
          $$GuidelineCacheTableFilterComposer,
          $$GuidelineCacheTableOrderingComposer,
          $$GuidelineCacheTableAnnotationComposer,
          $$GuidelineCacheTableCreateCompanionBuilder,
          $$GuidelineCacheTableUpdateCompanionBuilder,
          (
            GuidelineChunkRow,
            BaseReferences<
              _$AppDatabase,
              $GuidelineCacheTable,
              GuidelineChunkRow
            >,
          ),
          GuidelineChunkRow,
          PrefetchHooks Function()
        > {
  $$GuidelineCacheTableTableManager(
    _$AppDatabase db,
    $GuidelineCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuidelineCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuidelineCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuidelineCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chunkId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<String> ruleTags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuidelineCacheCompanion(
                chunkId: chunkId,
                source: source,
                title: title,
                body: body,
                keywords: keywords,
                ruleTags: ruleTags,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chunkId,
                required String source,
                Value<String> title = const Value.absent(),
                required String body,
                Value<String> keywords = const Value.absent(),
                Value<String> ruleTags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuidelineCacheCompanion.insert(
                chunkId: chunkId,
                source: source,
                title: title,
                body: body,
                keywords: keywords,
                ruleTags: ruleTags,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuidelineCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GuidelineCacheTable,
      GuidelineChunkRow,
      $$GuidelineCacheTableFilterComposer,
      $$GuidelineCacheTableOrderingComposer,
      $$GuidelineCacheTableAnnotationComposer,
      $$GuidelineCacheTableCreateCompanionBuilder,
      $$GuidelineCacheTableUpdateCompanionBuilder,
      (
        GuidelineChunkRow,
        BaseReferences<_$AppDatabase, $GuidelineCacheTable, GuidelineChunkRow>,
      ),
      GuidelineChunkRow,
      PrefetchHooks Function()
    >;
typedef $$ExplanationsTableCreateCompanionBuilder =
    ExplanationsCompanion Function({
      required String screeningId,
      required String source,
      required String summary,
      required String whyThisLevel,
      required String safeNextSteps,
      required String whenToEscalate,
      required String questionsToAsk,
      Value<String> citations,
      required String disclaimer,
      Value<String> modelName,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ExplanationsTableUpdateCompanionBuilder =
    ExplanationsCompanion Function({
      Value<String> screeningId,
      Value<String> source,
      Value<String> summary,
      Value<String> whyThisLevel,
      Value<String> safeNextSteps,
      Value<String> whenToEscalate,
      Value<String> questionsToAsk,
      Value<String> citations,
      Value<String> disclaimer,
      Value<String> modelName,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ExplanationsTableFilterComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whyThisLevel => $composableBuilder(
    column: $table.whyThisLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get safeNextSteps => $composableBuilder(
    column: $table.safeNextSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get whenToEscalate => $composableBuilder(
    column: $table.whenToEscalate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionsToAsk => $composableBuilder(
    column: $table.questionsToAsk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disclaimer => $composableBuilder(
    column: $table.disclaimer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExplanationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whyThisLevel => $composableBuilder(
    column: $table.whyThisLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get safeNextSteps => $composableBuilder(
    column: $table.safeNextSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get whenToEscalate => $composableBuilder(
    column: $table.whenToEscalate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionsToAsk => $composableBuilder(
    column: $table.questionsToAsk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disclaimer => $composableBuilder(
    column: $table.disclaimer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExplanationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExplanationsTable> {
  $$ExplanationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get whyThisLevel => $composableBuilder(
    column: $table.whyThisLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get safeNextSteps => $composableBuilder(
    column: $table.safeNextSteps,
    builder: (column) => column,
  );

  GeneratedColumn<String> get whenToEscalate => $composableBuilder(
    column: $table.whenToEscalate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionsToAsk => $composableBuilder(
    column: $table.questionsToAsk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get citations =>
      $composableBuilder(column: $table.citations, builder: (column) => column);

  GeneratedColumn<String> get disclaimer => $composableBuilder(
    column: $table.disclaimer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExplanationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExplanationsTable,
          ExplanationRow,
          $$ExplanationsTableFilterComposer,
          $$ExplanationsTableOrderingComposer,
          $$ExplanationsTableAnnotationComposer,
          $$ExplanationsTableCreateCompanionBuilder,
          $$ExplanationsTableUpdateCompanionBuilder,
          (
            ExplanationRow,
            BaseReferences<_$AppDatabase, $ExplanationsTable, ExplanationRow>,
          ),
          ExplanationRow,
          PrefetchHooks Function()
        > {
  $$ExplanationsTableTableManager(_$AppDatabase db, $ExplanationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExplanationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExplanationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExplanationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> screeningId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> whyThisLevel = const Value.absent(),
                Value<String> safeNextSteps = const Value.absent(),
                Value<String> whenToEscalate = const Value.absent(),
                Value<String> questionsToAsk = const Value.absent(),
                Value<String> citations = const Value.absent(),
                Value<String> disclaimer = const Value.absent(),
                Value<String> modelName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExplanationsCompanion(
                screeningId: screeningId,
                source: source,
                summary: summary,
                whyThisLevel: whyThisLevel,
                safeNextSteps: safeNextSteps,
                whenToEscalate: whenToEscalate,
                questionsToAsk: questionsToAsk,
                citations: citations,
                disclaimer: disclaimer,
                modelName: modelName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String screeningId,
                required String source,
                required String summary,
                required String whyThisLevel,
                required String safeNextSteps,
                required String whenToEscalate,
                required String questionsToAsk,
                Value<String> citations = const Value.absent(),
                required String disclaimer,
                Value<String> modelName = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExplanationsCompanion.insert(
                screeningId: screeningId,
                source: source,
                summary: summary,
                whyThisLevel: whyThisLevel,
                safeNextSteps: safeNextSteps,
                whenToEscalate: whenToEscalate,
                questionsToAsk: questionsToAsk,
                citations: citations,
                disclaimer: disclaimer,
                modelName: modelName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExplanationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExplanationsTable,
      ExplanationRow,
      $$ExplanationsTableFilterComposer,
      $$ExplanationsTableOrderingComposer,
      $$ExplanationsTableAnnotationComposer,
      $$ExplanationsTableCreateCompanionBuilder,
      $$ExplanationsTableUpdateCompanionBuilder,
      (
        ExplanationRow,
        BaseReferences<_$AppDatabase, $ExplanationsTable, ExplanationRow>,
      ),
      ExplanationRow,
      PrefetchHooks Function()
    >;
typedef $$EmergencyContactsTableCreateCompanionBuilder =
    EmergencyContactsCompanion Function({
      required String id,
      required String name,
      required String phone,
      Value<String> relation,
      Value<bool> isPrimary,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$EmergencyContactsTableUpdateCompanionBuilder =
    EmergencyContactsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> phone,
      Value<String> relation,
      Value<bool> isPrimary,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$EmergencyContactsTableFilterComposer
    extends Composer<_$AppDatabase, $EmergencyContactsTable> {
  $$EmergencyContactsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmergencyContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmergencyContactsTable> {
  $$EmergencyContactsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmergencyContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmergencyContactsTable> {
  $$EmergencyContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$EmergencyContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmergencyContactsTable,
          EmergencyContactRow,
          $$EmergencyContactsTableFilterComposer,
          $$EmergencyContactsTableOrderingComposer,
          $$EmergencyContactsTableAnnotationComposer,
          $$EmergencyContactsTableCreateCompanionBuilder,
          $$EmergencyContactsTableUpdateCompanionBuilder,
          (
            EmergencyContactRow,
            BaseReferences<
              _$AppDatabase,
              $EmergencyContactsTable,
              EmergencyContactRow
            >,
          ),
          EmergencyContactRow,
          PrefetchHooks Function()
        > {
  $$EmergencyContactsTableTableManager(
    _$AppDatabase db,
    $EmergencyContactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmergencyContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmergencyContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmergencyContactsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmergencyContactsCompanion(
                id: id,
                name: name,
                phone: phone,
                relation: relation,
                isPrimary: isPrimary,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String phone,
                Value<String> relation = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmergencyContactsCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                relation: relation,
                isPrimary: isPrimary,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmergencyContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmergencyContactsTable,
      EmergencyContactRow,
      $$EmergencyContactsTableFilterComposer,
      $$EmergencyContactsTableOrderingComposer,
      $$EmergencyContactsTableAnnotationComposer,
      $$EmergencyContactsTableCreateCompanionBuilder,
      $$EmergencyContactsTableUpdateCompanionBuilder,
      (
        EmergencyContactRow,
        BaseReferences<
          _$AppDatabase,
          $EmergencyContactsTable,
          EmergencyContactRow
        >,
      ),
      EmergencyContactRow,
      PrefetchHooks Function()
    >;
typedef $$SosEventsTableCreateCompanionBuilder =
    SosEventsCompanion Function({
      required String id,
      Value<String?> patientId,
      Value<String?> screeningId,
      required String trigger,
      required DateTime triggeredAt,
      Value<String> contactsNotified,
      Value<String> message,
      Value<String> status,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int> rowid,
    });
typedef $$SosEventsTableUpdateCompanionBuilder =
    SosEventsCompanion Function({
      Value<String> id,
      Value<String?> patientId,
      Value<String?> screeningId,
      Value<String> trigger,
      Value<DateTime> triggeredAt,
      Value<String> contactsNotified,
      Value<String> message,
      Value<String> status,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int> rowid,
    });

class $$SosEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SosEventsTable> {
  $$SosEventsTableFilterComposer({
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

  ColumnFilters<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactsNotified => $composableBuilder(
    column: $table.contactsNotified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SosEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SosEventsTable> {
  $$SosEventsTableOrderingComposer({
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

  ColumnOrderings<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactsNotified => $composableBuilder(
    column: $table.contactsNotified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SosEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SosEventsTable> {
  $$SosEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get screeningId => $composableBuilder(
    column: $table.screeningId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumn<DateTime> get triggeredAt => $composableBuilder(
    column: $table.triggeredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactsNotified => $composableBuilder(
    column: $table.contactsNotified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);
}

class $$SosEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SosEventsTable,
          SosEventRow,
          $$SosEventsTableFilterComposer,
          $$SosEventsTableOrderingComposer,
          $$SosEventsTableAnnotationComposer,
          $$SosEventsTableCreateCompanionBuilder,
          $$SosEventsTableUpdateCompanionBuilder,
          (
            SosEventRow,
            BaseReferences<_$AppDatabase, $SosEventsTable, SosEventRow>,
          ),
          SosEventRow,
          PrefetchHooks Function()
        > {
  $$SosEventsTableTableManager(_$AppDatabase db, $SosEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SosEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SosEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SosEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> patientId = const Value.absent(),
                Value<String?> screeningId = const Value.absent(),
                Value<String> trigger = const Value.absent(),
                Value<DateTime> triggeredAt = const Value.absent(),
                Value<String> contactsNotified = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SosEventsCompanion(
                id: id,
                patientId: patientId,
                screeningId: screeningId,
                trigger: trigger,
                triggeredAt: triggeredAt,
                contactsNotified: contactsNotified,
                message: message,
                status: status,
                latitude: latitude,
                longitude: longitude,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> patientId = const Value.absent(),
                Value<String?> screeningId = const Value.absent(),
                required String trigger,
                required DateTime triggeredAt,
                Value<String> contactsNotified = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SosEventsCompanion.insert(
                id: id,
                patientId: patientId,
                screeningId: screeningId,
                trigger: trigger,
                triggeredAt: triggeredAt,
                contactsNotified: contactsNotified,
                message: message,
                status: status,
                latitude: latitude,
                longitude: longitude,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SosEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SosEventsTable,
      SosEventRow,
      $$SosEventsTableFilterComposer,
      $$SosEventsTableOrderingComposer,
      $$SosEventsTableAnnotationComposer,
      $$SosEventsTableCreateCompanionBuilder,
      $$SosEventsTableUpdateCompanionBuilder,
      (
        SosEventRow,
        BaseReferences<_$AppDatabase, $SosEventsTable, SosEventRow>,
      ),
      SosEventRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
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

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PatientsTableTableManager get patients =>
      $$PatientsTableTableManager(_db, _db.patients);
  $$ScreeningsTableTableManager get screenings =>
      $$ScreeningsTableTableManager(_db, _db.screenings);
  $$WaveformBlobsTableTableManager get waveformBlobs =>
      $$WaveformBlobsTableTableManager(_db, _db.waveformBlobs);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$GuidelineCacheTableTableManager get guidelineCache =>
      $$GuidelineCacheTableTableManager(_db, _db.guidelineCache);
  $$ExplanationsTableTableManager get explanations =>
      $$ExplanationsTableTableManager(_db, _db.explanations);
  $$EmergencyContactsTableTableManager get emergencyContacts =>
      $$EmergencyContactsTableTableManager(_db, _db.emergencyContacts);
  $$SosEventsTableTableManager get sosEvents =>
      $$SosEventsTableTableManager(_db, _db.sosEvents);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
