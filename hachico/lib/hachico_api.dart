import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> fetchHachicoReply({
  required String systemPrompt,
  required String userMessage,
  String? userId,
}) async {
  final url = Uri.parse('https://chatwithopenai-47zuyjjpba-uc.a.run.app');

  try {
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemPrompt': systemPrompt,
            'userMessage': userMessage,
            if (userId != null) 'userId': userId,
          }),
        )
        .timeout(Duration(seconds: 30)); // 30秒タイムアウト

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse;
    } else if (response.statusCode == 429) {
      // 利用制限エラー
      final errorResponse = jsonDecode(response.body);
      throw Exception(
        errorResponse['message'] ?? '本日の利用制限に達しました。プレミアムプランへのアップグレードをご検討ください。',
      );
    } else if (response.statusCode == 500) {
      // サーバーエラー
      throw Exception('サーバーでエラーが発生しました。しばらく時間をおいてから再度お試しください。');
    } else if (response.statusCode == 503) {
      // サービス利用不可
      throw Exception('サービスが一時的に利用できません。しばらく時間をおいてから再度お試しください。');
    } else {
      print('Error: ${response.statusCode} ${response.body}');
      throw Exception('通信エラーが発生しました。インターネット接続をご確認ください。');
    }
  } catch (e) {
    if (e.toString().contains('TimeoutException')) {
      throw Exception('応答がタイムアウトしました。しばらく時間をおいてから再度お試しください。');
    } else if (e.toString().contains('SocketException')) {
      throw Exception('インターネット接続を確認してください。');
    }
    rethrow;
  }
}

// ユーザー情報取得
Future<Map<String, dynamic>> getUserInfo(String userId) async {
  final url = Uri.parse(
    'https://getuserinfo-47zuyjjpba-uc.a.run.app?userId=$userId',
  );

  try {
    final response = await http.get(url).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      throw Exception('ユーザー情報の取得に失敗しました。');
    } else if (response.statusCode == 500) {
      throw Exception('サーバーでエラーが発生しました。しばらく時間をおいてから再度お試しください。');
    } else {
      throw Exception('ユーザー情報の取得に失敗しました。');
    }
  } catch (e) {
    if (e.toString().contains('TimeoutException')) {
      throw Exception('ユーザー情報の取得がタイムアウトしました。');
    } else if (e.toString().contains('SocketException')) {
      throw Exception('インターネット接続を確認してください。');
    }
    rethrow;
  }
}

// プレミアムアップグレード
Future<Map<String, dynamic>> upgradeToPremium(String userId) async {
  final url = Uri.parse('https://upgradetopremium-47zuyjjpba-uc.a.run.app');

  try {
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId}),
        )
        .timeout(Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      throw Exception('アップグレードに必要な情報が不足しています。');
    } else if (response.statusCode == 500) {
      throw Exception('アップグレード処理中にエラーが発生しました。しばらく時間をおいてから再度お試しください。');
    } else {
      throw Exception('アップグレードに失敗しました。');
    }
  } catch (e) {
    if (e.toString().contains('TimeoutException')) {
      throw Exception('アップグレード処理がタイムアウトしました。');
    } else if (e.toString().contains('SocketException')) {
      throw Exception('インターネット接続を確認してください。');
    }
    rethrow;
  }
}
