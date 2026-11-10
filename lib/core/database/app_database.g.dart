// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalVisitsTable extends LocalVisits
    with TableInfo<$LocalVisitsTable, LocalVisit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<String> merchantId = GeneratedColumn<String>(
    'merchant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta(
    'visitedAt',
  );
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalVisitSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  ).withConverter<LocalVisitSyncStatus>($LocalVisitsTable.$convertersyncStatus);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    visitId,
    merchantId,
    customerId,
    visitedAt,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalVisit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('visit_id')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visit_id']!, _visitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_visitIdMeta);
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('visited_at')) {
      context.handle(
        _visitedAtMeta,
        visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedAtMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {visitId};
  @override
  LocalVisit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalVisit(
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visit_id'],
      )!,
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      visitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visited_at'],
      )!,
      syncStatus: $LocalVisitsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalVisitsTable createAlias(String alias) {
    return $LocalVisitsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalVisitSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalVisitSyncStatus>(
    LocalVisitSyncStatus.values,
  );
}

class LocalVisit extends DataClass implements Insertable<LocalVisit> {
  final String visitId;
  final String merchantId;
  final String customerId;
  final DateTime visitedAt;
  final LocalVisitSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalVisit({
    required this.visitId,
    required this.merchantId,
    required this.customerId,
    required this.visitedAt,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['visit_id'] = Variable<String>(visitId);
    map['merchant_id'] = Variable<String>(merchantId);
    map['customer_id'] = Variable<String>(customerId);
    map['visited_at'] = Variable<DateTime>(visitedAt);
    {
      map['sync_status'] = Variable<String>(
        $LocalVisitsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalVisitsCompanion toCompanion(bool nullToAbsent) {
    return LocalVisitsCompanion(
      visitId: Value(visitId),
      merchantId: Value(merchantId),
      customerId: Value(customerId),
      visitedAt: Value(visitedAt),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalVisit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalVisit(
      visitId: serializer.fromJson<String>(json['visitId']),
      merchantId: serializer.fromJson<String>(json['merchantId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      visitedAt: serializer.fromJson<DateTime>(json['visitedAt']),
      syncStatus: $LocalVisitsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'visitId': serializer.toJson<String>(visitId),
      'merchantId': serializer.toJson<String>(merchantId),
      'customerId': serializer.toJson<String>(customerId),
      'visitedAt': serializer.toJson<DateTime>(visitedAt),
      'syncStatus': serializer.toJson<String>(
        $LocalVisitsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalVisit copyWith({
    String? visitId,
    String? merchantId,
    String? customerId,
    DateTime? visitedAt,
    LocalVisitSyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalVisit(
    visitId: visitId ?? this.visitId,
    merchantId: merchantId ?? this.merchantId,
    customerId: customerId ?? this.customerId,
    visitedAt: visitedAt ?? this.visitedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalVisit copyWithCompanion(LocalVisitsCompanion data) {
    return LocalVisit(
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalVisit(')
          ..write('visitId: $visitId, ')
          ..write('merchantId: $merchantId, ')
          ..write('customerId: $customerId, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    visitId,
    merchantId,
    customerId,
    visitedAt,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalVisit &&
          other.visitId == this.visitId &&
          other.merchantId == this.merchantId &&
          other.customerId == this.customerId &&
          other.visitedAt == this.visitedAt &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalVisitsCompanion extends UpdateCompanion<LocalVisit> {
  final Value<String> visitId;
  final Value<String> merchantId;
  final Value<String> customerId;
  final Value<DateTime> visitedAt;
  final Value<LocalVisitSyncStatus> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalVisitsCompanion({
    this.visitId = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalVisitsCompanion.insert({
    required String visitId,
    required String merchantId,
    required String customerId,
    required DateTime visitedAt,
    this.syncStatus = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : visitId = Value(visitId),
       merchantId = Value(merchantId),
       customerId = Value(customerId),
       visitedAt = Value(visitedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalVisit> custom({
    Expression<String>? visitId,
    Expression<String>? merchantId,
    Expression<String>? customerId,
    Expression<DateTime>? visitedAt,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (visitId != null) 'visit_id': visitId,
      if (merchantId != null) 'merchant_id': merchantId,
      if (customerId != null) 'customer_id': customerId,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalVisitsCompanion copyWith({
    Value<String>? visitId,
    Value<String>? merchantId,
    Value<String>? customerId,
    Value<DateTime>? visitedAt,
    Value<LocalVisitSyncStatus>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalVisitsCompanion(
      visitId: visitId ?? this.visitId,
      merchantId: merchantId ?? this.merchantId,
      customerId: customerId ?? this.customerId,
      visitedAt: visitedAt ?? this.visitedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (visitId.present) {
      map['visit_id'] = Variable<String>(visitId.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<String>(merchantId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalVisitsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalVisitsCompanion(')
          ..write('visitId: $visitId, ')
          ..write('merchantId: $merchantId, ')
          ..write('customerId: $customerId, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _ownerScopeIdMeta = const VerificationMeta(
    'ownerScopeId',
  );
  @override
  late final GeneratedColumn<String> ownerScopeId = GeneratedColumn<String>(
    'owner_scope_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PendingActionType, String>
  actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PendingActionType>($PendingActionsTable.$converteractionType);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PendingActionStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  ).withConverter<PendingActionStatus>($PendingActionsTable.$converterstatus);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    ownerScopeId,
    actionType,
    entityType,
    entityId,
    payload,
    createdAt,
    updatedAt,
    status,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('owner_scope_id')) {
      context.handle(
        _ownerScopeIdMeta,
        ownerScopeId.isAcceptableOrUnknown(
          data['owner_scope_id']!,
          _ownerScopeIdMeta,
        ),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
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
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      ownerScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_scope_id'],
      ),
      actionType: $PendingActionsTable.$converteractionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action_type'],
        )!,
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      status: $PendingActionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PendingActionType, String, String>
  $converteractionType = const EnumNameConverter<PendingActionType>(
    PendingActionType.values,
  );
  static JsonTypeConverter2<PendingActionStatus, String, String>
  $converterstatus = const EnumNameConverter<PendingActionStatus>(
    PendingActionStatus.values,
  );
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final int id;
  final String operationId;
  final String? ownerScopeId;
  final PendingActionType actionType;
  final String entityType;
  final String entityId;
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PendingActionStatus status;
  final int retryCount;
  final String? lastError;
  const PendingAction({
    required this.id,
    required this.operationId,
    this.ownerScopeId,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || ownerScopeId != null) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId);
    }
    {
      map['action_type'] = Variable<String>(
        $PendingActionsTable.$converteractionType.toSql(actionType),
      );
    }
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['status'] = Variable<String>(
        $PendingActionsTable.$converterstatus.toSql(status),
      );
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      ownerScopeId: ownerScopeId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerScopeId),
      actionType: Value(actionType),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<int>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      ownerScopeId: serializer.fromJson<String?>(json['ownerScopeId']),
      actionType: $PendingActionsTable.$converteractionType.fromJson(
        serializer.fromJson<String>(json['actionType']),
      ),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: $PendingActionsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operationId': serializer.toJson<String>(operationId),
      'ownerScopeId': serializer.toJson<String?>(ownerScopeId),
      'actionType': serializer.toJson<String>(
        $PendingActionsTable.$converteractionType.toJson(actionType),
      ),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<String>(
        $PendingActionsTable.$converterstatus.toJson(status),
      ),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingAction copyWith({
    int? id,
    String? operationId,
    Value<String?> ownerScopeId = const Value.absent(),
    PendingActionType? actionType,
    String? entityType,
    String? entityId,
    String? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    PendingActionStatus? status,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => PendingAction(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    ownerScopeId: ownerScopeId.present ? ownerScopeId.value : this.ownerScopeId,
    actionType: actionType ?? this.actionType,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      ownerScopeId: data.ownerScopeId.present
          ? data.ownerScopeId.value
          : this.ownerScopeId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    ownerScopeId,
    actionType,
    entityType,
    entityId,
    payload,
    createdAt,
    updatedAt,
    status,
    retryCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.ownerScopeId == this.ownerScopeId &&
          other.actionType == this.actionType &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<int> id;
  final Value<String> operationId;
  final Value<String?> ownerScopeId;
  final Value<PendingActionType> actionType;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<PendingActionStatus> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.ownerScopeId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    this.id = const Value.absent(),
    required String operationId,
    this.ownerScopeId = const Value.absent(),
    required PendingActionType actionType,
    required String entityType,
    required String entityId,
    required String payload,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : operationId = Value(operationId),
       actionType = Value(actionType),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingAction> custom({
    Expression<int>? id,
    Expression<String>? operationId,
    Expression<String>? ownerScopeId,
    Expression<String>? actionType,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (ownerScopeId != null) 'owner_scope_id': ownerScopeId,
      if (actionType != null) 'action_type': actionType,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? operationId,
    Value<String?>? ownerScopeId,
    Value<PendingActionType>? actionType,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<PendingActionStatus>? status,
    Value<int>? retryCount,
    Value<String?>? lastError,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      ownerScopeId: ownerScopeId ?? this.ownerScopeId,
      actionType: actionType ?? this.actionType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (ownerScopeId.present) {
      map['owner_scope_id'] = Variable<String>(ownerScopeId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(
        $PendingActionsTable.$converteractionType.toSql(actionType.value),
      );
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PendingActionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('ownerScopeId: $ownerScopeId, ')
          ..write('actionType: $actionType, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $LocalCheckInsTable extends LocalCheckIns
    with TableInfo<$LocalCheckInsTable, LocalCheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _checkInIdMeta = const VerificationMeta(
    'checkInId',
  );
  @override
  late final GeneratedColumn<String> checkInId = GeneratedColumn<String>(
    'check_in_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUidMeta = const VerificationMeta(
    'ownerUid',
  );
  @override
  late final GeneratedColumn<String> ownerUid = GeneratedColumn<String>(
    'owner_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<String> merchantId = GeneratedColumn<String>(
    'merchant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<
    LocalCheckInBusinessStatus,
    String
  >
  businessStatus =
      GeneratedColumn<String>(
        'business_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalCheckInBusinessStatus>(
        $LocalCheckInsTable.$converterbusinessStatus,
      );
  @override
  late final GeneratedColumnWithTypeConverter<LocalCheckInSyncStatus, String>
  syncStatus =
      GeneratedColumn<String>(
        'sync_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('synced'),
      ).withConverter<LocalCheckInSyncStatus>(
        $LocalCheckInsTable.$convertersyncStatus,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visit_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    checkInId,
    ownerUid,
    merchantId,
    customerId,
    createdAt,
    expiresAt,
    businessStatus,
    syncStatus,
    updatedAt,
    visitId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCheckIn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('check_in_id')) {
      context.handle(
        _checkInIdMeta,
        checkInId.isAcceptableOrUnknown(data['check_in_id']!, _checkInIdMeta),
      );
    } else if (isInserting) {
      context.missing(_checkInIdMeta);
    }
    if (data.containsKey('owner_uid')) {
      context.handle(
        _ownerUidMeta,
        ownerUid.isAcceptableOrUnknown(data['owner_uid']!, _ownerUidMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerUidMeta);
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('visit_id')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visit_id']!, _visitIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {checkInId};
  @override
  LocalCheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCheckIn(
      checkInId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_in_id'],
      )!,
      ownerUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_uid'],
      )!,
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      businessStatus: $LocalCheckInsTable.$converterbusinessStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}business_status'],
        )!,
      ),
      syncStatus: $LocalCheckInsTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visit_id'],
      ),
    );
  }

  @override
  $LocalCheckInsTable createAlias(String alias) {
    return $LocalCheckInsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocalCheckInBusinessStatus, String, String>
  $converterbusinessStatus =
      const EnumNameConverter<LocalCheckInBusinessStatus>(
        LocalCheckInBusinessStatus.values,
      );
  static JsonTypeConverter2<LocalCheckInSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<LocalCheckInSyncStatus>(
    LocalCheckInSyncStatus.values,
  );
}

class LocalCheckIn extends DataClass implements Insertable<LocalCheckIn> {
  final String checkInId;
  final String ownerUid;
  final String merchantId;
  final String customerId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final LocalCheckInBusinessStatus businessStatus;
  final LocalCheckInSyncStatus syncStatus;
  final DateTime updatedAt;
  final String? visitId;
  const LocalCheckIn({
    required this.checkInId,
    required this.ownerUid,
    required this.merchantId,
    required this.customerId,
    required this.createdAt,
    required this.expiresAt,
    required this.businessStatus,
    required this.syncStatus,
    required this.updatedAt,
    this.visitId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['check_in_id'] = Variable<String>(checkInId);
    map['owner_uid'] = Variable<String>(ownerUid);
    map['merchant_id'] = Variable<String>(merchantId);
    map['customer_id'] = Variable<String>(customerId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    {
      map['business_status'] = Variable<String>(
        $LocalCheckInsTable.$converterbusinessStatus.toSql(businessStatus),
      );
    }
    {
      map['sync_status'] = Variable<String>(
        $LocalCheckInsTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || visitId != null) {
      map['visit_id'] = Variable<String>(visitId);
    }
    return map;
  }

  LocalCheckInsCompanion toCompanion(bool nullToAbsent) {
    return LocalCheckInsCompanion(
      checkInId: Value(checkInId),
      ownerUid: Value(ownerUid),
      merchantId: Value(merchantId),
      customerId: Value(customerId),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      businessStatus: Value(businessStatus),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
      visitId: visitId == null && nullToAbsent
          ? const Value.absent()
          : Value(visitId),
    );
  }

  factory LocalCheckIn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCheckIn(
      checkInId: serializer.fromJson<String>(json['checkInId']),
      ownerUid: serializer.fromJson<String>(json['ownerUid']),
      merchantId: serializer.fromJson<String>(json['merchantId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      businessStatus: $LocalCheckInsTable.$converterbusinessStatus.fromJson(
        serializer.fromJson<String>(json['businessStatus']),
      ),
      syncStatus: $LocalCheckInsTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      visitId: serializer.fromJson<String?>(json['visitId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'checkInId': serializer.toJson<String>(checkInId),
      'ownerUid': serializer.toJson<String>(ownerUid),
      'merchantId': serializer.toJson<String>(merchantId),
      'customerId': serializer.toJson<String>(customerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'businessStatus': serializer.toJson<String>(
        $LocalCheckInsTable.$converterbusinessStatus.toJson(businessStatus),
      ),
      'syncStatus': serializer.toJson<String>(
        $LocalCheckInsTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'visitId': serializer.toJson<String?>(visitId),
    };
  }

  LocalCheckIn copyWith({
    String? checkInId,
    String? ownerUid,
    String? merchantId,
    String? customerId,
    DateTime? createdAt,
    DateTime? expiresAt,
    LocalCheckInBusinessStatus? businessStatus,
    LocalCheckInSyncStatus? syncStatus,
    DateTime? updatedAt,
    Value<String?> visitId = const Value.absent(),
  }) => LocalCheckIn(
    checkInId: checkInId ?? this.checkInId,
    ownerUid: ownerUid ?? this.ownerUid,
    merchantId: merchantId ?? this.merchantId,
    customerId: customerId ?? this.customerId,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    businessStatus: businessStatus ?? this.businessStatus,
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: updatedAt ?? this.updatedAt,
    visitId: visitId.present ? visitId.value : this.visitId,
  );
  LocalCheckIn copyWithCompanion(LocalCheckInsCompanion data) {
    return LocalCheckIn(
      checkInId: data.checkInId.present ? data.checkInId.value : this.checkInId,
      ownerUid: data.ownerUid.present ? data.ownerUid.value : this.ownerUid,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      businessStatus: data.businessStatus.present
          ? data.businessStatus.value
          : this.businessStatus,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckIn(')
          ..write('checkInId: $checkInId, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('merchantId: $merchantId, ')
          ..write('customerId: $customerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('businessStatus: $businessStatus, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('visitId: $visitId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    checkInId,
    ownerUid,
    merchantId,
    customerId,
    createdAt,
    expiresAt,
    businessStatus,
    syncStatus,
    updatedAt,
    visitId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCheckIn &&
          other.checkInId == this.checkInId &&
          other.ownerUid == this.ownerUid &&
          other.merchantId == this.merchantId &&
          other.customerId == this.customerId &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.businessStatus == this.businessStatus &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt &&
          other.visitId == this.visitId);
}

class LocalCheckInsCompanion extends UpdateCompanion<LocalCheckIn> {
  final Value<String> checkInId;
  final Value<String> ownerUid;
  final Value<String> merchantId;
  final Value<String> customerId;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<LocalCheckInBusinessStatus> businessStatus;
  final Value<LocalCheckInSyncStatus> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<String?> visitId;
  final Value<int> rowid;
  const LocalCheckInsCompanion({
    this.checkInId = const Value.absent(),
    this.ownerUid = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.businessStatus = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.visitId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCheckInsCompanion.insert({
    required String checkInId,
    required String ownerUid,
    required String merchantId,
    required String customerId,
    required DateTime createdAt,
    required DateTime expiresAt,
    required LocalCheckInBusinessStatus businessStatus,
    this.syncStatus = const Value.absent(),
    required DateTime updatedAt,
    this.visitId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : checkInId = Value(checkInId),
       ownerUid = Value(ownerUid),
       merchantId = Value(merchantId),
       customerId = Value(customerId),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt),
       businessStatus = Value(businessStatus),
       updatedAt = Value(updatedAt);
  static Insertable<LocalCheckIn> custom({
    Expression<String>? checkInId,
    Expression<String>? ownerUid,
    Expression<String>? merchantId,
    Expression<String>? customerId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? businessStatus,
    Expression<String>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<String>? visitId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (checkInId != null) 'check_in_id': checkInId,
      if (ownerUid != null) 'owner_uid': ownerUid,
      if (merchantId != null) 'merchant_id': merchantId,
      if (customerId != null) 'customer_id': customerId,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (businessStatus != null) 'business_status': businessStatus,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (visitId != null) 'visit_id': visitId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCheckInsCompanion copyWith({
    Value<String>? checkInId,
    Value<String>? ownerUid,
    Value<String>? merchantId,
    Value<String>? customerId,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<LocalCheckInBusinessStatus>? businessStatus,
    Value<LocalCheckInSyncStatus>? syncStatus,
    Value<DateTime>? updatedAt,
    Value<String?>? visitId,
    Value<int>? rowid,
  }) {
    return LocalCheckInsCompanion(
      checkInId: checkInId ?? this.checkInId,
      ownerUid: ownerUid ?? this.ownerUid,
      merchantId: merchantId ?? this.merchantId,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      businessStatus: businessStatus ?? this.businessStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      visitId: visitId ?? this.visitId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (checkInId.present) {
      map['check_in_id'] = Variable<String>(checkInId.value);
    }
    if (ownerUid.present) {
      map['owner_uid'] = Variable<String>(ownerUid.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<String>(merchantId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (businessStatus.present) {
      map['business_status'] = Variable<String>(
        $LocalCheckInsTable.$converterbusinessStatus.toSql(
          businessStatus.value,
        ),
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $LocalCheckInsTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (visitId.present) {
      map['visit_id'] = Variable<String>(visitId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckInsCompanion(')
          ..write('checkInId: $checkInId, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('merchantId: $merchantId, ')
          ..write('customerId: $customerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('businessStatus: $businessStatus, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('visitId: $visitId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalVisitsTable localVisits = $LocalVisitsTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final $LocalCheckInsTable localCheckIns = $LocalCheckInsTable(this);
  late final Index idxLocalVisitsMerchantVisitedAt = Index(
    'idx_local_visits_merchant_visited_at',
    'CREATE INDEX idx_local_visits_merchant_visited_at ON local_visits (merchant_id, visited_at)',
  );
  late final Index idxLocalVisitsCustomerVisitedAt = Index(
    'idx_local_visits_customer_visited_at',
    'CREATE INDEX idx_local_visits_customer_visited_at ON local_visits (customer_id, visited_at)',
  );
  late final Index idxLocalVisitsSyncStatus = Index(
    'idx_local_visits_sync_status',
    'CREATE INDEX idx_local_visits_sync_status ON local_visits (sync_status)',
  );
  late final Index idxPendingActionsStatusCreatedAt = Index(
    'idx_pending_actions_status_created_at',
    'CREATE INDEX idx_pending_actions_status_created_at ON pending_actions (status, created_at)',
  );
  late final Index idxPendingActionsEntity = Index(
    'idx_pending_actions_entity',
    'CREATE INDEX idx_pending_actions_entity ON pending_actions (entity_type, entity_id)',
  );
  late final Index idxPendingActionsOwnerStatusCreatedAt = Index(
    'idx_pending_actions_owner_status_created_at',
    'CREATE INDEX idx_pending_actions_owner_status_created_at ON pending_actions (owner_scope_id, status, created_at)',
  );
  late final Index idxLocalCheckinsMerchantStatusCreated = Index(
    'idx_local_checkins_merchant_status_created',
    'CREATE INDEX idx_local_checkins_merchant_status_created ON local_check_ins (merchant_id, business_status, created_at)',
  );
  late final Index idxLocalCheckinsMerchantExpires = Index(
    'idx_local_checkins_merchant_expires',
    'CREATE INDEX idx_local_checkins_merchant_expires ON local_check_ins (merchant_id, expires_at)',
  );
  late final Index idxLocalCheckinsOwnerStatus = Index(
    'idx_local_checkins_owner_status',
    'CREATE INDEX idx_local_checkins_owner_status ON local_check_ins (owner_uid, business_status)',
  );
  late final VisitDao visitDao = VisitDao(this as AppDatabase);
  late final PendingActionDao pendingActionDao = PendingActionDao(
    this as AppDatabase,
  );
  late final CheckInDao checkInDao = CheckInDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localVisits,
    pendingActions,
    localCheckIns,
    idxLocalVisitsMerchantVisitedAt,
    idxLocalVisitsCustomerVisitedAt,
    idxLocalVisitsSyncStatus,
    idxPendingActionsStatusCreatedAt,
    idxPendingActionsEntity,
    idxPendingActionsOwnerStatusCreatedAt,
    idxLocalCheckinsMerchantStatusCreated,
    idxLocalCheckinsMerchantExpires,
    idxLocalCheckinsOwnerStatus,
  ];
}

typedef $$LocalVisitsTableCreateCompanionBuilder =
    LocalVisitsCompanion Function({
      required String visitId,
      required String merchantId,
      required String customerId,
      required DateTime visitedAt,
      Value<LocalVisitSyncStatus> syncStatus,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalVisitsTableUpdateCompanionBuilder =
    LocalVisitsCompanion Function({
      Value<String> visitId,
      Value<String> merchantId,
      Value<String> customerId,
      Value<DateTime> visitedAt,
      Value<LocalVisitSyncStatus> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalVisitsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalVisitsTable> {
  $$LocalVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    LocalVisitSyncStatus,
    LocalVisitSyncStatus,
    String
  >
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalVisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalVisitsTable> {
  $$LocalVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalVisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalVisitsTable> {
  $$LocalVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get visitId =>
      $composableBuilder(column: $table.visitId, builder: (column) => column);

  GeneratedColumn<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalVisitSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalVisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalVisitsTable,
          LocalVisit,
          $$LocalVisitsTableFilterComposer,
          $$LocalVisitsTableOrderingComposer,
          $$LocalVisitsTableAnnotationComposer,
          $$LocalVisitsTableCreateCompanionBuilder,
          $$LocalVisitsTableUpdateCompanionBuilder,
          (
            LocalVisit,
            BaseReferences<_$AppDatabase, $LocalVisitsTable, LocalVisit>,
          ),
          LocalVisit,
          PrefetchHooks Function()
        > {
  $$LocalVisitsTableTableManager(_$AppDatabase db, $LocalVisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> visitId = const Value.absent(),
                Value<String> merchantId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<DateTime> visitedAt = const Value.absent(),
                Value<LocalVisitSyncStatus> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalVisitsCompanion(
                visitId: visitId,
                merchantId: merchantId,
                customerId: customerId,
                visitedAt: visitedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String visitId,
                required String merchantId,
                required String customerId,
                required DateTime visitedAt,
                Value<LocalVisitSyncStatus> syncStatus = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalVisitsCompanion.insert(
                visitId: visitId,
                merchantId: merchantId,
                customerId: customerId,
                visitedAt: visitedAt,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalVisitsTable, LocalVisit>(table),
                  BaseReferences<_$AppDatabase, $LocalVisitsTable, LocalVisit>(
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

typedef $$LocalVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalVisitsTable,
      LocalVisit,
      $$LocalVisitsTableFilterComposer,
      $$LocalVisitsTableOrderingComposer,
      $$LocalVisitsTableAnnotationComposer,
      $$LocalVisitsTableCreateCompanionBuilder,
      $$LocalVisitsTableUpdateCompanionBuilder,
      (
        LocalVisit,
        BaseReferences<_$AppDatabase, $LocalVisitsTable, LocalVisit>,
      ),
      LocalVisit,
      PrefetchHooks Function()
    >;
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      required String operationId,
      Value<String?> ownerScopeId,
      required PendingActionType actionType,
      required String entityType,
      required String entityId,
      required String payload,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<PendingActionStatus> status,
      Value<int> retryCount,
      Value<String?> lastError,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      Value<String> operationId,
      Value<String?> ownerScopeId,
      Value<PendingActionType> actionType,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<PendingActionStatus> status,
      Value<int> retryCount,
      Value<String?> lastError,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PendingActionType, PendingActionType, String>
  get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    PendingActionStatus,
    PendingActionStatus,
    String
  >
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerScopeId => $composableBuilder(
    column: $table.ownerScopeId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PendingActionType, String> get actionType =>
      $composableBuilder(
        column: $table.actionType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PendingActionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingAction,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingAction,
            BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
          ),
          PendingAction,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String?> ownerScopeId = const Value.absent(),
                Value<PendingActionType> actionType = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<PendingActionStatus> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                operationId: operationId,
                ownerScopeId: ownerScopeId,
                actionType: actionType,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationId,
                Value<String?> ownerScopeId = const Value.absent(),
                required PendingActionType actionType,
                required String entityType,
                required String entityId,
                required String payload,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<PendingActionStatus> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingActionsCompanion.insert(
                id: id,
                operationId: operationId,
                ownerScopeId: ownerScopeId,
                actionType: actionType,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                retryCount: retryCount,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingActionsTable, PendingAction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingActionsTable,
                    PendingAction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingAction,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingAction,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
      ),
      PendingAction,
      PrefetchHooks Function()
    >;
typedef $$LocalCheckInsTableCreateCompanionBuilder =
    LocalCheckInsCompanion Function({
      required String checkInId,
      required String ownerUid,
      required String merchantId,
      required String customerId,
      required DateTime createdAt,
      required DateTime expiresAt,
      required LocalCheckInBusinessStatus businessStatus,
      Value<LocalCheckInSyncStatus> syncStatus,
      required DateTime updatedAt,
      Value<String?> visitId,
      Value<int> rowid,
    });
typedef $$LocalCheckInsTableUpdateCompanionBuilder =
    LocalCheckInsCompanion Function({
      Value<String> checkInId,
      Value<String> ownerUid,
      Value<String> merchantId,
      Value<String> customerId,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<LocalCheckInBusinessStatus> businessStatus,
      Value<LocalCheckInSyncStatus> syncStatus,
      Value<DateTime> updatedAt,
      Value<String?> visitId,
      Value<int> rowid,
    });

class $$LocalCheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get checkInId => $composableBuilder(
    column: $table.checkInId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    LocalCheckInBusinessStatus,
    LocalCheckInBusinessStatus,
    String
  >
  get businessStatus => $composableBuilder(
    column: $table.businessStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    LocalCheckInSyncStatus,
    LocalCheckInSyncStatus,
    String
  >
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get checkInId => $composableBuilder(
    column: $table.checkInId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessStatus => $composableBuilder(
    column: $table.businessStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get checkInId =>
      $composableBuilder(column: $table.checkInId, builder: (column) => column);

  GeneratedColumn<String> get ownerUid =>
      $composableBuilder(column: $table.ownerUid, builder: (column) => column);

  GeneratedColumn<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalCheckInBusinessStatus, String>
  get businessStatus => $composableBuilder(
    column: $table.businessStatus,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<LocalCheckInSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get visitId =>
      $composableBuilder(column: $table.visitId, builder: (column) => column);
}

class $$LocalCheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCheckInsTable,
          LocalCheckIn,
          $$LocalCheckInsTableFilterComposer,
          $$LocalCheckInsTableOrderingComposer,
          $$LocalCheckInsTableAnnotationComposer,
          $$LocalCheckInsTableCreateCompanionBuilder,
          $$LocalCheckInsTableUpdateCompanionBuilder,
          (
            LocalCheckIn,
            BaseReferences<_$AppDatabase, $LocalCheckInsTable, LocalCheckIn>,
          ),
          LocalCheckIn,
          PrefetchHooks Function()
        > {
  $$LocalCheckInsTableTableManager(_$AppDatabase db, $LocalCheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> checkInId = const Value.absent(),
                Value<String> ownerUid = const Value.absent(),
                Value<String> merchantId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<LocalCheckInBusinessStatus> businessStatus =
                    const Value.absent(),
                Value<LocalCheckInSyncStatus> syncStatus = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> visitId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCheckInsCompanion(
                checkInId: checkInId,
                ownerUid: ownerUid,
                merchantId: merchantId,
                customerId: customerId,
                createdAt: createdAt,
                expiresAt: expiresAt,
                businessStatus: businessStatus,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                visitId: visitId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String checkInId,
                required String ownerUid,
                required String merchantId,
                required String customerId,
                required DateTime createdAt,
                required DateTime expiresAt,
                required LocalCheckInBusinessStatus businessStatus,
                Value<LocalCheckInSyncStatus> syncStatus = const Value.absent(),
                required DateTime updatedAt,
                Value<String?> visitId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCheckInsCompanion.insert(
                checkInId: checkInId,
                ownerUid: ownerUid,
                merchantId: merchantId,
                customerId: customerId,
                createdAt: createdAt,
                expiresAt: expiresAt,
                businessStatus: businessStatus,
                syncStatus: syncStatus,
                updatedAt: updatedAt,
                visitId: visitId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCheckInsTable, LocalCheckIn>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCheckInsTable,
                    LocalCheckIn
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCheckInsTable,
      LocalCheckIn,
      $$LocalCheckInsTableFilterComposer,
      $$LocalCheckInsTableOrderingComposer,
      $$LocalCheckInsTableAnnotationComposer,
      $$LocalCheckInsTableCreateCompanionBuilder,
      $$LocalCheckInsTableUpdateCompanionBuilder,
      (
        LocalCheckIn,
        BaseReferences<_$AppDatabase, $LocalCheckInsTable, LocalCheckIn>,
      ),
      LocalCheckIn,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalVisitsTableTableManager get localVisits =>
      $$LocalVisitsTableTableManager(_db, _db.localVisits);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
  $$LocalCheckInsTableTableManager get localCheckIns =>
      $$LocalCheckInsTableTableManager(_db, _db.localCheckIns);
}
