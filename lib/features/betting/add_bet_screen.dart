import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/betting_record.dart';
import '../../shared/providers/betting_provider.dart';
import '../../shared/services/ocr_service.dart';

class AddBetScreen extends ConsumerStatefulWidget {
  const AddBetScreen({super.key});

  @override
  ConsumerState<AddBetScreen> createState() => _AddBetScreenState();
}

class _AddBetScreenState extends ConsumerState<AddBetScreen> {
  final _matchCtrl = TextEditingController();
  final _oddsCtrl = TextEditingController();
  final _stakeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _selectionCtrl = TextEditingController();

  BetType _betType = BetType.single;
  final _category = BetCategory.football;
  String _playType = '独赢';
  bool _loading = false;
  bool _ocrLoading = false;
  String? _pendingImageUrl; // URL of uploaded ticket image from last OCR

  final List<_ParlayLegUi> _parlayLegs = [];

  static const _playTypes = ['独赢', '让球', '大小分', '波胆', '半全场'];
  @override
  void initState() {
    super.initState();
    // Init 2 default legs for parlay
    _parlayLegs.addAll([_ParlayLegUi(), _ParlayLegUi()]);
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _oddsCtrl.dispose();
    _stakeCtrl.dispose();
    _noteCtrl.dispose();
    _selectionCtrl.dispose();
    for (final leg in _parlayLegs) {
      leg.matchCtrl.dispose();
      leg.oddsCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00E676)),
              title: const Text('拍照识别'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF00E676)),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.collections, color: Color(0xFF00E676)),
              title: const Text('批量选择（多张票据）'),
              onTap: () => Navigator.pop(ctx, 'multi'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    if (action == 'multi') {
      _batchPick();
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 1024);
    if (image == null) return;

    if (!mounted) return;

    setState(() => _ocrLoading = true);

    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      final ocr = ref.read(ocrServiceProvider);
      final results = await ocr.scanTicket(base64Str);

      // Upload image to storage in parallel
      final imageUrl = await _uploadTicketImage(base64Str);

      if (!mounted) return;
      setState(() {
        _ocrLoading = false;
        _pendingImageUrl = imageUrl;
      });

      if (results.length == 1) {
        _fillForm(results.first);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别成功，已自动填充'), backgroundColor: Color(0xFF00C853), behavior: SnackBarBehavior.floating),
        );
      } else if (results.length > 1) {
        _showBatchResults(results);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到票据，请手动填写'), backgroundColor: Color(0xFFFFAB00)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocrLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别失败，请手动填写'), backgroundColor: Color(0xFFFFAB00)),
      );
    }
  }

  void _fillForm(OcrResult result) {
    if (result.matchName != null) _matchCtrl.text = result.matchName!;
    if (result.odds != null) _oddsCtrl.text = result.odds.toString();
    if (result.stake != null) _stakeCtrl.text = result.stake.toString();
    if (result.betSelection.isNotEmpty) _selectionCtrl.text = result.betSelection;
    if (result.playType.isNotEmpty && _playTypes.contains(result.playType)) {
      _playType = result.playType;
    }
    if (result.betType == 'parlay') {
      _betType = BetType.parlay;
      if (result.legs != null && result.legs!.isNotEmpty) {
        _parlayLegs.removeWhere((ui) => ui.matchCtrl.text.trim().isEmpty && ui.oddsCtrl.text.trim().isEmpty);
        for (final leg in result.legs!) {
          final ui = _ParlayLegUi();
          ui.matchCtrl.text = leg.matchName;
          ui.oddsCtrl.text = leg.odds.toString();
          _parlayLegs.add(ui);
        }
      }
      setState(() {});
    }
  }

  Future<void> _batchPick() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OcrProgressDialog(total: images.length),
    );

    final ocr = ref.read(ocrServiceProvider);
    final allResults = <OcrResult>[];
    final allImageUrls = <String?>[];
    var errors = 0;

    for (var i = 0; i < images.length; i++) {
      if (!mounted) break;
      _updateProgress(context, i + 1, images.length);

      try {
        final bytes = await File(images[i].path).readAsBytes();
        final base64Str = base64Encode(bytes);
        final results = await ocr.scanTicket(base64Str);
        final url = await _uploadTicketImage(base64Str);
        for (var j = 0; j < results.length; j++) {
          allImageUrls.add(url);
        }
        allResults.addAll(results);
      } catch (_) {
        errors++;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Close progress dialog

    if (allResults.isNotEmpty) {
      _showBatchResults(allResults, errors: errors, imageUrls: allImageUrls);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未识别到任何票据'), backgroundColor: Color(0xFFFFAB00)),
      );
    }
  }

  void _updateProgress(BuildContext context, int current, int total) {
    // Find the state in the progress dialog and update it
    final state = context.findAncestorStateOfType<_OcrProgressState>();
    state?.update(current, total);
  }

  void _showBatchResults(List<OcrResult> results, {int errors = 0, List<String?>? imageUrls}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1220),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BatchResultSheet(
        results: results,
        errors: errors,
        onConfirm: () async {
          Navigator.pop(ctx);
          final validResults = results.where((r) => r.odds != null && r.stake != null).toList();
          final records = validResults.asMap().entries.map((e) {
            final r = e.value;
            final isParlay = r.betType == 'parlay';
            List<({String matchName, String playType, double odds})>? legs;
            double odds = r.odds ?? 1.0;

            if (isParlay && r.legs != null && r.legs!.isNotEmpty) {
              legs = r.legs!.map((l) => (matchName: l.matchName, playType: '', odds: l.odds)).toList();
              odds = legs.fold<double>(1.0, (acc, l) => acc * l.odds);
            }

            return (
              betType: isParlay ? BetType.parlay : BetType.single,
              matchName: r.matchName,
              playType: r.playType.isNotEmpty ? r.playType : '独赢',
              betSelection: r.betSelection,
              odds: odds,
              stake: r.stake!,
              ticketImageUrl: imageUrls != null && e.key < imageUrls.length ? imageUrls[e.key] : null,
              legs: legs,
            );
          }).toList();

          if (records.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('没有有效的票据数据'), backgroundColor: Color(0xFFFFAB00)),
            );
            return;
          }

          final count = await ref.read(bettingRecordsProvider.notifier).batchCreateRecords(records);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('成功创建 $count 条记录'), backgroundColor: const Color(0xFF00C853), behavior: SnackBarBehavior.floating),
            );
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_betType == BetType.single) {
      if (_matchCtrl.text.isEmpty || _oddsCtrl.text.isEmpty || _stakeCtrl.text.isEmpty) {
        _showError('请填写比赛名称、赔率和投注金额');
        return;
      }
    } else {
      final validLegs = _parlayLegs.where((l) => l.matchCtrl.text.isNotEmpty && l.oddsCtrl.text.isNotEmpty).toList();
      if (validLegs.length < 2) {
        _showError('串关至少需要 2 场比赛');
        return;
      }
      if (_stakeCtrl.text.isEmpty) {
        _showError('请填写投注金额');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final stake = double.tryParse(_stakeCtrl.text);
      if (stake == null || stake <= 0) {
        _showError('请输入有效的投注金额');
        return;
      }

      if (_betType == BetType.single) {
        final odds = double.tryParse(_oddsCtrl.text);
        if (odds == null || odds <= 1) {
          _showError('请输入有效的赔率（大于 1）');
          return;
        }
        await ref.read(bettingRecordsProvider.notifier).createRecord(
              betType: BetType.single,
              category: _category,
              matchName: _matchCtrl.text,
              playType: _playType,
              betSelection: _selectionCtrl.text,
              odds: odds,
              stake: stake,
              note: _noteCtrl.text,
              ticketImageUrl: _pendingImageUrl,
            );
      } else {
        final legs = _parlayLegs
            .where((l) => l.matchCtrl.text.isNotEmpty && l.oddsCtrl.text.isNotEmpty)
            .map((l) {
              final odds = double.tryParse(l.oddsCtrl.text);
              if (odds == null || odds <= 1) throw FormatException('无效赔率: ${l.oddsCtrl.text}');
              return (matchName: l.matchCtrl.text, playType: '', odds: odds);
            })
            .toList();

        // Parlay odds = product of all legs
        final combinedOdds = legs.fold<double>(1.0, (acc, l) => acc * l.odds);

        await ref.read(bettingRecordsProvider.notifier).createRecord(
              betType: BetType.parlay,
              category: _category,
              playType: '串关',
              odds: combinedOdds,
              stake: stake,
              note: _noteCtrl.text,
              ticketImageUrl: _pendingImageUrl,
              legs: legs,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已保存'),
            backgroundColor: Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) _showError('保存失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _matchCtrl.clear();
    _oddsCtrl.clear();
    _stakeCtrl.clear();
    _noteCtrl.clear();
    _selectionCtrl.clear();
    _pendingImageUrl = null;
    for (final leg in _parlayLegs) {
      leg.matchCtrl.clear();
      leg.oddsCtrl.clear();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFFF3D57)),
    );
  }

  Future<String?> _uploadTicketImage(String base64Str) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = base64Decode(base64Str);
      await client.storage.from('tickets').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      return client.storage.from('tickets').getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加投注', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bet type selector
            _buildLabel('投注类型'),
            Row(
              children: [
                Expanded(child: _typeChip(_betType == BetType.single, '⚡ 单关', () => setState(() => _betType = BetType.single))),
                const SizedBox(width: 8),
                Expanded(child: _typeChip(_betType == BetType.parlay, '✨ 串关', () => setState(() => _betType = BetType.parlay))),
              ],
            ),
            const SizedBox(height: 16),

            // Photo upload
            GestureDetector(
              onTap: _ocrLoading ? null : _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2E),
                  border: Border.all(color: const Color(0x0FFFFFFF), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _ocrLoading
                    ? const Column(
                        children: [
                          SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00E676)),
                          ),
                          SizedBox(height: 12),
                          Text('正在识别票据...', style: TextStyle(fontSize: 13, color: Color(0xFF00E676), fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text('请稍候', style: TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
                        ],
                      )
                    : const Column(
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 36, color: Color(0xFF4A5568)),
                          SizedBox(height: 8),
                          Text('拍照识别彩票', style: TextStyle(fontSize: 13, color: Color(0xFF8A96B0), fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text('或从相册选择票据图片', style: TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Single bet form
            if (_betType == BetType.single) ...[
              _buildLabel('比赛名称'),
              TextField(controller: _matchCtrl, style: const TextStyle(color: Color(0xFFE8ECF4)), decoration: const InputDecoration(hintText: '如: 皇马 vs 巴萨')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildField('赔率', _oddsCtrl, '1.85', keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField('投注金额', _stakeCtrl, '¥500', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              _buildLabel('玩法'),
              Wrap(
                spacing: 8,
                children: _playTypes.map((p) => _catChip(_playType == p, p, () => setState(() => _playType = p))).toList(),
              ),
              const SizedBox(height: 12),
              _buildLabel('投注方向'),
              TextField(controller: _selectionCtrl, style: const TextStyle(color: Color(0xFFE8ECF4)), decoration: const InputDecoration(hintText: '如: 主胜、客胜、大2.5、2:1')),
            ],

            // Parlay legs
            if (_betType == BetType.parlay) ...[
              _buildLabel('串关场次'),
              ..._parlayLegs.asMap().entries.map((e) => _parlayLegCard(e.key, e.value)),
              GestureDetector(
                onTap: () => setState(() => _parlayLegs.add(_ParlayLegUi())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x0FFFFFFF), style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('+ 添加场次', style: TextStyle(color: Color(0xFF4A5568), fontSize: 12)),
                  ),
                ),
              ),
              _buildField('投注金额', _stakeCtrl, '¥200', keyboardType: TextInputType.number),
            ],
            const SizedBox(height: 12),

            _buildLabel('备注'),
            TextField(controller: _noteCtrl, style: const TextStyle(color: Color(0xFFE8ECF4)), decoration: const InputDecoration(hintText: '可选备注...')),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('✓ 保存投注记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A96B0), letterSpacing: 0.02)),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFFE8ECF4)),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _typeChip(bool active, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E676).withValues(alpha: 0.1) : const Color(0xFF111A2E),
          border: Border.all(color: active ? const Color(0xFF00E676) : const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? const Color(0xFF00E676) : const Color(0xFF8A96B0))),
        ),
      ),
    );
  }

  Widget _catChip(bool active, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E676).withValues(alpha: 0.1) : const Color(0xFF111A2E),
          border: Border.all(color: active ? const Color(0xFF00E676) : const Color(0x0FFFFFFF)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? const Color(0xFF00E676) : const Color(0xFF8A96B0))),
      ),
    );
  }

  Widget _parlayLegCard(int index, _ParlayLegUi leg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第 ${index + 1} 场', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF00E676))),
              if (_parlayLegs.length > 2)
                GestureDetector(
                  onTap: () => setState(() => _parlayLegs.removeAt(index)),
                  child: const Icon(Icons.close, size: 14, color: Color(0xFF4A5568)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 2, child: TextField(controller: leg.matchCtrl, style: const TextStyle(fontSize: 12, color: Color(0xFFE8ECF4)), decoration: const InputDecoration(hintText: '比赛名称', contentPadding: EdgeInsets.all(8)),)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: leg.oddsCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Color(0xFFE8ECF4)), decoration: const InputDecoration(hintText: '赔率', contentPadding: EdgeInsets.all(8)),)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParlayLegUi {
  final matchCtrl = TextEditingController();
  final oddsCtrl = TextEditingController();
}

class _OcrProgressDialog extends StatefulWidget {
  final int total;
  const _OcrProgressDialog({required this.total});

  @override
  State<_OcrProgressDialog> createState() => _OcrProgressState();
}

class _OcrProgressState extends State<_OcrProgressDialog> {
  int _current = 0;

  void update(int current, int total) {
    if (mounted) setState(() => _current = current);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36, height: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00E676)),
            ),
            const SizedBox(height: 16),
            Text(
              '正在识别票据...',
              style: GoogleFonts.notoSansSc(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFFE8ECF4)),
            ),
            const SizedBox(height: 8),
            Text(
              '$_current / ${widget.total}',
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: const Color(0xFF4A5568)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchResultSheet extends StatelessWidget {
  final List<OcrResult> results;
  final int errors;
  final VoidCallback onConfirm;

  const _BatchResultSheet({required this.results, required this.errors, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: const BoxDecoration(color: Color(0xFF4A5568), borderRadius: BorderRadius.all(Radius.circular(2)))),
            const SizedBox(height: 16),
            const Text('识别结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '共识别 ${results.length} 张票据${errors > 0 ? "，$errors 张失败" : ""}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A96B0)),
            ),
            const SizedBox(height: 16),
            ...results.asMap().entries.map((e) => _resultItem(e.key, e.value)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                child: Text(
                  '确认录入 ${results.where((r) => r.odds != null && r.stake != null).length} 条记录',
                  style: GoogleFonts.notoSansSc(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultItem(int index, OcrResult r) {
    final isValid = r.odds != null && r.stake != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isValid ? const Color(0xFF00E676).withValues(alpha: 0.3) : const Color(0xFFFF3D57).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: (isValid ? const Color(0xFF00E676) : const Color(0xFFFF3D57)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isValid ? '⚽' : '?',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.displayTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isValid
                      ? '${r.betType == 'parlay' ? '串关' : r.playType} · @${r.odds?.toStringAsFixed(2)} · ¥${r.stake?.toStringAsFixed(0)}'
                      : '数据不完整',
                  style: TextStyle(fontSize: 11, color: isValid ? const Color(0xFF4A5568) : const Color(0xFFFF3D57)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
