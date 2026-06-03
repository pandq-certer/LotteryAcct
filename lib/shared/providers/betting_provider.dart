import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/betting_record.dart';
import '../models/bet_leg.dart';
import 'supabase_client_provider.dart';

// ── Betting Records ──

final bettingRecordsProvider = AsyncNotifierProvider<BettingRecordsNotifier, List<BettingRecord>>(
  BettingRecordsNotifier.new,
);

class BettingRecordsNotifier extends AsyncNotifier<List<BettingRecord>> {
  @override
  Future<List<BettingRecord>> build() async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await client
        .from('betting_records')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return data.map((e) => BettingRecord.fromJson(e)).toList();
  }

  Future<String> createRecord({
    required BetType betType,
    required BetCategory category,
    String? matchName,
    required String playType,
    required double odds,
    required double stake,
    String note = '',
    String? ticketImageUrl,
    List<({String matchName, String playType, double odds})>? legs,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;

    final payload = {
      'user_id': userId,
      'bet_type': betType.name,
      'category': category.name,
      'match_name': matchName,
      'play_type': playType,
      'odds': odds,
      'stake': stake,
      'note': note,
      'ticket_image_url': ticketImageUrl,
    };

    final data = await client.from('betting_records').insert(payload).select().single();
    final recordId = data['id'] as String;

    if (legs != null && legs.isNotEmpty) {
      final legsPayload = legs.map((leg) => {
        'record_id': recordId,
        'match_name': leg.matchName,
        'play_type': leg.playType,
        'odds': leg.odds,
      }).toList();
      await client.from('bet_legs').insert(legsPayload);
    }

    ref.invalidateSelf();
    return recordId;
  }

  Future<void> settleRecord(String recordId, double resultAmount, BetStatus status) async {
    final client = ref.read(supabaseClientProvider);
    await client.from('betting_records').update({
      'result_amount': resultAmount,
      'status': status.name,
      'settled_at': DateTime.now().toIso8601String(),
    }).eq('id', recordId);
    ref.invalidateSelf();
  }

  Future<void> deleteRecord(String recordId) async {
    final client = ref.read(supabaseClientProvider);
    await client.from('betting_records').delete().eq('id', recordId);
    ref.invalidateSelf();
  }
}

// ── Bet Legs ──

final betLegsProvider = FutureProvider.family<List<BetLeg>, String>((ref, recordId) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('bet_legs')
      .select()
      .eq('record_id', recordId)
      .order('created_at', ascending: true);
  return data.map((e) => BetLeg.fromJson(e)).toList();
});

// ── P&L Summary ──

class PnlSummary {
  final int totalBets;
  final int wins;
  final int settledBets;
  final double totalPnl;
  final double monthlyPnl;
  final double totalStake;
  final double? winRate;

  const PnlSummary({
    required this.totalBets,
    required this.wins,
    required this.settledBets,
    required this.totalPnl,
    required this.monthlyPnl,
    required this.totalStake,
    this.winRate,
  });

  factory PnlSummary.fromJson(Map<String, dynamic> json) {
    return PnlSummary(
      totalBets: json['total_bets'] as int,
      wins: json['wins'] as int,
      settledBets: json['settled_bets'] as int,
      totalPnl: (json['total_pnl'] as num).toDouble(),
      monthlyPnl: (json['monthly_pnl'] as num).toDouble(),
      totalStake: (json['total_stake'] as num).toDouble(),
      winRate: (json['win_rate'] as num?)?.toDouble(),
    );
  }
}

final pnlSummaryProvider = FutureProvider<PnlSummary?>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final data = await client
      .from('user_pnl_summary')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (data == null) {
    return const PnlSummary(
      totalBets: 0, wins: 0, settledBets: 0,
      totalPnl: 0, monthlyPnl: 0, totalStake: 0,
    );
  }
  return PnlSummary.fromJson(data);
});

// ── Daily P&L Trend ──

class DailyPnl {
  final DateTime date;
  final double dailyPnl;
  final double cumulativePnl;

  const DailyPnl({required this.date, required this.dailyPnl, required this.cumulativePnl});

  factory DailyPnl.fromJson(Map<String, dynamic> json) {
    return DailyPnl(
      date: DateTime.parse(json['bet_date'] as String),
      dailyPnl: (json['daily_pnl'] as num).toDouble(),
      cumulativePnl: (json['cumulative_pnl'] as num).toDouble(),
    );
  }
}

final dailyPnlProvider = FutureProvider<List<DailyPnl>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  final data = await client
      .from('daily_pnl_trend')
      .select()
      .eq('user_id', userId)
      .order('bet_date', ascending: true);

  return data.map((e) => DailyPnl.fromJson(e)).toList();
});
