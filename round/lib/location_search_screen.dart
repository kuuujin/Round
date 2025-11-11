import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 1. (수정) 반환 모델에서 dong 제거
class LocationData {
  final String sido;
  final String sigungu;

  LocationData({required this.sido, required this.sigungu});
}

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _searchController = TextEditingController();
  List<LocationData> _allLocations = [];
  List<LocationData> _filteredLocations = [];

  // 팔레트
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _hint = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  // 2. (수정) 새로운 JSON 구조에 맞게 파싱 로직 변경
  Future<void> _loadLocations() async {
    try{
    final String jsonString = await rootBundle.loadString('assets/data/locations.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    final List<LocationData> tempList = [];
    final List<dynamic> dataList = jsonData['data'];

    // JSON 리스트를 순회
    for (var sidoEntry in dataList) {
      final Map<String, dynamic> sidoMap = sidoEntry as Map<String, dynamic>;
      final String sido = sidoMap.keys.first;
      final List<dynamic> sigunguList = sidoMap[sido];

      if (sigunguList.isEmpty) {
        // '세종특별자치시'처럼 시/군/구가 없는 경우
        tempList.add(LocationData(sido: sido, sigungu: ''));
      } else {
        // 시/군/구 목록을 순회
        for (var sigungu in sigunguList) {
          tempList.add(LocationData(sido: sido, sigungu: sigungu as String));
        }
      }
    }

    setState(() {
      _allLocations = tempList;
    });
    print("✅ Location data loaded successfully. Total count: ${_allLocations.length}");
    }
    catch (e) {
      // 👇👇👇 에러 발생 시 콘솔에 출력 👇👇👇
      print("❌ ERROR loading locations.json: $e");
    }
  }

  // 3. (수정) '시/군/구' 또는 '시/도'로 검색하도록 로직 변경
  void _filterLocations(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLocations = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = _allLocations.where((loc) {
      // 시/군/구 또는 시/도 이름에 검색어가 포함되는지 확인
      return loc.sigungu.toLowerCase().contains(lowerQuery) ||
             loc.sido.toLowerCase().contains(lowerQuery);
    }).toList();

    setState(() {
      _filteredLocations = results;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('모임 지역', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLocations,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                // 4. (수정) 힌트 텍스트 변경
                hintText: '시/도 또는 시/군/구를 입력해주세요.',
                hintStyle: const TextStyle(color: _hint),
                filled: true,
                fillColor: _panel,
                prefixIcon: const Icon(Icons.search, color: _hint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: _hint),
                  onPressed: () {
                    _searchController.clear();
                    _filterLocations('');
                  },
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLocations.length,
              itemBuilder: (context, index) {
                final location = _filteredLocations[index];
                
                // 5. (수정) ListTile 표시 로직 변경
                final bool isSidoOnly = location.sigungu.isEmpty;
                
                return ListTile(
                  title: Text(
                    isSidoOnly ? location.sido : location.sigungu, // 시/군/구가 없으면 시/도 이름을 메인으로
                    style: const TextStyle(color: Colors.white)
                  ),
                  subtitle: Text(
                    isSidoOnly ? '' : location.sido, // 시/군/구가 없으면 서브타이틀 비움
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    // 6. (수정) 'dong'이 빠진 LocationData 반환
                    Navigator.pop(context, location);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}