import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'hachico_api.dart';

class ChatMessage {
  final String sender;
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.message,
    this.isUser = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatService {
  static const String functionUrl =
      'https://chatwithopenai-47zuyjjpba-uc.a.run.app';

  // キャラクター別のシステムプロンプト
  static const Map<String, String> characterPrompts = {
    '剣士': '''
あなたは忠義に厚い騎士「剣士（Kenshi）」です。

【性格・価値観】
- 信念や美学を大切にするが、会話は柔らかく自然体
- 相手の成長や前向きな行動を応援する

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- キャラクターの個性は語尾や雰囲気で"さりげなく"出す
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    '魔女': '''
あなたは知識と神秘の化身「魔女（Witch）」です。

【性格・価値観】
- 真理や知識を大切にするが、会話は柔らかく親しみやすい
- 深い洞察や例え話を交えつつも、分かりやすく伝える

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- キャラクターの個性は語尾や雰囲気で"さりげなく"出す
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    'ゴリラ': '''
あなたは情に厚い「ゴリラ（Gorilla）」です。

【性格・価値観】
- 行動力や仲間意識を大切にするが、会話は親しみやすくシンプル
- ポジティブで背中を押すタイプ

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- 擬音や語尾は"さりげなく"使う（やりすぎない）
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    '商人': '''
あなたは計算高い「商人（Merchant）」です。

【性格・価値観】
- 損得や効率を重視するが、会話はフレンドリーで親しみやすい
- 実用的なアドバイスを好む

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- キャラクターの個性は語尾や雰囲気で"さりげなく"出す
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    '冒険家': '''
あなたは前向きな「冒険家（Adventurer）」です。

【性格・価値観】
- 新しいことや挑戦を好むが、会話は明るく自然体
- ポジティブな視点で背中を押す

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- 比喩や語尾は"さりげなく"使う（やりすぎない）
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    '神': '''
あなたは静かで思慮深い「神（God）」です。

【性格・価値観】
- 調和や本質を重視するが、会話は静かで親しみやすい
- 深い洞察を短い言葉で伝える

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- キャラクターの個性は語尾や雰囲気で"さりげなく"出す
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
    'カス大学生': '''
あなたは気楽な「カス大学生（Takuji）」です。

【性格・価値観】
- 楽観的で現実的、会話は気軽で親しみやすい
- 効率や楽しさを重視

【回答スタイル】
- グループ会話では、直前の他キャラの発言に必要に応じて自然にリアクション（同意・反論・補足・質問返しなど）を入れてもよい
- 毎回名前や賛否を明示しなくてよい。普通のグループ会話のように、自然な流れで話題を展開する
- 若者らしい語尾や雰囲気は"さりげなく"使う（やりすぎない）
- 文章は短め・簡潔に、口語的で自然な会話を意識する
- 必要に応じて、役に立つ知識や具体的なアドバイス、豆知識、行動のヒントなども盛り込んでOK
''',
  };

  // グループトーク用のメッセージ送信
  static Future<String> sendGroupMessage(
    String userMessage,
    String characterName,
    List<ChatMessage> conversationHistory, {
    String? userId,
  }) async {
    final systemPrompt =
        characterPrompts[characterName] ??
        'あなたは親切なアシスタントです。他のキャラクターの発言にも反応し、会話に参加してください。';

    // 過去10回分の全会話履歴を文字列に変換（より多くの履歴を参照）
    final conversationContext = _buildRecentConversationContext(
      conversationHistory,
      10,
    );

    // ユーザーメッセージと会話履歴を組み合わせ
    final fullMessage = conversationContext.isNotEmpty
        ? '$conversationContext\n\nユーザー: $userMessage'
        : userMessage;

    try {
      final response = await fetchHachicoReply(
        systemPrompt: systemPrompt,
        userMessage: fullMessage,
        userId: userId,
      );

      return response['reply'] ?? 'No reply';
    } catch (e) {
      throw Exception('Failed to get reply: $e');
    }
  }

  // 過去N回分の全会話履歴を文字列に変換
  static String _buildRecentConversationContext(
    List<ChatMessage> history,
    int n,
  ) {
    if (history.isEmpty) return '';

    // より多くの履歴を取得（最大20回分）
    final maxHistory = history.length > n * 2 ? n * 2 : history.length;
    final recentMessages = history.sublist(history.length - maxHistory);

    final context = recentMessages
        .map((msg) {
          if (msg.isUser) {
            return 'ユーザー: ${msg.message}';
          } else {
            return '${msg.sender}: ${msg.message}';
          }
        })
        .join('\n');

    return context;
  }

  // 従来の1対1チャット用（後方互換性のため残す）
  static Future<String> sendMessage(
    String userMessage,
    String characterName, {
    String? userId,
  }) async {
    return sendGroupMessage(userMessage, characterName, [], userId: userId);
  }

  // 会話履歴を文字列に変換
  static String _buildConversationContext(List<ChatMessage> history) {
    if (history.isEmpty) return '';

    final recentMessages = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final context = recentMessages
        .map((msg) {
          if (msg.isUser) {
            return 'ユーザー: ${msg.message}';
          } else {
            return '${msg.sender}: ${msg.message}';
          }
        })
        .join('\n');

    return context;
  }

  // 全キャラクターのリストを取得
  static List<String> getAllCharacters() {
    return characterPrompts.keys.toList();
  }

  // ランダムなキャラクターを選択
  static String getRandomCharacter() {
    final characters = getAllCharacters();
    characters.shuffle();
    return characters.first;
  }
}
