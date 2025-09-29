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
  String _selectedLanguage = 'English';
  
  // 支持的语言列表
  final Map<String, String> _languages = {
    'English': 'en',
    '中文': 'zh',
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
    final savedLang = prefs.getString('selected_language');
    if (savedLang != null && _languages.containsKey(savedLang)) {
      _selectedLanguage = savedLang;
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage);
  }

  Future<void> _translateText() async {
    if (_textController.text.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'text': _textController.text,
        'target_language': _languages[_selectedLanguage],
        'auto_detect': true,
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
            // 语言选择器
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目标语言',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      items: _languages.keys.map((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
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
  String _voiceTranslatedText = '';
  String _voiceInputText = '';
  bool _isLoading = false;
  bool _isListening = false;
  bool _isPlaying = false;
  String _selectedLanguage = 'English';
  String _selectedStyle = '书面风格';
  
  // 支持的语言列表
  final Map<String, String> _languages = {
    'English': 'en',
    '中文': 'zh',
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
    final savedLang = prefs.getString('selected_language');
    final savedStyle = prefs.getString('selected_style');
    if (savedLang != null && _languages.containsKey(savedLang)) {
      setState(() {
        _selectedLanguage = savedLang;
      });
    }
    if (savedStyle != null && _translationStyles.contains(savedStyle)) {
      setState(() {
        _selectedStyle = savedStyle;
      });
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage);
  }

  Future<void> _startListening() async {
    // 请求麦克风权限
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能使用语音功能')),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _voiceInputText = result.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    
    if (_voiceInputText.isNotEmpty) {
      await _translateVoiceInput();
    }
  }

  Future<void> _translateVoiceInput() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'text': _voiceInputText,
        'target_language': _languages[_selectedLanguage],
        'auto_detect': true,
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
        setState(() {
          _voiceTranslatedText = data['translated_text'] ?? '翻译失败';
        });
      } else {
        setState(() {
          _voiceTranslatedText = '翻译失败: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _voiceTranslatedText = '翻译错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playTranslatedVoice() async {
    if (_voiceTranslatedText.isEmpty) return;

    setState(() {
      _isPlaying = true;
    });

    await _flutterTts.speak(_voiceTranslatedText);
    
    // 等待播放完成
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语音翻译'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 语言/风格选择器
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目标语言',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      items: _languages.keys.map((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                          _savePrefs();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '翻译风格',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedStyle,
                      isExpanded: true,
                      items: _translationStyles.map((String style) {
                        return DropdownMenuItem<String>(
                          value: style,
                          child: Text(style),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedStyle = newValue;
                          });
                          _savePrefs();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 语音控制区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '语音控制',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isListening ? _stopListening : _startListening,
                            icon: Icon(_isListening ? Icons.stop : Icons.mic),
                            label: Text(_isListening ? '停止录音' : '开始录音'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isListening ? Colors.red : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        if (_voiceTranslatedText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isPlaying ? null : _playTranslatedVoice,
                            icon: Icon(_isPlaying ? Icons.volume_up : Icons.volume_up),
                            label: Text(_isPlaying ? '播放中...' : '播放'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_isListening) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.mic, size: 48, color: Colors.red),
                            SizedBox(height: 8),
                            Text('正在录音...', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            if (_voiceInputText.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '语音识别结果',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          _voiceInputText,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (_voiceTranslatedText.isNotEmpty) ...[
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          _voiceTranslatedText,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在翻译...', style: TextStyle(fontSize: 16)),
                      ],
                    ),
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