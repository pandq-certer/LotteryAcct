class BetLeg {
  final String id;
  final String recordId;
  final String matchName;
  final String playType;
  final double odds;
  final double? resultAmount;
  final BetLegStatus status;
  final DateTime createdAt;

  const BetLeg({
    required this.id,
    required this.recordId,
    required this.matchName,
    required this.playType,
    required this.odds,
    this.resultAmount,
    required this.status,
    required this.createdAt,
  });

  factory BetLeg.fromJson(Map<String, dynamic> json) {
    return BetLeg(
      id: json['id'] as String,
      recordId: json['record_id'] as String,
      matchName: json['match_name'] as String,
      playType: json['play_type'] as String? ?? '',
      odds: (json['odds'] as num).toDouble(),
      resultAmount: (json['result_amount'] as num?)?.toDouble(),
      status: BetLegStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson(String parentRecordId) {
    return {
      'record_id': parentRecordId,
      'match_name': matchName,
      'play_type': playType,
      'odds': odds,
      'status': status.name,
    };
  }
}

enum BetLegStatus { pending, won, lost, partial, voided }
