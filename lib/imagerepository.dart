import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // 1. 이미지 선택 후 Python 서버로 전송, 배경 제거 처리 후 저장
  // 1. 이미지 선택 후 Python 서버로 전송, 배경 제거 처리 후 저장
  Future<Map<String, String>?> uploadImage(String userId, ImageSource source) async {
    final String dateTime = DateTime.now().millisecondsSinceEpoch.toString();
    XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      // Python 서버로 이미지를 전송하여 배경 제거된 이미지 URL들을 받음
      List<String>? processedImageUrls = await _sendImageToPython(image);

      // 처리된 이미지 URL이 null이 아니면 첫 번째 이미지로 Firebase에 저장
      if (processedImageUrls != null && processedImageUrls.isNotEmpty) {
        String firstProcessedImageUrl = processedImageUrls.first;

        // Python 서버에서 받은 URL의 이미지를 다운로드하여 로컬 파일로 변환
        File? downloadedFile = await _downloadImageToLocal(firstProcessedImageUrl);

        if (downloadedFile != null && downloadedFile.existsSync()) {
          String imageRef = "images/${userId}_$dateTime";

          // Firebase Storage에 처리된 이미지 업로드
          await _storage.ref(imageRef).putFile(downloadedFile);
          String imageUrl = await _storage.ref(imageRef).getDownloadURL();

          // Firebase에 저장된 이미지 정보 반환
          return {
            "image": imageUrl,
            "path": imageRef,
          };
        } else {
          print('Error: Processed file could not be downloaded');
          return null;
        }
      } else {
        print('Error: processedImageUrls is null or empty');
      }
    }
    return null;
  }

  // URL에서 이미지를 다운로드하여 로컬 파일로 저장하는 함수
  Future<File?> _downloadImageToLocal(String imageUrl) async {
    try {
      // 이미지 URL을 HTTP로 다운로드
      final http.Response response = await http.get(Uri.parse(imageUrl));

      // 이미지가 정상적으로 다운로드되었는지 확인
      if (response.statusCode == 200) {
        // 임시 디렉토리에 이미지 저장
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File file = File(tempPath);

        // 파일에 이미지 데이터를 기록
        await file.writeAsBytes(response.bodyBytes);

        return file; // 로컬 파일 반환
      } else {
        print('Failed to download image from URL');
        return null;
      }
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  // Python 서버로 이미지 전송하여 URL을 받아오는 함수
  // Python 서버로 이미지 전송하여 URL을 받아오는 함수
  Future<List<String>?> _sendImageToPython(XFile image) async {
    String url = 'http://54.180.224.157:5000/process-image'; // Python 서버의 URL

    try {
      // 이미지 파일을 Multipart로 전송
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var jsonResponse = jsonDecode(responseData.body);

        // processed_image_url이 리스트일 경우 처리
        if (jsonResponse['processed_image_urls'] is List) {
          List<dynamic> urlList = jsonResponse['processed_image_urls'];
          List<String> processedImageUrls = urlList.map((url) => url.toString()).toList();
          return processedImageUrls;
        } else if (jsonResponse['processed_image_url'] is String) {
          return [jsonResponse['processed_image_url']]; // 단일 URL을 리스트로 반환
        } else {
          print('Error: processed_image_url is neither List nor String');
          return null;
        }
      } else {
        print('Python 서버에서 이미지 처리 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception occurred while sending image to Python server: $e');
      return null;
    }
  }




  Future<void> saveImageInfo({
    required String userId,
    required String docId,
    required String imageUrl,
    required String path,
    required String category,
    required List<String> weather,
    String? subCategory,
    String? sleeve,
    String? color,
    String? subColor,
    String? shirtSleeve,
    List<String>? detail,
    String? collar,
    List<String>? material,
    List<String>? print,
    String? neckLine,
    String? fit,
  }) async {
    await _firestore.collection("images").doc(docId).set({
      "userId": userId,
      "docId": docId,
      "image": imageUrl,
      "path": path,
      "dateTime": Timestamp.now(),
      "category": category,
      "weather": weather,
      "color": color,
      "subCategory": subCategory,
      "sleeve": sleeve,
      "subColor": subColor,
      "shirtSleeve": shirtSleeve,
      "detail": detail,
      "collar": collar,
      "material": material,
      "print": print,
      "neckLine": neckLine,
      "fit": fit,
    });
  }

  Future<void> deleteImage(String docId, String path) async {
    await _storage.ref(path).delete();
    await _firestore.collection("images").doc(docId).delete();
  }

  Future<List<Map<String, dynamic>>> getImages(String userId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection("images")
        .where("userId", isEqualTo: userId)  // 사용자 ID로 필터링
        .orderBy("dateTime", descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

}