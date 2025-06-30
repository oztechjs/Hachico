import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_service.dart';
import 'hachico_api.dart';
import 'settings_screen.dart';

void main() {
  runApp(HachicoApp());
}

class HachicoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hachico Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _chatTabs = [
    'Hachico',
    '剣士',
    '魔女',
    'ゴリラ',
    '商人',
    '冒険家',
    '神',
    'カス大学生',
  ];
  late TabController _tabController;

  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  Set<String> _respondingCharacters = {}; // 返答中のキャラクターを追跡

  // チャット履歴
  List<ChatMessage> _groupMessages = [];
  Map<String, List<ChatMessage>> _privateMessages = {};

  // ユーザー管理
  late String _userId;
  Map<String, dynamic>? _userInfo;
  File? _userIconFile; // ユーザーアイコンファイル

  final Map<String, Color> characterColors = {
    '魔女': Colors.purple,
    'ゴリラ': Colors.brown,
    '冒険家': Colors.green,
    '科学者': Colors.blue,
    '芸術家': Colors.pink,
  };
  final Map<String, String> characterAvatars = {
    '剣士': 'assets/character_swordman.png',
    '魔女': 'assets/character_wizard.png',
    'ゴリラ': 'assets/character_gorilla.png',
    '商人': 'assets/character_merchant.png',
    '冒険家': 'assets/character_adventurer.png',
    '神': 'assets/character_god.png',
    'カス大学生': 'assets/character_takuji.png',
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _chatTabs.length, vsync: this);
    _initializeUser();
    _loadUserIcon();
  }

  void _initializeUser() {
    final random = Random();
    _userId = 'user_${random.nextInt(1000000)}';
    _loadUserInfo();
  }

  Future<void> _loadUserIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('user_icon_path');
      if (path != null && File(path).existsSync()) {
        setState(() {
          _userIconFile = File(path);
        });
      }
    } catch (e) {
      print('Failed to load user icon: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await getUserInfo(_userId);
      setState(() {
        _userInfo = userInfo;
      });
    } catch (e) {
      print('Failed to load user info: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    final currentTab = _chatTabs[_tabController.index];
    setState(() {
      if (currentTab == 'Hachico') {
        _groupMessages.add(
          ChatMessage(sender: 'あなた', message: text, isUser: true),
        );
      } else {
        _privateMessages[currentTab] ??= [];
        _privateMessages[currentTab]!.add(
          ChatMessage(sender: 'あなた', message: text, isUser: true),
        );
      }
      _isLoading = true;
      _respondingCharacters.clear(); // 返答中のキャラクターをリセット
    });
    _controller.clear();
    try {
      if (currentTab == 'Hachico') {
        await _handleGroupChat(text);
      } else {
        await _handlePrivateChat(text, currentTab);
      }
      await _loadUserInfo();
    } catch (e) {
      // エラーはチャット履歴に追加せずprintのみ
      print('エラーが発生しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _respondingCharacters.clear(); // エラー時もリセット
      });
    }
  }

  Future<void> _handleGroupChat(String text) async {
    final allCharacters = ['剣士', '魔女', 'ゴリラ', '商人', '冒険家', '神', 'カス大学生'];
    allCharacters.shuffle();
    final numResponders = 2 + Random().nextInt(2); // 2〜3人
    final selected = allCharacters.take(numResponders).toList();

    // 順次処理で各キャラクターが前のキャラクターの発言を反映
    for (int i = 0; i < selected.length; i++) {
      final character = selected[i];
      await _handleCharacterResponse(text, character, i, selected.length);

      // 各キャラクターの返答間に少し間隔を設ける
      await Future.delayed(Duration(milliseconds: 500));
    }

    setState(() {
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _handleCharacterResponse(
    String text,
    String character,
    int index,
    int total,
  ) async {
    // 返答開始を記録
    setState(() {
      _respondingCharacters.add(character);
    });

    try {
      final lengthPrompt = [
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '長めに詳しく返答してください。必ず全体で60字以内で完結してください。',
      ][Random().nextInt(7)];

      String userMessage = '';
      // 直前の他キャラの発言を含める
      if (index > 0) {
        // 直前のキャラ
        final prevChar = _groupMessages.isNotEmpty
            ? _groupMessages.last.sender
            : null;
        final prevMsg = _groupMessages.isNotEmpty
            ? _groupMessages.last.message
            : null;
        if (prevChar != null && prevMsg != null) {
          userMessage += '直前の他キャラの発言: $prevChar: $prevMsg\n';
          userMessage +=
              'この発言に必ずリアクション（同意・反論・補足・質問返しなど）を入れてから、ユーザーの質問にも答えてください。\n';
        }
      }
      userMessage += text + '\n' + lengthPrompt;
      if (index == total - 1) {
        userMessage += '\n\nあなたの返答の最後に、ユーザーに自然な形で新たな質問を投げかけてください。';
      }

      final response = await ChatService.sendGroupMessage(
        userMessage,
        character,
        _groupMessages,
        userId: _userId,
      );

      setState(() {
        _groupMessages.add(ChatMessage(sender: character, message: response));
        _respondingCharacters.remove(character); // 返答完了
      });
      _scrollToBottom();

      // 各キャラクターの返答間に少し間隔を設ける
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('$characterの返答でエラー: $e');
      setState(() {
        _respondingCharacters.remove(character); // エラー時も返答完了として記録
      });
    }
  }

  Future<void> _handlePrivateChat(String text, String character) async {
    _privateMessages[character] ??= [];
    try {
      final lengthPrompt = [
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '短めに返答してください。必ず全体で20字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で35字以内で完結してください。',
        '長めに詳しく返答してください。必ず全体で60字以内で完結してください。',
      ][Random().nextInt(7)];
      final userMessage = text + '\n' + lengthPrompt;
      final response = await ChatService.sendMessage(
        userMessage,
        character,
        userId: _userId,
      );
      setState(() {
        _privateMessages[character]!.add(
          ChatMessage(sender: character, message: response),
        );
      });
      _scrollToBottom();
    } catch (e) {
      print('エラー: $e');
    }
  }

  String normalizeCharacterName(String name) {
    return name.split('（').first.trim();
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.isUser;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bgColor = isUser
        ? Colors.blueAccent
        : characterColors[msg.sender] ?? Colors.grey.shade300;
    final textColor = isUser ? Colors.white : Colors.black87;
    final normalizedSender = normalizeCharacterName(msg.sender);
    final avatar = isUser
        ? CircleAvatar(
            backgroundImage: _userIconFile != null
                ? FileImage(_userIconFile!)
                : null,
            child: _userIconFile == null ? Text('君') : null,
            radius: 20,
          )
        : (characterAvatars.containsKey(normalizedSender)
              ? CircleAvatar(
                  backgroundImage: AssetImage(
                    characterAvatars[normalizedSender]!,
                  ),
                  radius: 20,
                )
              : CircleAvatar(
                  child: Text(normalizedSender.substring(0, 1)),
                  radius: 20,
                ));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: alignment,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) avatar,
          SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Text(
                      msg.sender,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  Text(msg.message, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          if (isUser) avatar,
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final currentTab = _chatTabs[_tabController.index];
    final messages = currentTab == 'Hachico'
        ? _groupMessages
        : (_privateMessages[currentTab] ?? []);
    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessage(messages[index]),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('プレミアムプラン'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'プレミアムプランにアップグレードすると：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildFeatureItem(Icons.all_inclusive, '1日あたり150回まで利用可能（無料の5倍）'),
            _buildFeatureItem(Icons.priority_high, '優先サポート'),
            _buildFeatureItem(Icons.new_releases, '新機能の先行利用'),
            _buildFeatureItem(Icons.speed, '高速レスポンス'),
            _buildFeatureItem(Icons.psychology, 'より詳細な回答'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber.shade700),
                  SizedBox(width: 8),
                  Text(
                    '料金: 月額800円',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '※ いつでもキャンセル可能です',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              _showUpgradeLoadingDialog();
              try {
                await upgradeToPremium(_userId);
                await _loadUserInfo();
              } catch (e) {
                print('❌ アップグレードに失敗しました: $e');
              }
            },
            icon: Icon(Icons.star),
            label: Text('アップグレード'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showUpgradeLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('アップグレード処理中...'),
          ],
        ),
      ),
    );
  }

  void _showFreePlanDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('無料プラン詳細'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在の利用状況：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildDetailItem(Icons.calendar_today, '1日あたり30回まで利用可能'),
            _buildDetailItem(Icons.refresh, '毎日午前0時にリセット'),
            _buildDetailItem(Icons.check_circle, '基本的な機能は全て利用可能'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'プレミアムプランにアップグレードすると：',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildFeatureItem(
                    Icons.all_inclusive,
                    '1日あたり150回まで利用可能（無料の5倍）',
                  ),
                  _buildFeatureItem(Icons.priority_high, '優先サポート'),
                  _buildFeatureItem(Icons.new_releases, '新機能の先行利用'),
                  _buildFeatureItem(Icons.speed, '高速レスポンス'),
                  _buildFeatureItem(Icons.psychology, 'より詳細な回答'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showUpgradeDialog();
            },
            icon: Icon(Icons.star),
            label: Text('アップグレード'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _userInfo?['isPremium'] == true
                  ? Colors.amber
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _userInfo?['isPremium'] == true ? 'プレミアム' : '無料版',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text('Hachico Chat'),
        ],
      ),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      actions: [
        if (_userInfo?['isPremium'] == true)
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showPremiumDetails,
          )
        else
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showFreePlanDetails,
          ),
        if (_userInfo?['isPremium'] != true)
          IconButton(icon: Icon(Icons.star), onPressed: _showUpgradeDialog),
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsScreen()),
            );
            // 設定画面から戻ってきた時にユーザーアイコンを再読み込み
            _loadUserIcon();
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: _chatTabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  void _showPremiumDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('プレミアムプラン'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プレミアムプランの特典：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildFeatureItem(Icons.all_inclusive, '1日あたり150回まで利用可能'),
            _buildFeatureItem(Icons.priority_high, '優先サポート'),
            _buildFeatureItem(Icons.new_releases, '新機能の先行利用'),
            _buildFeatureItem(Icons.speed, '高速レスポンス'),
            _buildFeatureItem(Icons.psychology, 'より詳細な回答'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'プレミアムプラン利用中',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_isLoading || _respondingCharacters.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (_respondingCharacters.isNotEmpty)
                      ..._respondingCharacters
                          .map(
                            (character) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (characterAvatars.containsKey(character))
                                    CircleAvatar(
                                      backgroundImage: AssetImage(
                                        characterAvatars[character]!,
                                      ),
                                      radius: 12,
                                    ),
                                  SizedBox(width: 8),
                                  Text(
                                    '$characterが返答中…',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    if (_isLoading && _respondingCharacters.isEmpty)
                      Text(
                        'AIが送信中…',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            Divider(height: 1),
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(hintText: 'メッセージを入力してください'),
                        onSubmitted: (_) => _handleSend(),
                        enabled: !_isLoading,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: _isLoading ? null : _handleSend,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
