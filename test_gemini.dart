// import 'dart:io';
// import 'package:google_generative_ai/google_generative_ai.dart';

// void main() async {
//   final apiKey = "AIzaSyDVpeYuRkuytlZZL7FzruK2vVwJWwDHPbA";
//   final prompt = "Write a 2-sentence poem about a coder drinking coffee.";

//   final model = GenerativeModel(
//     apiKey: apiKey,
//     model: "gemini-2.5-flash",
//   );

//   try {
//     final response = await model.generateContent(prompt);
//     print("\n--- Gemini's Response ---");
//     print(response.text);
//   } catch (e) {
//     print("\n" * 3 + "=" * 21);
//     print("Error: $e");
//     print("=" * 21 + "\n" * 3);
//   }
// }
