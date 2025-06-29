import 'package:flutter/material.dart';
import 'dart:math';
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

  // チャット履歴
  List<ChatMessage> _groupMessages = [];
  Map<String, List<ChatMessage>> _privateMessages = {};

  // ユーザー管理
  late String _userId;
  Map<String, dynamic>? _userInfo;

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
  }

  void _initializeUser() {
    final random = Random();
    _userId = 'user_${random.nextInt(1000000)}';
    _loadUserInfo();
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
      });
    }
  }

  Future<void> _handleGroupChat(String text) async {
    final allCharacters = ['剣士', '魔女', 'ゴリラ', '商人', '冒険家', '神', 'カス大学生'];
    allCharacters.shuffle();
    final numResponders = 2 + Random().nextInt(2); // 2〜3人
    final selected = allCharacters.take(numResponders).toList();
    for (int i = 0; i < selected.length; i++) {
      final character = selected[i];
      setState(() {
        _isLoading = true;
      });
      try {
        final lengthPrompt = [
          '短めに返答してください。必ず全体で30字以内で完結してください。',
          '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
          '短めに返答してください。必ず全体で30字以内で完結してください。',
          '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
          '短めに返答してください。必ず全体で30字以内で完結してください。',
          '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
          '長めに詳しく返答してください。必ず全体で100字以内で完結してください。',
        ][Random().nextInt(7)];
        String userMessage = text + '\n' + lengthPrompt;
        if (i == selected.length - 1) {
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
        });
        _scrollToBottom();
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        print('$characterの返答でエラー: $e');
      }
    }
    setState(() {
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _handlePrivateChat(String text, String character) async {
    _privateMessages[character] ??= [];
    try {
      final lengthPrompt = [
        '短めに返答してください。必ず全体で30字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
        '短めに返答してください。必ず全体で30字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
        '短めに返答してください。必ず全体で30字以内で完結してください。',
        '普通の長さで返答してください。必ず全体で50字以内で完結してください。',
        '長めに詳しく返答してください。必ず全体で100字以内で完結してください。',
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
        ? CircleAvatar(child: Text('君'))
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

  Widget _buildUsageInfo() {
    if (_userInfo == null) return SizedBox.shrink();
    final dailyCount = _userInfo!['dailyCount'] ?? 0;
    final dailyLimit = _userInfo!['dailyLimit'] ?? 30;
    final isPremium = _userInfo!['isPremium'] ?? false;
    final remaining = dailyLimit - dailyCount;
    final totalUsage = _userInfo!['totalUsage'] ?? 0;
    Color statusColor;
    IconData statusIcon;
    if (remaining <= 0) {
      statusColor = Colors.red;
      statusIcon = Icons.block;
    } else if (remaining <= 5) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (remaining <= 10) {
      statusColor = Colors.yellow.shade700;
      statusIcon = Icons.info;
    } else {
      statusColor = isPremium ? Colors.amber : Colors.green;
      statusIcon = isPremium ? Icons.star : Icons.check_circle;
    }
    return Container(
      padding: EdgeInsets.all(12),
      color: statusColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPremium ? 'プレミアムプラン' : '無料プラン',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              if (!isPremium && remaining <= 5)
                TextButton(
                  onPressed: _showUpgradeDialog,
                  child: Text(
                    'アップグレード',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '今日の利用回数: $dailyCount/$dailyLimit (残り$remaining回)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '総利用回数: $totalUsage回',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          if (remaining <= 5 && remaining > 0)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                remaining <= 3
                    ? '⚠️ 残り回数が少なくなっています。プレミアムプランへのアップグレードをご検討ください。'
                    : '残り回数が少なくなっています。',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hachico Chat'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _chatTabs.map((tab) {
            final isGroup = tab == 'Hachico';
            return Tab(
              child: Row(
                children: [
                  if (!isGroup && characterAvatars[tab] != null)
                    CircleAvatar(
                      backgroundImage: AssetImage(characterAvatars[tab]!),
                      radius: 12,
                    ),
                  if (!isGroup) SizedBox(width: 4),
                  Text(tab),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildUsageInfo(),
            Expanded(child: _buildMessageList()),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'AIが送信中…',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
