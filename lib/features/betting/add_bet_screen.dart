import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  BetType _betType = BetType.single;
  BetCategory _category = BetCategory.football;
  String _playType = '独赢';
  bool _loading = false;

  final List<_ParlayLegUi> _parlayLegs = [];

  static const _playTypes = ['独赢', '让球', '大小分', '波胆', '半全场'];
  static const _categories = [
    (BetCategory.football, '⚽ 足球'),
    (BetCategory.basketball, '🏀 篮球'),
    (BetCategory.tennis, '🎾 网球'),
    (BetCategory.other, '🎯 其他'),
  ];

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
    for (final leg in _parlayLegs) {
      leg.matchCtrl.dispose();
      leg.oddsCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (image == null) return;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在识别...'), backgroundColor: Color(0xFF111A2E), duration: Duration(seconds: 5)),
    );

    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      final ocr = ref.read(ocrServiceProvider);
      final result = await ocr.scanTicket(base64Str);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Auto-fill form
      if (result.matchName != null) _matchCtrl.text = result.matchName!;
      if (result.odds != null) _oddsCtrl.text = result.odds.toString();
      if (result.stake != null) _stakeCtrl.text = result.stake.toString();
      if (result.playType.isNotEmpty && _playTypes.contains(result.playType)) {
        _playType = result.playType;
      }
      final cat = BetCategory.values.where((c) => c.name == result.category).firstOrNull;
      if (cat != null) _category = cat;
      if (result.betType == 'parlay') {
        _betType = BetType.parlay;
        if (result.legs != null) {
          for (final leg in result.legs!) {
            final ui = _ParlayLegUi();
            ui.matchCtrl.text = leg.matchName;
            ui.oddsCtrl.text = leg.odds.toString();
            _parlayLegs.add(ui);
          }
        }
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 识别成功，已自动填充'), backgroundColor: Color(0xFF00C853), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别失败，请手动填写'), backgroundColor: Color(0xFFFFAB00)),
      );
    }
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
      final odds = double.parse(_oddsCtrl.text);
      final stake = double.parse(_stakeCtrl.text);

      if (_betType == BetType.single) {
        await ref.read(bettingRecordsProvider.notifier).createRecord(
              betType: BetType.single,
              category: _category,
              matchName: _matchCtrl.text,
              playType: _playType,
              odds: odds,
              stake: stake,
              note: _noteCtrl.text,
            );
      } else {
        final legs = _parlayLegs
            .where((l) => l.matchCtrl.text.isNotEmpty && l.oddsCtrl.text.isNotEmpty)
            .map((l) => (matchName: l.matchCtrl.text, playType: '', odds: double.parse(l.oddsCtrl.text)))
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
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2E),
                  border: Border.all(color: const Color(0x0FFFFFFF), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
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

            // Category
            _buildLabel('赛事类别'),
            Wrap(
              spacing: 8,
              children: _categories.map((c) => _catChip(c.$1 == _category, c.$2, () => setState(() => _category = c.$1))).toList(),
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
