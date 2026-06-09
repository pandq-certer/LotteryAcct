import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OcrResult {
  final String? matchName;
  final String playType;
  final String betSelection;
  final double? odds;
  final double? stake;
  final String category;
  final String betType;
  final List<OcrLeg>? legs;

  const OcrResult({
    this.matchName,
    this.playType = '',
    this.betSelection = '',
    this.odds,
    this.stake,
    this.category = 'football',
    this.betType = 'single',
    this.legs,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      matchName: json['match_name'] as String?,
      playType: json['play_type'] as String? ?? '',
      betSelection: json['bet_selection'] as String? ?? '',
      odds: (json['odds'] as num?)?.toDouble(),
      stake: (json['stake'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'football',
      betType: json['bet_type'] as String? ?? 'single',
      legs: (json['legs'] as List?)
          ?.map((e) => OcrLeg.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayTitle => matchName ?? (betType == 'parlay' ? '串关' : '--');
}

class OcrLeg {
  final String matchName;
  final double odds;

  const OcrLeg({required this.matchName, required this.odds});

  factory OcrLeg.fromJson(Map<String, dynamic> json) {
    return OcrLeg(
      matchName: json['match_name'] as String,
      odds: (json['odds'] as num).toDouble(),
    );
  }
}

class OcrService {
  final SupabaseClient _client;

  OcrService(this._client);

  /// Scan a single image, returns list of tickets (one image may contain multiple tickets)
  Future<List<OcrResult>> scanTicket(String base64Image) async {
    final response = await _client.functions.invoke(
      'ticket-ocr',
      body: {'image_base64': base64Image},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'OCR 失败');
    }

    final dataList = response.data['data'] as List;
    return dataList.map((e) => OcrResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Scan multiple images, returns all tickets from all images
  Future<List<OcrResult>> scanTickets(List<String> base64Images) async {
    final allResults = <OcrResult>[];
    for (final image in base64Images) {
      final results = await scanTicket(image);
      allResults.addAll(results);
    }
    return allResults;
  }

  Future<bool> verifyWinning(String base64Image, {String? matchName, String? playType}) async {
    final response = await _client.functions.invoke(
      'winning-ocr',
      body: {
        'image_base64': base64Image,
        if (matchName != null) 'match_name': matchName,
        if (playType != null) 'play_type': playType,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? '识别失败');
    }

    return response.data['data']['is_won'] as bool? ?? false;
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService(Supabase.instance.client);
});
