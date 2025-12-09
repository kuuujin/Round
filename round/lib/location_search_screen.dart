import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 데이터 모델
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
  // Controllers & State
  final _searchController = TextEditingController();
  List<LocationData> _allLocations = [];
  List<LocationData> _filteredLocations = [];

  // Palette
  static const Color _bg = Color(0xFF262626);
  static const Color _panel = Color(0xFF2F2F2F);
  static const Color _hint = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. JSON 데이터 로드 및 파싱
  Future<void> _loadLocations() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/locations.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> dataList = jsonData['data'];

      final List<LocationData> tempList = [];

      for (var sidoEntry in dataList) {
        final Map<String, dynamic> sidoMap = sidoEntry as Map<String, dynamic>;
        final String sido = sidoMap.keys.first;
        final List<dynamic> sigunguList = sidoMap[sido];

        if (sigunguList.isEmpty) {
          // 예: '세종특별자치시' (하위 행정구역 없음)
          tempList.add(LocationData(sido: sido, sigungu: ''));
        } else {
          // 일반적인 시/도 -> 시/군/구 구조
          for (var sigungu in sigunguList) {
            tempList.add(LocationData(sido: sido, sigungu: sigungu as String));
          }
        }
      }

      if (mounted) {
        setState(() {
          _allLocations = tempList;
          _filteredLocations = tempList; // 초기엔 전체 목록 표시 (또는 빈 목록 선택 가능)
        });
      }
    } catch (e) {
      debugPrint("❌ Location load error: $e");
    }
  }

  // 2. 검색어 필터링
  void _filterLocations(String query) {
    if (query.isEmpty) {
      // 검색어가 없으면 전체 목록 표시 (또는 빈 목록)
      setState(() => _filteredLocations = _allLocations);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = _allLocations.where((loc) {
      return loc.sigungu.toLowerCase().contains(lowerQuery) ||
             loc.sido.toLowerCase().contains(lowerQuery);
    }).toList();

    setState(() {
      _filteredLocations = results;
    });
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('모임 지역 선택', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildLocationList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _filterLocations,
        autofocus: true, // 화면 진입 시 키보드 올림
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '시/도 또는 시/군/구를 입력해주세요.',
          hintStyle: const TextStyle(color: _hint),
          filled: true,
          fillColor: _panel,
          prefixIcon: const Icon(Icons.search, color: _hint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: _hint),
                  onPressed: () {
                    _searchController.clear();
                    _filterLocations('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLocationList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _filteredLocations.length,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // 스크롤 시 키보드 내림
        itemBuilder: (context, index) {
          final location = _filteredLocations[index];
          final bool isSidoOnly = location.sigungu.isEmpty;

          return ListTile(
            title: Text(
              isSidoOnly ? location.sido : location.sigungu,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: isSidoOnly 
                ? null // subtitle이 없으면 title이 중앙 정렬됨
                : Text(location.sido, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            onTap: () {
              // 선택된 지역 정보 반환
              Navigator.pop(context, location);
            },
          );
        },
      ),
    );
  }
}