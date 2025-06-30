import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  File? _userIconFile;

  @override
  void initState() {
    super.initState();
    _loadUserIcon();
  }

  Future<void> _loadUserIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('user_icon_path');
    if (path != null && File(path).existsSync()) {
      setState(() {
        _userIconFile = File(path);
      });
    }
  }

  Future<void> _pickUserIcon() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_icon_path', picked.path);
      setState(() {
        _userIconFile = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('設定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(height: 20),
            _buildFeatureCard(context, 'グループトーク機能', Icons.group, [
              '• 複数のAIキャラクターと同時に会話できます',
              '• 各キャラクターが他の発言を考慮して返答します',
              '• 1対1チャットとグループトークを切り替え可能',
              '• 参加キャラクターを自由に選択可能',
            ]),
            SizedBox(height: 16),
            _buildCharacterCard(context),
            SizedBox(height: 16),
            _buildUsageCard(context),
            SizedBox(height: 16),
            _buildHowToUseCard(context),
            SizedBox(height: 16),
            _buildServiceCard(context),
            SizedBox(height: 20),
            _buildVersionInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickUserIcon,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: _userIconFile != null
                  ? FileImage(_userIconFile!)
                  : null,
              child: _userIconFile == null
                  ? Icon(Icons.person, size: 36, color: Colors.blue)
                  : null,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hachico Chat',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  'AIキャラクターと楽しく会話',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'アイコンをタップして変更',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    List<String> features,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...features.map(
              (feature) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(feature),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'キャラクターについて',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...ChatService.getAllCharacters()
                .map(
                  (character) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                character,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Text(
                                _getCharacterDescription(character),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  '利用制限について',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('• 無料プラン: 1日30回まで'),
            Text('• プレミアムプラン: 1日150回まで（月額800円）'),
            Text('• 利用回数は毎日0時にリセットされます'),
            Text('• 残り回数は画面上部で確認できます'),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToUseCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  '使い方',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('1. 右上のアイコンでモードを切り替え'),
            Text('2. 人アイコンで参加キャラクターを選択'),
            Text('3. メッセージを入力して送信'),
            Text('4. グループモードでは全キャラクターが順番に返答'),
            Text('5. 相談室モードでは1対1で会話'),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.teal, size: 24),
                SizedBox(width: 8),
                Text(
                  'サービスについて',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('• このアプリはHachicoが提供するAIチャットサービスです'),
            Text('• APIキーはサービス側で管理されており、安全です'),
            Text('• 利用料金はサービス提供者によって管理されます'),
            Text('• プライバシーを重視した設計です'),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Center(
      child: Text(
        'Version 1.0.0',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
    );
  }

  String _getCharacterDescription(String character) {
    switch (character) {
      case '剣士':
        return '忠義に厚い騎士。武と知を兼ね備え、信念を貫く人格者';
      case '魔女':
        return '神秘的な魔法使い。知識と真理の探究者';
      case 'ゴリラ':
        return 'パッションと本能の塊。筋トレと行動力重視';
      case '商人':
        return '計算高い実業家。情報とお金に精通';
      case '冒険家':
        return '刺激と未知を求める旅人。好奇心旺盛';
      case '神':
        return '全知全能の存在。深い洞察と調和を求める';
      case 'カス大学生':
        return '世渡り上手な若者。ズルく生きる知恵を持つ';
      default:
        return '親切なアシスタント';
    }
  }
}
