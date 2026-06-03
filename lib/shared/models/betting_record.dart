enum BetStatus { pending, won, lost, partial, voided }

enum BetType { single, parlay }

enum BetCategory { football, basketball, tennis, other }

class BettingRecord {
  final String id;
  final String userId;
  final BetType betType;
  final BetCategory category;
  final String? matchName;
  final String playType;
  final double odds;
  final double stake;
  final double potentialReturn;
  final double? resultAmount;
  final BetStatus status;
  final String note;
  final String? ticketImageUrl;
  final DateTime? settledAt;
  final DateTime createdAt;

  const BettingRecord({
    required this.id,
    required this.userId,
    required this.betType,
    required this.category,
    this.matchName,
    required this.playType,
    required this.odds,
    required this.stake,
    required this.potentialReturn,
    this.resultAmount,
    required this.status,
    this.note = '',
    this.ticketImageUrl,
    this.settledAt,
    required this.createdAt,
  });

  factory BettingRecord.fromJson(Map<String, dynamic> json) {
    return BettingRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      betType: BetType.values.firstWhere(
        (e) => e.name == json['bet_type'] as String,
      ),
      category: BetCategory.values.firstWhere(
        (e) => e.name == json['category'] as String,
      ),
      matchName: json['match_name'] as String?,
      playType: json['play_type'] as String? ?? '',
      odds: (json['odds'] as num).toDouble(),
      stake: (json['stake'] as num).toDouble(),
      potentialReturn: (json['potential_return'] as num).toDouble(),
      resultAmount: (json['result_amount'] as num?)?.toDouble(),
      status: BetStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
      ),
      note: json['note'] as String? ?? '',
      ticketImageUrl: json['ticket_image_url'] as String?,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bet_type': betType.name,
      'category': category.name,
      'match_name': matchName,
      'play_type': playType,
      'odds': odds,
      'stake': stake,
      'status': status.name,
      'note': note,
      'ticket_image_url': ticketImageUrl,
    };
  }

  double get pnl => resultAmount ?? 0;
  bool get isSettled => status != BetStatus.pending;
  bool get isPositive => (resultAmount ?? 0) > 0;
}
