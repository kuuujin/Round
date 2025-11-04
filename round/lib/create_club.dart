import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateClubScreen extends StatelessWidget {
  final String userId;
  const CreateClubScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827), // 텍스트/아이콘 진회색
          title: const Text(
            '동호회 개설',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 안내 텍스트
            const Text(
              '기본 정보를 입력해 주세요.',
              style: TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 지역 (미구현 placeholder)
            const Text('지역', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            _RoundedFieldPlaceholder(hint: '동/읍/면 찾기'),

            const SizedBox(height: 14),
            const Text('모임 이름', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            _RoundedFieldPlaceholder(hint: '모임 이름'),

            const SizedBox(height: 14),
            const Text('모임 목표', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            _RoundedFieldPlaceholder(
              hint: '모임 목표를 설명해주세요.',
              minHeight: 110,
              alignTop: true,
            ),

            const SizedBox(height: 20),
            // 정원 (placeholder)
            const Text('정원 (예: 10 ~ 100명)', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Row(
              children: const [
                Expanded(child: _RoundedFieldPlaceholder(hint: '최소 인원')),
                SizedBox(width: 10),
                Expanded(child: _RoundedFieldPlaceholder(hint: '최대 인원')),
              ],
            ),

            const SizedBox(height: 28),
            // 만들기 버튼 (동작은 아직 없음)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 일단 뒤로
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '모임 만들기',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 회색 라운드 입력창 플레이스홀더(추후 TextField로 교체)
class _RoundedFieldPlaceholder extends StatelessWidget {
  final String hint;
  final double minHeight;
  final bool alignTop;

  const _RoundedFieldPlaceholder({
    Key? key,
    required this.hint,
    this.minHeight = 44,
    this.alignTop = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.fromLTRB(14, alignTop ? 12 : 0, 14, 0),
      alignment: alignTop ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        hint,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
    );
  }
}
