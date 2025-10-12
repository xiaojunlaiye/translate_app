import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

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
                    '语音翻译',
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
  final String backendBaseUrl = 'http://summer.pink:8888';
  
  String _translatedText = '';
  String _spokenStyleText = '';
  String _writtenStyleText = '';
  bool _isLoading = false;
  String _selectedTargetLanguage = 'English';
  bool _isChineseToOther = true; // true: 中文→其他语言, false: 其他语言→中文
  
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
    final savedDirection = prefs.getBool('is_chinese_to_other');
    if (savedTargetLang != null && _targetLanguages.containsKey(savedTargetLang)) {
      _selectedTargetLanguage = savedTargetLang;
    }
    if (savedDirection != null) {
      _isChineseToOther = savedDirection;
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_target_language', _selectedTargetLanguage);
    await prefs.setBool('is_chinese_to_other', _isChineseToOther);
  }

  Future<void> _translateText() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 根据翻译方向设置源语言和目标语言
      String sourceLanguage;
      String targetLanguage;
      
      if (_isChineseToOther) {
        // 中文 → 其他语言
        sourceLanguage = 'zh';
        targetLanguage = _targetLanguages[_selectedTargetLanguage]!;
      } else {
        // 其他语言 → 中文
        sourceLanguage = _targetLanguages[_selectedTargetLanguage]!;
        targetLanguage = 'zh';
      }
      
      final payload = {
        'text': _textController.text,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'auto_detect': false, // 明确指定源语言，不使用自动检测
        'style': 'all',
      };
      print('POST /translate payload (text): ' + jsonEncode(payload));
      final response = await http.post(
        Uri.parse('$backendBaseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translated_text'] ?? '翻译失败';
        
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
            // 语言选择器和方向切换
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '翻译设置',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // 翻译方向显示和切换 - 重新设计
                    Column(
                      children: [
                        // 翻译方向指示器
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 源语言
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isChineseToOther ? Colors.blue[500] : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isChineseToOther ? [
                                    BoxShadow(
                                      color: Colors.blue[300]!,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ] : null,
                                ),
                                child: Text(
                                  _isChineseToOther ? '中文' : _selectedTargetLanguage,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isChineseToOther ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                              
                              // 箭头指示器
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Colors.blue[600],
                                  size: 20,
                                ),
                              ),
                              
                              // 目标语言
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isChineseToOther ? Colors.blue[500] : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !_isChineseToOther ? [
                                    BoxShadow(
                                      color: Colors.blue[300]!,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ] : null,
                                ),
                                child: Text(
                                  !_isChineseToOther ? '中文' : _selectedTargetLanguage,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: !_isChineseToOther ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 切换按钮 - 更醒目的设计
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isChineseToOther = !_isChineseToOther;
                            });
                            _savePrefs();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[500],
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange[300]!,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '切换翻译方向',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
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
  final String backendBaseUrl = 'http://43.165.179.193:8888';
  
  // 语音相关
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  // 状态管理
  String _voiceInputText = '';
  bool _isLoading = false;
  String _selectedTargetLanguage = 'English'; // 目标语言（非中文）
  String _selectedStyle = '书面风格';
  bool _autoTranslate = true;
  bool _isRecording = false;
  bool _isChineseToOther = true; // true: 中文→其他语言, false: 其他语言→中文
  
  // 对话历史
  List<ConversationMessage> _conversationHistory = [];
  
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

    setState(() {
      _isRecording = true;
      _voiceInputText = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _voiceInputText = result.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopRecording() async {
    await _speechToText.stop();
    setState(() {
      _isRecording = false;
    });
    
    if (_voiceInputText.isNotEmpty) {
      if (_autoTranslate) {
        await _translateVoiceInput();
      } else {
        // 如果不自动翻译，只显示识别结果，等待用户手动翻译
        _addMessageToHistory(_voiceInputText, '点击翻译', true);
      }
    }
  }

  Future<void> _translateVoiceInput() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 根据翻译方向设置源语言和目标语言
      String sourceLanguage;
      String targetLanguage;
      
      if (_isChineseToOther) {
        // 中文 → 其他语言
        sourceLanguage = 'zh';
        targetLanguage = _targetLanguages[_selectedTargetLanguage]!;
      } else {
        // 其他语言 → 中文
        sourceLanguage = _targetLanguages[_selectedTargetLanguage]!;
        targetLanguage = 'zh';
      }
      
      final payload = {
        'text': _voiceInputText,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'auto_detect': false, // 明确指定源语言，不使用自动检测
        'style': _selectedStyle,
      };
      print('POST /translate payload (voice): ' + jsonEncode(payload));
      final response = await http.post(
        Uri.parse('$backendBaseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translated_text'] ?? '翻译失败';
        
        // 添加到对话历史
        _addMessageToHistory(_voiceInputText, translatedText, true);
      } else {
        final errorText = '翻译失败: ${response.statusCode}';
        _addMessageToHistory(_voiceInputText, errorText, true);
      }
    } catch (e) {
      final errorText = '翻译错误: $e';
      _addMessageToHistory(_voiceInputText, errorText, true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  // 添加消息到对话历史
  void _addMessageToHistory(String originalText, String translatedText, bool isFromUser) {
    setState(() {
      _conversationHistory.add(ConversationMessage(
        originalText: originalText,
        translatedText: translatedText,
        isFromUser: isFromUser,
        timestamp: DateTime.now(),
      ));
    });
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isFromUser ? Colors.blue[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message.translatedText,
                      style: TextStyle(
                        color: message.isFromUser ? Colors.blue[800] : Colors.black87,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
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
        title: const Text('语音翻译'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        actions: [
          // 语言选择按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String language) {
              setState(() {
                _selectedTargetLanguage = language;
              });
              _savePrefs();
            },
            itemBuilder: (BuildContext context) {
              return _targetLanguages.keys.map((String language) {
                return PopupMenuItem<String>(
                  value: language,
                  child: Row(
                    children: [
                      if (_selectedTargetLanguage == language)
                        const Icon(Icons.check, color: Colors.blue),
                      if (_selectedTargetLanguage == language)
                        const SizedBox(width: 8),
                      Text(language),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 设置栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // 语言显示和方向切换 - 重新设计
                Expanded(
                  child: Column(
                    children: [
                      // 翻译方向指示器
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 源语言
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isChineseToOther ? Colors.blue[500] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isChineseToOther ? [
                                  BoxShadow(
                                    color: Colors.blue[300]!,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ] : null,
                              ),
                              child: Text(
                                _isChineseToOther ? '中文' : _selectedTargetLanguage,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isChineseToOther ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                            
                            // 箭头指示器
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.blue[600],
                                size: 20,
                              ),
                            ),
                            
                            // 目标语言
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isChineseToOther ? Colors.blue[500] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !_isChineseToOther ? [
                                  BoxShadow(
                                    color: Colors.blue[300]!,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ] : null,
                              ),
                              child: Text(
                                !_isChineseToOther ? '中文' : _selectedTargetLanguage,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: !_isChineseToOther ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 切换按钮 - 更醒目的设计
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isChineseToOther = !_isChineseToOther;
                          });
                          _savePrefs();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange[500],
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange[300]!,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '切换翻译方向',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 自动翻译开关
                Row(
                  children: [
                    const Text('自动翻译'),
                    Switch(
                      value: _autoTranslate,
                      onChanged: (value) {
                        setState(() {
                          _autoTranslate = value;
                        });
                        _savePrefs();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 对话历史
          Expanded(
            child: _conversationHistory.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '开始对话',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          '长按下方按钮开始录音',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
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
                        Text('正在翻译...'),
                      ],
                    ),
                  ),
                
                // 录音按钮
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording ? '松开结束录音' : '长按录音',
                  style: TextStyle(
                    color: _isRecording ? Colors.red : Colors.grey[600],
                    fontSize: 14,
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