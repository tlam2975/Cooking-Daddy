import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import '../data/models/quotes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String randomQuote;

  @override
  void initState() {
    super.initState();
    randomQuote = cookingQuotes[Random().nextInt(cookingQuotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEAEA),
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: const Color(0xFFFFA4A4),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Stack(
                children: [
                  // Back button
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 32,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Title
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Cooking Daddy',
                          style: TextStyle(
                            fontSize: 40,
                            color: Color.fromARGB(255, 255, 230, 0),
                          ),
                        ),
                        Text(
                          randomQuote,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings'.tr(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Language Setting
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: const Icon(
                          Icons.language,
                          size: 32,
                          color: Color(0xFFFFA4A4),
                        ),
                        title: Text(
                          'language'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          context.locale.languageCode == 'en'
                              ? 'english'.tr()
                              : 'vietnamese'.tr(),
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showLanguageDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'copyright'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: context.locale.languageCode,
                onChanged: (value) {
                  context.setLocale(Locale('en'));
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              title: Text('english'.tr()),
              onTap: () {
                context.setLocale(Locale('en'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'vi',
                groupValue: context.locale.languageCode,
                onChanged: (value) {
                  context.setLocale(Locale('vi'));
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              title: Text('vietnamese'.tr()),
              onTap: () {
                context.setLocale(Locale('vi'));
                Navigator.pop(context);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
