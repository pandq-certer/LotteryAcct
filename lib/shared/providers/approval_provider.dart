import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_client_provider.dart';

enum ApprovalOp { create, settle, delete }
enum ApprovalStatus { pending, approved, rejected }

class ApprovalRequest {
  final String id;
  final ApprovalOp operation;
  final String? recordId;
  final Map<String, dynamic> payload;
  final String requestedBy;
  final String? approvedBy;
  final ApprovalStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const ApprovalRequest({
    required this.id,
    required this.operation,
    this.recordId,
    required this.payload,
    required this.requestedBy,
    this.approvedBy,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      operation: {'create': ApprovalOp.create, 'settle': ApprovalOp.settle, 'delete': ApprovalOp.delete}[json['operation'] as String] ?? ApprovalOp.create,
      recordId: json['record_id'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      requestedBy: json['requested_by'] as String,
      approvedBy: json['approved_by'] as String?,
      status: {'pending': ApprovalStatus.pending, 'approved': ApprovalStatus.approved, 'rejected': ApprovalStatus.rejected}[json['status'] as String] ?? ApprovalStatus.pending,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String).toLocal() : null,
    );
  }

  String get operationLabel => {'create': '添加投注', 'settle': '结算', 'delete': '删除'}[operation.name] ?? '';
}

