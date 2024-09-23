import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../provider/userprovider.dart';

class RecommendationScreen extends StatefulWidget {
  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  String? selectedCategory;
  String? selectedSeason;
  bool _isLoading = false;

  List<String> docIds = [];

  String? topImageUrl;
  String? bottomImageUrl;
  String? outerImageUrl;
  String? dressImageUrl;

  final Map<String, List<String>> styleCategories = {
    "클래식": ["클래식", "프레피"],
    "매니시": ["매니시", "톰보이"],
    "엘레강스": ["엘레강스", "소피스케이티드", "글래머러스"],
    "에스닉": ["에스닉", "히피", "오리엔탈"],
    "모던": ["모던", "미니멀"],
    "내추럴": ["내추럴", "컨트리", "리조트"],
    "로맨틱": ["로맨틱", "섹시"],
    "스포티": ["스포티", "애슬레져", "밀리터리"],
    "문화": ["뉴트로", "힙합", "키티/키덜트", "맥시멈", "펑크/로커"],
    "캐주얼": ["캐주얼", "놈코어"]
  };

  final List<String> seasons = ["봄", "여름", "가을", "겨울"];
  late String userId;
  void initState() {
    super.initState();
    // Provider에서 userId 가져오기
    userId = Provider.of<UserProvider>(context, listen: false).userId;

    // 데이터를 가져오는 함수 호출
  }
  Future<void> _sendDataToPythonServer() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 선택한 StyleCategories와 Seasons 데이터를 준비
      Map<String, dynamic> data = {
        'userId': userId,
        'styleCategory': selectedCategory,
        'season': selectedSeason
      };

      // Python 서버 URL (실제 서버 IP로 변경 필요)
      String url = 'http://54.180.224.157:5000/get-doc-ids';

      // POST 요청으로 Python 서버에 데이터 전송
      var response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      // 서버로부터 받은 데이터를 처리
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        List<String> fetchedDocIds = List<String>.from(jsonResponse['docIds']);
        setState(() {
          docIds = fetchedDocIds;
        });
        await _fetchOutfitImages();  // Firebase에서 이미지 가져오기
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data to Python server: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOutfitImages() async {
    try {
      for (String docId in docIds) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('images')
            .doc(docId)
            .get();

        if (doc.exists) {
          String imageUrl = doc['image'];
          String category = doc['category'];

          if (category == '상의') {
            topImageUrl = imageUrl;
          } else if (category == '하의') {
            bottomImageUrl = imageUrl;
          } else if (category == '아우터') {
            outerImageUrl = imageUrl;
          } else if (category == '원피스') {
            dressImageUrl = imageUrl;
          }
        }
      }
    } catch (e) {
      print('Error fetching images: $e');
    }
  }

  Widget _buildOutfitDisplay() {
    return Center(
      child: Stack(
        children: [
          // 아우터가 가장 뒤에 나타남
          if (outerImageUrl != null)
            Positioned(
              top: 15, // 아우터를 더 위로 이동
              left: 20, // 살짝 왼쪽으로 이동
              child: SizedBox(
                height: 180,
                child: Image.network(
                  outerImageUrl!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // 상의가 아우터 위에 나타남
          if (topImageUrl != null)
            Positioned(
              top: 55, // 상의를 살짝 위로 올림
              left: 100, // 중앙에서 좀 더 오른쪽으로 이동
              child: SizedBox(
                height: 160,
                child: Image.network(
                  topImageUrl!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // 하의는 상의보다 위로 올라가고 오른쪽으로 이동
          if (bottomImageUrl != null)
            Positioned(
              top: 130, // 하의를 좀 더 위로 이동
              left: 170, // 오른쪽으로 이동
              child: SizedBox(
                height: 150,
                child: Image.network(
                  bottomImageUrl!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          // 원피스가 있으면 상의, 하의 대신 원피스만 나타남
          if (dressImageUrl != null)
            Positioned(
              top: 50,
              left: 100, // 중앙에 배치
              child: SizedBox(
                height: 220,
                child: Image.network(
                  dressImageUrl!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildSeasonButton(String season) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedSeason = season;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: selectedSeason == season ? Colors.blueAccent : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 3,
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              season,
              style: TextStyle(
                color: selectedSeason == season ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI 코디 생성기',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI가 추천하는 코디를 받아보세요!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 3,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: selectedCategory,
                hint: Text('카테고리 선택'),
                isExpanded: true,
                underline: SizedBox(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCategory = newValue;
                  });
                },
                items: styleCategories.keys.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: seasons.map((season) => _buildSeasonButton(season)).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendDataToPythonServer,
              child: Text(
                'AI 코디 생성하기!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                minimumSize: Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                elevation: 5,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Center(
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Container(
                  width: double.infinity,
                  height: 500,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Center(
                    child: _buildOutfitDisplay(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
