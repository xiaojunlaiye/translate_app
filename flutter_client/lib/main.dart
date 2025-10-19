import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '翻译应用',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

// 主页面
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('翻译应用'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.translate,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                '选择翻译方式',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TextTranslatePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.text_fields, size: 32),
                  label: const Text(
                    '文字翻译',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoiceTranslatePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.mic, size: 32),
                  label: const Text(
                    '语音对话',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 文字翻译页面
class TextTranslatePage extends StatefulWidget {
  const TextTranslatePage({super.key});

  @override
  State<TextTranslatePage> createState() => _TextTranslatePageState();
}

class _TextTranslatePageState extends State<TextTranslatePage> {
  final TextEditingController _textController = TextEditingController();
  final String backendBaseUrl = 'http://39.106.34.7:8888';
  
  String _translatedText = '';
  String _spokenStyleText = '';
  String _writtenStyleText = '';
  bool _isLoading = false;
  String _selectedTargetLanguage = 'English';
  // 文字翻译固定为中文到其他语言
  
  // 支持的目标语言列表（除中文外）
  final Map<String, String> _targetLanguages = {
    'English': 'en',
    '日本語': 'ja',
    '한국어': 'ko',
    'Français': 'fr',
    'Deutsch': 'de',
    'Español': 'es',
    'Русский': 'ru',
    'العربية': 'ar',
  };

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTargetLang = prefs.getString('selected_target_language');
    if (savedTargetLang != null && _targetLanguages.containsKey(savedTargetLang)) {
      _selectedTargetLanguage = savedTargetLang;
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_target_language', _selectedTargetLanguage);
  }

  Future<void> _translateText() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 文字翻译固定为中文到其他语言
      String sourceLanguage = 'zh';
      String targetLanguage = _targetLanguages[_selectedTargetLanguage]!;
      
      final payload = {
        'text': _textController.text,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'auto_detect': false, // 明确指定源语言，不使用自动检测
        'style': 'all',
      };
      // 打印发送的数据
      print('=== POST /translate 请求数据 (文字翻译) ===');
      print('URL: $backendBaseUrl/translate');
      print('Payload: ${jsonEncode(payload)}');
      print('Content-Type: application/json');
      print('==========================================');
      final response = await http.post(
        Uri.parse('$backendBaseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // 响应日志
      print('=== /translate 响应 (文字翻译) ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('==============================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 兼容字段: translated_text 或 result
        final translatedText = (data['translated_text'] ?? data['result'] ?? '').toString();
        
        // 解析两种风格的翻译结果
        if (translatedText.contains('口语风格:') && translatedText.contains('书面风格:')) {
          final parts = translatedText.split('\n');
          String spokenStyle = '';
          String writtenStyle = '';
          
          for (final part in parts) {
            if (part.contains('口语风格:')) {
              spokenStyle = part.replaceFirst('口语风格:', '').trim();
            } else if (part.contains('书面风格:')) {
              writtenStyle = part.replaceFirst('书面风格:', '').trim();
            }
          }
          
          setState(() {
            _spokenStyleText = spokenStyle;
            _writtenStyleText = writtenStyle;
            _translatedText = ''; // 清空旧的翻译结果
          });
        } else {
          // 如果返回格式不是预期的，显示原始结果
          setState(() {
            _translatedText = translatedText;
            _spokenStyleText = '';
            _writtenStyleText = '';
          });
        }
      } else {
        setState(() {
          _translatedText = '翻译失败: ${response.statusCode}';
          _spokenStyleText = '';
          _writtenStyleText = '';
        });
      }
    } catch (e) {
      setState(() {
        _translatedText = '翻译错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanTextFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        buffer.writeln(block.text);
      }
      final scanned = buffer.toString().trim();
      if (scanned.isNotEmpty) {
        setState(() {
          _textController.text = scanned;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文字翻译'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 语言选择器
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 语言选择器
                    const Text(
                      '目标语言',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedTargetLanguage,
                      isExpanded: true,
                      items: _targetLanguages.keys.map((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTargetLanguage = newValue;
                          });
                          _savePrefs();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            
            // 文本输入区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '输入文本',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: '请输入要翻译的文本',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            SizedBox(
                              height: 48,
                              width: 48,
                              child: ElevatedButton(
                                onPressed: _scanTextFromCamera,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Icon(Icons.camera_alt),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _translateText,
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('翻译中...'),
                                ],
                              )
                            : const Text('翻译'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_spokenStyleText.isNotEmpty || _writtenStyleText.isNotEmpty || _translatedText.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '翻译结果',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // 口语风格翻译
                      if (_spokenStyleText.isNotEmpty) ...[
                        const Text(
                          '口语风格',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Text(
                            _spokenStyleText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // 书面风格翻译
                      if (_writtenStyleText.isNotEmpty) ...[
                        const Text(
                          '书面风格',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            _writtenStyleText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // 原始翻译结果（如果格式不匹配）
                      if (_translatedText.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            _translatedText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 对话消息模型
class ConversationMessage {
  final String originalText;
  final String translatedText;
  final bool isFromUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.originalText,
    required this.translatedText,
    required this.isFromUser,
    required this.timestamp,
  });
}

// 语音翻译页面
class VoiceTranslatePage extends StatefulWidget {
  const VoiceTranslatePage({super.key});

  @override
  State<VoiceTranslatePage> createState() => _VoiceTranslatePageState();
}

class _VoiceTranslatePageState extends State<VoiceTranslatePage> {
  final String backendBaseUrl = 'http://39.106.34.7:8888';
  
  // 语音相关
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // 状态管理
  String _voiceInputText = '';
  bool _isLoading = false;
  String _selectedTargetLanguage = 'English'; // 目标语言（非中文）
  String _selectedStyle = '书面风格';
  bool _autoTranslate = true;
  bool _isRecording = false;
  bool _isChineseToOther = true; // true: 中文→其他语言, false: 其他语言→中文
  String? _audioPath;
  
  // 对话历史
  List<ConversationMessage> _conversationHistory = [];
  
  // 历史记录存储
  List<ConversationMessage> _allHistory = [];
  
  // 支持的目标语言列表（除中文外）
  final Map<String, String> _targetLanguages = {
    'English': 'en',
    '日本語': 'ja',
    '한국어': 'ko',
    'Français': 'fr',
    'Deutsch': 'de',
    'Español': 'es',
    'Русский': 'ru',
    'العربية': 'ar',
  };

  // 翻译风格列表
  final List<String> _translationStyles = ['书面风格', '口语风格'];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _loadPrefs();
  }

  Future<void> _initSpeech() async {
    bool available = await _speechToText.initialize();
    if (!available) {
      print('语音识别不可用');
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // 检查TTS支持的语言
    await _checkTtsLanguages();
  }

  // 测试日语TTS
  Future<void> _testJapaneseTts() async {
    print('🔴 === 开始测试日语TTS ===');
    
    try {
      // 首先检查TTS是否可用
      bool isAvailable = await _flutterTts.isLanguageAvailable('ja-JP');
      print('🔴 日语TTS可用性检查: $isAvailable');
      
      // 获取支持的语言列表
      List<dynamic> languages = await _flutterTts.getLanguages;
      print('🔴 所有支持的语言: $languages');
      
      // 查找日语相关的语言
      List<String> japaneseCodes = ['ja-JP', 'ja', 'ja_JP', 'japanese', 'ja_JP_JP'];
      List<String> availableJapanese = [];
      
      for (var lang in languages) {
        String langStr = lang.toString().toLowerCase();
        if (langStr.contains('ja') || langStr.contains('japanese') || langStr.contains('japan')) {
          availableJapanese.add(lang.toString());
        }
      }
      
      print('🔴 找到的日语语言: $availableJapanese');
      
      if (availableJapanese.isEmpty) {
        print('🔴 ❌ 设备不支持日语TTS');
        print('🔴 建议: 在设备设置中安装日语语音包');
        
        // 显示用户友好的提示
        _showJapaneseTtsNotSupportedDialog();
        return;
      }
      
      // 测试每个可用的日语代码
      for (String code in availableJapanese) {
        print('🔴 尝试日语代码: $code');
        try {
          await _flutterTts.setLanguage(code);
          await _flutterTts.speak('こんにちは');
          print('🔴 ✅ 日语代码 $code 工作正常');
          return;
      } catch (e) {
          print('🔴 ❌ 日语代码 $code 失败: $e');
        }
      }
      
      print('🔴 ⚠️ 所有日语代码都失败了');
    } catch (e) {
      print('🔴 日语TTS测试失败: $e');
    }
  }

  // 文本转语音功能
  Future<void> _speakText(String text, {String? targetLanguage}) async {
    if (text.isEmpty) return;
    
    try {
      // 根据传入的目标语言或当前选择的目标语言设置TTS语言
      String languageToUse = targetLanguage ?? _selectedTargetLanguage;
      String ttsLanguage = await _getTtsLanguageWithFallback(languageToUse);
      
      print('TTS: 使用语言 $ttsLanguage (目标语言: $languageToUse)');
      
      // 如果是日语，先测试一下
      if (languageToUse == '日本語') {
        print('检测到日语，先测试TTS支持...');
        await _testJapaneseTts();
      }
      
      await _flutterTts.setLanguage(ttsLanguage);
      
      print('TTS: 朗读文本 "$text" (语言: $ttsLanguage)');
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS错误: $e');
      // 如果设置失败，尝试用英语朗读
      try {
        print('TTS: 回退到英语朗读');
        await _flutterTts.setLanguage('en-US');
        await _flutterTts.speak(text);
      } catch (fallbackError) {
        print('TTS回退也失败: $fallbackError');
      }
    }
  }

  // 检测文本是否为中文
  bool _isChineseText(String text) {
    // 简单的中文检测：如果包含中文字符，认为是中文
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  // 检测文本是否为日语
  bool _isJapaneseText(String text) {
    // 检测平假名、片假名、汉字
    return RegExp(r'[\u3040-\u309f\u30a0-\u30ff\u4e00-\u9fff]').hasMatch(text);
  }

  // 检测文本是否为韩语
  bool _isKoreanText(String text) {
    // 检测韩文字符
    return RegExp(r'[\uac00-\ud7af]').hasMatch(text);
  }

  // 检测文本是否为阿拉伯语
  bool _isArabicText(String text) {
    // 检测阿拉伯文字符
    return RegExp(r'[\u0600-\u06ff]').hasMatch(text);
  }

  // 检测文本是否为俄语
  bool _isRussianText(String text) {
    // 检测西里尔字母
    return RegExp(r'[\u0400-\u04ff]').hasMatch(text);
  }

  // 显示日语TTS不支持对话框
  void _showJapaneseTtsNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('日语语音不支持'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('您的设备不支持日语语音朗读。'),
              SizedBox(height: 8),
              Text('解决方案：'),
              Text('1. 在设备设置中安装日语语音包'),
              Text('2. 日语翻译结果将用英语朗读'),
              SizedBox(height: 8),
              Text('设置路径：'),
              Text('iOS: 设置 → 辅助功能 → 朗读内容 → 语音'),
              Text('Android: 设置 → 辅助功能 → 文字转语音'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  // 显示使用说明
  void _showUsageTip() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text('使用说明'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '语音对话使用方法：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. 长按录音按钮'),
              Text('2. 说出你要表达的内容'),
              Text('3. 松开按钮，系统会自动识别和翻译'),
              SizedBox(height: 8),
              Text(
                '提示：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• 支持中文与其他语言互译'),
              Text('• 系统会自动检测语言方向'),
              Text('• 翻译结果会自动朗读'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  // 显示历史记录对话框
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 标题栏
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Text(
                      '历史记录',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                
                // 历史记录列表
                Expanded(
                  child: _allHistory.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '暂无历史记录',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _allHistory.length,
                          itemBuilder: (context, index) {
                            final message = _allHistory[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          message.isFromUser ? Icons.person : Icons.smart_toy,
                                          size: 16,
                                          color: message.isFromUser ? Colors.blue : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          message.isFromUser ? '我' : '翻译',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: message.isFromUser ? Colors.blue : Colors.green,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTime(message.timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message.originalText,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (message.translatedText.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        message.translatedText,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // 底部按钮
                if (_allHistory.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _clearAllHistory();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('清空历史'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('关闭'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 格式化时间
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 清空所有历史记录
  void _clearAllHistory() {
    setState(() {
      _allHistory.clear();
    });
    // 同时清空本地存储
    _saveHistory();
  }

  // 保存历史记录到本地存储
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _allHistory.map((message) => {
        'originalText': message.originalText,
        'translatedText': message.translatedText,
        'isFromUser': message.isFromUser,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      }).toList();
      
      await prefs.setString('translation_history', jsonEncode(historyJson));
      print('历史记录已保存: ${_allHistory.length} 条记录');
    } catch (e) {
      print('保存历史记录失败: $e');
    }
  }

  // 从本地存储加载历史记录
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('translation_history');
      
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _allHistory = historyList.map((item) => ConversationMessage(
          originalText: item['originalText'] ?? '',
          translatedText: item['translatedText'] ?? '',
          isFromUser: item['isFromUser'] ?? false,
          timestamp: DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0),
        )).toList();
        
        print('历史记录已加载: ${_allHistory.length} 条记录');
      }
    } catch (e) {
      print('加载历史记录失败: $e');
      _allHistory = []; // 如果加载失败，初始化为空列表
    }
  }

  // 检测输入文本的语言
  String _detectInputLanguage(String text) {
    if (_isChineseText(text)) {
      return 'zh';
    } else if (_isJapaneseText(text)) {
      return 'ja';
    } else if (_isKoreanText(text)) {
      return 'ko';
    } else if (_isArabicText(text)) {
      return 'ar';
    } else if (_isRussianText(text)) {
      return 'ru';
    } else {
      // 默认认为是英语
      return 'en';
    }
  }

  // 获取TTS语言代码
  String _getTtsLanguage(String targetLanguage) {
    switch (targetLanguage) {
      case '中文':
        return 'zh-CN';
      case 'English':
        return 'en-US';
      case '日本語':
        return 'ja-JP';  // 主要尝试 ja-JP
      case '한국어':
        return 'ko-KR';
      case 'Français':
        return 'fr-FR';
      case 'Deutsch':
        return 'de-DE';
      case 'Español':
        return 'es-ES';
      case 'Русский':
        return 'ru-RU';
      case 'العربية':
        return 'ar-SA';
      default:
        return 'en-US';
    }
  }

  // 获取TTS语言代码（带备用选项）
  Future<String> _getTtsLanguageWithFallback(String targetLanguage) async {
    String primaryLanguage = _getTtsLanguage(targetLanguage);
    
    // 对于日语，尝试多种语言代码
    if (targetLanguage == '日本語') {
      List<String> japaneseCodes = ['ja-JP', 'ja', 'ja_JP'];
      
      for (String code in japaneseCodes) {
        try {
          await _flutterTts.setLanguage(code);
          // 由于 getLanguage 不可用，我们假设设置成功
          print('TTS: 日语语言代码 $code 设置尝试完成');
          return code;
        } catch (e) {
          print('TTS: 日语语言代码 $code 设置失败: $e');
        }
      }
    }
    
    return primaryLanguage;
  }

  // 获取TTS支持的语言列表
  Future<void> _checkTtsLanguages() async {
    try {
      List<dynamic> languages = await _flutterTts.getLanguages;
      print('TTS支持的语言: $languages');
      
      // 检查是否包含日语相关的语言代码
      bool hasJapanese = false;
      for (var lang in languages) {
        String langStr = lang.toString().toLowerCase();
        if (langStr.contains('ja') || langStr.contains('japanese') || langStr.contains('japan')) {
          hasJapanese = true;
          print('找到日语支持: $lang');
        }
      }
      
      if (!hasJapanese) {
        print('⚠️ 警告: 未找到日语TTS支持');
        print('建议: 在设备设置中安装日语语音包');
      }
    } catch (e) {
      print('获取TTS语言列表失败: $e');
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTargetLang = prefs.getString('selected_target_language');
    final savedStyle = prefs.getString('selected_style');
    final savedAutoTranslate = prefs.getBool('auto_translate');
    final savedDirection = prefs.getBool('is_chinese_to_other');
    if (savedTargetLang != null && _targetLanguages.containsKey(savedTargetLang)) {
      setState(() {
        _selectedTargetLanguage = savedTargetLang;
      });
    }
    if (savedStyle != null && _translationStyles.contains(savedStyle)) {
      setState(() {
        _selectedStyle = savedStyle;
      });
    }
    if (savedAutoTranslate != null) {
      setState(() {
        _autoTranslate = savedAutoTranslate;
      });
    }
    if (savedDirection != null) {
      setState(() {
        _isChineseToOther = savedDirection;
      });
    }
    
    // 加载历史记录
    await _loadHistory();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_target_language', _selectedTargetLanguage);
    await prefs.setBool('auto_translate', _autoTranslate);
    await prefs.setBool('is_chinese_to_other', _isChineseToOther);
  }

  Future<void> _startRecording() async {
    // 请求麦克风权限
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能使用语音功能')),
      );
      return;
    }

    try {
      // 获取临时目录
      final directory = await getTemporaryDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      _audioPath = '${directory.path}/$fileName';
      
      setState(() {
        _isRecording = true;
        _voiceInputText = '';
      });

      // 开始录音
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: _audioPath!,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始录音失败: $e')),
      );
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      
      if (_audioPath != null && File(_audioPath!).existsSync()) {
        await _recognizeSpeech();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('停止录音失败: $e')),
      );
      setState(() {
        _isRecording = false;
      });
    }
  }

  // 语音识别API调用
  Future<void> _recognizeSpeech() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 读取音频文件
      final audioFile = File(_audioPath!);
      final audioBytes = await audioFile.readAsBytes();
      
      // 语言由后端自动识别（不在此处指定）
      
      // 创建multipart请求
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendBaseUrl/speech_to_text'),
      );
      
      // 添加音频文件
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'audio.wav',
        ),
      );
      
      // 添加语言参数
      request.fields['language'] = 'auto';
      
      // 打印发送的数据
      print('=== POST /speech_to_text 请求数据 ===');
      print('URL: $backendBaseUrl/speech_to_text');
      print('Language: auto');
      print('Audio file size: ${audioBytes.length} bytes');
      print('Audio filename: audio.wav');
      print('Content-Type: multipart/form-data');
      print('=====================================');
      
      // 发送请求
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      // 响应日志
      print('=== /speech_to_text 响应 ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('===========================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 兼容字段: text 或 result 或 transcript
        final recognizedText = (data['text'] ?? data['result'] ?? data['transcript'] ?? '').toString().trim();

        final finalText = recognizedText.isNotEmpty ? recognizedText : '识别失败';
        setState(() {
          _voiceInputText = finalText;
        });

        if (_autoTranslate && finalText.isNotEmpty && finalText != '识别失败') {
          // 展示占位并自动翻译
          _addMessageToHistory(finalText, '翻译中...', true);
          await _translateText(finalText);
        } else {
          // 仅展示识别文本，不占用额外空间
          _addMessageToHistory(finalText, '', true);
        }
      } else {
        final errorText = '语音识别失败: ${response.statusCode} ${response.body}';
        _addMessageToHistory('语音识别失败', errorText, true);
      }
    } catch (e) {
      final errorText = '语音识别错误: $e';
      _addMessageToHistory('语音识别失败', errorText, true);
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // 清理临时音频文件
      if (_audioPath != null && File(_audioPath!).existsSync()) {
        await File(_audioPath!).delete();
        _audioPath = null;
      }
    }
  }

  // 添加消息到对话历史
  void _addMessageToHistory(String originalText, String translatedText, bool isFromUser) {
    final message = ConversationMessage(
      originalText: originalText,
      translatedText: translatedText,
      isFromUser: isFromUser,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _conversationHistory.add(message);
      _allHistory.add(message); // 同时保存到历史记录
    });
    
    // 自动保存历史记录到本地存储
    _saveHistory();
  }

  // 翻译文本
  Future<void> _translateText(String text) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 智能检测翻译方向：根据文本内容和用户选择判断
      String sourceLanguage;
      String targetLanguage;
      
      // 检测输入文本的语言
      String detectedLanguage = _detectInputLanguage(text);
      String selectedTargetCode = _targetLanguages[_selectedTargetLanguage]!;
      
      if (detectedLanguage == 'zh') {
        // 中文 → 其他语言
        sourceLanguage = 'zh';
        targetLanguage = selectedTargetCode;
        print('检测到中文文本，翻译方向: 中文 → ${_selectedTargetLanguage}');
      } else if (detectedLanguage == selectedTargetCode) {
        // 目标语言 → 中文
        sourceLanguage = selectedTargetCode;
        targetLanguage = 'zh';
        print('检测到目标语言文本，翻译方向: ${_selectedTargetLanguage} → 中文');
      } else {
        // 其他语言 → 中文 (默认)
        sourceLanguage = detectedLanguage;
        targetLanguage = 'zh';
        print('检测到其他语言文本，翻译方向: $detectedLanguage → 中文');
      }
      
      final payload = {
        'text': text,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'auto_detect': false, // 明确指定源语言，不使用自动检测
        'style': _selectedStyle,
      };
      // 打印发送的数据
      print('=== POST /translate 请求数据 ===');
      print('URL: $backendBaseUrl/translate');
      print('Payload: ${jsonEncode(payload)}');
      print('Content-Type: application/json');
      print('===============================');
      final response = await http.post(
        Uri.parse('$backendBaseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // 响应日志
      print('=== /translate 响应 (语音翻译) ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('============================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 兼容字段: translated_text 或 result
        final translatedText = (data['translated_text'] ?? data['result'] ?? '').toString();
        
        // 更新对话历史中的翻译结果
        setState(() {
          for (int i = 0; i < _conversationHistory.length; i++) {
            if (_conversationHistory[i].originalText == text && 
                (_conversationHistory[i].translatedText.isEmpty || _conversationHistory[i].translatedText == '翻译中...')) {
              _conversationHistory[i] = ConversationMessage(
                originalText: _conversationHistory[i].originalText,
                translatedText: translatedText,
                isFromUser: _conversationHistory[i].isFromUser,
                timestamp: _conversationHistory[i].timestamp,
              );
              break;
            }
          }
        });
        
        // 自动朗读翻译结果
        if (translatedText.isNotEmpty) {
          // 根据翻译方向决定TTS语言
          String ttsLanguage;
          if (targetLanguage == 'zh') {
            // 翻译结果是中文，TTS使用中文
            ttsLanguage = '中文';
          } else {
            // 翻译结果是其他语言，TTS使用目标语言
            ttsLanguage = _selectedTargetLanguage;
          }
          print('TTS语言选择: $ttsLanguage (翻译结果语言: $targetLanguage)');
          
          // 特殊处理：如果是日语但设备不支持，用英语朗读
          if (ttsLanguage == '日本語') {
            print('检测到日语TTS，检查设备支持...');
            bool isJapaneseSupported = await _flutterTts.isLanguageAvailable('ja-JP');
            if (!isJapaneseSupported) {
              print('设备不支持日语TTS，降级到英语朗读');
              ttsLanguage = 'English';
            }
          }
          
          await _speakText(translatedText, targetLanguage: ttsLanguage);
        }
      } else {
        // 更新为错误信息，附带后端返回内容
        setState(() {
          for (int i = 0; i < _conversationHistory.length; i++) {
            if (_conversationHistory[i].originalText == text && 
                (_conversationHistory[i].translatedText.isEmpty || _conversationHistory[i].translatedText == '翻译中...')) {
              _conversationHistory[i] = ConversationMessage(
                originalText: _conversationHistory[i].originalText,
                translatedText: '翻译失败: ${response.statusCode} ${response.body}',
                isFromUser: _conversationHistory[i].isFromUser,
                timestamp: _conversationHistory[i].timestamp,
              );
              break;
            }
          }
        });
      }
    } catch (e) {
      // 更新为错误信息
      setState(() {
        for (int i = 0; i < _conversationHistory.length; i++) {
          if (_conversationHistory[i].originalText == text && 
              (_conversationHistory[i].translatedText.isEmpty || _conversationHistory[i].translatedText == '翻译中...')) {
            _conversationHistory[i] = ConversationMessage(
              originalText: _conversationHistory[i].originalText,
              translatedText: '翻译错误: $e',
              isFromUser: _conversationHistory[i].isFromUser,
              timestamp: _conversationHistory[i].timestamp,
            );
            break;
          }
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 构建消息气泡
  Widget _buildMessageBubble(ConversationMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: message.isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, size: 20, color: Colors.blue[700]),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment: message.isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 原文
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isFromUser ? Colors.blue[500] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message.originalText,
                      style: TextStyle(
                        color: message.isFromUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 翻译
                  if (message.translatedText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isFromUser ? Colors.blue[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              message.translatedText,
                              style: TextStyle(
                                color: message.isFromUser ? Colors.blue[800] : Colors.black87,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              // 根据翻译结果内容智能决定TTS语言
                              String ttsLanguage;
                              if (_isChineseText(message.translatedText)) {
                                // 翻译结果是中文，TTS使用中文
                                ttsLanguage = '中文';
                              } else {
                                // 翻译结果是其他语言，TTS使用目标语言
                                ttsLanguage = _selectedTargetLanguage;
                                
                                // 特殊处理：如果是日语但设备不支持，用英语朗读
                                if (ttsLanguage == '日本語') {
                                  bool isJapaneseSupported = await _flutterTts.isLanguageAvailable('ja-JP');
                                  if (!isJapaneseSupported) {
                                    print('设备不支持日语TTS，降级到英语朗读');
                                    ttsLanguage = 'English';
                                  }
                                }
                              }
                              _speakText(message.translatedText, targetLanguage: ttsLanguage);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.volume_up,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.person, size: 20, color: Colors.green[700]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音对话'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        actions: [
          // 历史记录按钮
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              _showHistoryDialog();
            },
            tooltip: '历史记录',
          ),
        ],
      ),
      body: Column(
        children: [
          // 设置栏（简化版）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // 目标语言选择（紧凑版）
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Colors.blue[600],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '对方的语言:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedTargetLanguage,
                          isExpanded: true,
                          underline: Container(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          items: _targetLanguages.keys.map((String language) {
                            return DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTargetLanguage = newValue;
                              });
                              _savePrefs();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 使用说明图标（点击显示）
                GestureDetector(
                  onTap: () {
                    _showUsageTip();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.help_outline,
                      color: Colors.blue[600],
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 对话历史
          Expanded(
            child: _conversationHistory.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 40,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '语音对话使用说明',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '使用方法：',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '1. 长按录音按钮',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    '2. 说出你要表达的内容',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    '3. 松开按钮，系统会自动识别和翻译',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '功能特点：',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '• 支持中文与其他语言互译',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    '• 系统会自动检测语言方向',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    '• 翻译结果会自动朗读',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '点击下方按钮开始对话',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _conversationHistory.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_conversationHistory[index]);
                    },
                  ),
          ),
          
          // 底部录音区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('正在获取语音识别结果...'),
                      ],
                    ),
                  ),
                
                // 录音按钮 - 优化UI
                Center(
                  child: Column(
                    children: [
                      // 录音按钮
                      GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecording(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 100 : 90,
                          height: _isRecording ? 100 : 90,
                          decoration: BoxDecoration(
                            gradient: _isRecording 
                                ? LinearGradient(
                                    colors: [Colors.red[400]!, Colors.red[600]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.4),
                                blurRadius: _isRecording ? 20 : 15,
                                spreadRadius: _isRecording ? 3 : 2,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 2,
                                spreadRadius: -1,
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: Colors.white,
                              size: _isRecording ? 36 : 32,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 录音状态指示器
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isRecording ? Colors.red[200]! : Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRecording) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red[500],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isRecording ? '正在录音...' : '长按开始录音',
                              style: TextStyle(
                                color: _isRecording ? Colors.red[700] : Colors.blue[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 提示文字
                      Text(
                        _isRecording ? '松开结束录音' : '松开后点击翻译按钮',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 8),
                      
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}