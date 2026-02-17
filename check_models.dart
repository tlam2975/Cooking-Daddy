import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Quick test to see what models are available
void main() async {
  print('🔍 Checking available Gemini models...\n');

  // Load API key from .env file
  final apiKey = await loadApiKey();

  if (apiKey == null) {
    print('❌ ERROR: Could not load GEMINI_API_KEY from .env file');
    return;
  }

  print('✅ API Key loaded\n');

  // Try v1 API instead of v1beta
  print('Testing v1 API...');
  await testAPI('v1', apiKey);

  print('\n---\n');

  // Try v1beta API
  print('Testing v1beta API...');
  await testAPI('v1beta', apiKey);
}

Future<String?> loadApiKey() async {
  try {
    final file = File('.env');
    if (!await file.exists()) {
      return null;
    }

    final lines = await file.readAsLines();
    for (var line in lines) {
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        continue;
      }

      if (line.contains('GEMINI_API_KEY=')) {
        final key = line.split('=')[1].trim();
        return key.replaceAll('"', '').replaceAll("'", '');
      }
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<void> testAPI(String version, String apiKey) async {
  final models = [
    'gemini-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash-exp',
  ];

  for (var model in models) {
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models/$model:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Hello'},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        print('✅ $version/$model - WORKS!');
      } else if (response.statusCode == 404) {
        print('❌ $version/$model - Not found');
      } else {
        print('⚠️  $version/$model - Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ $version/$model - Error: $e');
    }
  }
}