final pendingApprovalsProvider = StreamProvider<List<ApprovalRequest>>((ref) {
  final client = ref.read(supabaseClientProvider);
  if (client.auth.currentUser == null) {
    return Stream.value([]);
  }

  final controller = StreamController<List<ApprovalRequest>>();

  // Initial fetch via REST query (more reliable than Realtime on mobile)
  () async {
    try {
      final data = await client
          .from('approval_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at');
      if (!controller.isClosed) {
        controller.add(data.map((e) => ApprovalRequest.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint('Pending approvals fetch error: $e');
      if (!controller.isClosed) controller.add([]);
    }
  }();

  // Realtime stream for live updates
  final sub = client
      .from('approval_requests')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at')
      .listen(
        (rows) {
          if (!controller.isClosed) {
            try {
              controller.add(rows.map((e) => ApprovalRequest.fromJson(e)).toList());
            } catch (e) {
              debugPrint('Pending approvals parse error: $e');
            }
          }
        },
        onError: (e) => debugPrint('Pending approvals Realtime error: $e'),
      );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

final allApprovalsProvider = StreamProvider<List<ApprovalRequest>>((ref) {
  final client = ref.read(supabaseClientProvider);
  if (client.auth.currentUser == null) {
    return Stream.value([]);
  }

  final controller = StreamController<List<ApprovalRequest>>();

  // Initial fetch via REST query
  () async {
    try {
      final data = await client
          .from('approval_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (!controller.isClosed) {
        controller.add(data.map((e) => ApprovalRequest.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint('All approvals fetch error: $e');
      if (!controller.isClosed) controller.add([]);
    }
  }();

  // Realtime stream for live updates
  final sub = client
      .from('approval_requests')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(50)
      .listen(
        (rows) {
          if (!controller.isClosed) {
            try {
              controller.add(rows.map((e) => ApprovalRequest.fromJson(e)).toList());
            } catch (e) {
              debugPrint('All approvals parse error: $e');
            }
          }
        },
        onError: (e) => debugPrint('All approvals Realtime error: $e'),
      );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

final approvalNotifierProvider = NotifierProvider<ApprovalNotifier, void>(ApprovalNotifier.new);

// Map: recordId -> ApprovalOp for all pending approval requests
final pendingApprovalMapProvider = FutureProvider<Map<String, ApprovalOp>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  if (client.auth.currentUser == null) return {};
  final data = await client
      .from('approval_requests')
      .select('record_id, operation')
      .eq('status', 'pending');
  return {
    for (final row in data)
      if (row['record_id'] != null)
        row['record_id'] as String: {'create': ApprovalOp.create, 'settle': ApprovalOp.settle, 'delete': ApprovalOp.delete}[row['operation'] as String] ?? ApprovalOp.create,
  };
});

class ApprovalNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<String> requestCreate({
    required String userId,
    required Map<String, dynamic> recordPayload,
  }) async {
    final client = ref.read(supabaseClientProvider);

    // Create record with awaiting_approval status
    final record = Map<String, dynamic>.from(recordPayload);
    record['status'] = 'awaiting_approval';
    record['user_id'] = userId;

    final data = await client.from('betting_records').insert(record).select().single();
    final recordId = data['id'] as String;

    // Create approval request
    await client.from('approval_requests').insert({
      'operation': 'create',
      'record_id': recordId,
      'payload': recordPayload,
      'requested_by': userId,
    });

    return recordId;
  }

  Future<void> requestSettle({
    required String recordId,
    required double resultAmount,
    required String status,
    required String userId,
  }) async {
    final client = ref.read(supabaseClientProvider);

    // Check for existing pending approval on this record
    final existing = await client
        .from('approval_requests')
        .select('id')
        .eq('record_id', recordId)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) {
      throw Exception('该记录已有待审批的请求');
    }

    final rec = await client
        .from('betting_records')
        .select('match_name, stake, odds, bet_type, play_type, category')
        .eq('id', recordId)
        .single();

    await client.from('approval_requests').insert({
      'operation': 'settle',
      'record_id': recordId,
      'payload': {
        'result_amount': resultAmount,
        'status': status,
        'match_name': rec['match_name'],
        'stake': rec['stake'],
        'odds': rec['odds'],
        'bet_type': rec['bet_type'],
        'play_type': rec['play_type'],
        'category': rec['category'],
      },
      'requested_by': userId,
    });
  }

  Future<void> requestDelete({
    required String recordId,
    required String userId,
  }) async {
    final client = ref.read(supabaseClientProvider);

    // Check for existing pending approval on this record
    final existing = await client
        .from('approval_requests')
        .select('id')
        .eq('record_id', recordId)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) {
      throw Exception('该记录已有待审批的请求');
    }

    final rec = await client
        .from('betting_records')
        .select('match_name, stake, odds, bet_type, play_type, category')
        .eq('id', recordId)
        .single();

    await client.from('approval_requests').insert({
      'operation': 'delete',
      'record_id': recordId,
      'payload': {
        'match_name': rec['match_name'],
        'stake': rec['stake'],
        'odds': rec['odds'],
        'bet_type': rec['bet_type'],
        'play_type': rec['play_type'],
        'category': rec['category'],
      },
      'requested_by': userId,
    });
  }

  Future<void> resolve(String requestId, bool approve) async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;
    final newStatus = approve ? 'approved' : 'rejected';

    // Fetch the request
    final req = await client
        .from('approval_requests')
        .select()
        .eq('id', requestId)
        .single();
    final operation = req['operation'] as String;
    final recordId = req['record_id'] as String?;
    final payload = req['payload'] as Map<String, dynamic>;

    // Update approval status
    await client.from('approval_requests').update({
      'status': newStatus,
      'approved_by': userId,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    if (!approve) {
      // If rejected and was a create, delete the awaiting_approval record
      if (operation == 'create' && recordId != null) {
        try {
          await client.from('betting_records').delete().eq('id', recordId);
        } catch (_) {
          // Record might already be deleted
        }
      }
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(allApprovalsProvider);
      return;
    }

    // Execute the approved operation
    switch (operation) {
      case 'create':
        if (recordId != null) {
          await client.from('betting_records').update({
            'status': 'pending',
          }).eq('id', recordId);
        }
        break;
      case 'settle':
        if (recordId != null) {
          await client.from('betting_records').update({
            'result_amount': payload['result_amount'],
            'status': payload['status'],
            'settled_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
        }
        break;
      case 'delete':
        if (recordId != null) {
          try {
            await client.from('betting_records').delete().eq('id', recordId);
          } catch (_) {
            // Record might already be deleted
          }
        }
        break;
    }

    ref.invalidate(pendingApprovalsProvider);
    ref.invalidate(allApprovalsProvider);
    ref.invalidate(pendingApprovalMapProvider);
  }
}
