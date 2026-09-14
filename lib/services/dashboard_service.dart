import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class DashboardBrief {
  final String date;
  final String title;
  final String tip;
  final String imageUrl;

  const DashboardBrief({
    required this.date,
    required this.title,
    required this.tip,
    required this.imageUrl,
  });

  factory DashboardBrief.fromJson(Map<String, dynamic> json) {
    return DashboardBrief(
      date: json['date'] as String? ?? _todayKey(),
      title: json['title'] as String? ?? 'Daily kitchen note',
      tip: json['tip'] as String? ?? _fallbackTip,
      imageUrl: json['imageUrl'] as String? ?? _fallbackImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'title': title,
      'tip': tip,
      'imageUrl': imageUrl,
      'cachedAt': FieldValue.serverTimestamp(),
    };
  }
}

class DashboardService {
  final String baseUrl;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DashboardService({this.baseUrl = 'http://localhost:2975'});

  Future<DashboardBrief> getDailyBrief() async {
    final date = _todayKey();
    final cached = await _getCachedBrief(date);
    if (cached != null) return cached;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/dashboard?date=$date'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final brief = DashboardBrief.fromJson(jsonDecode(response.body));
        await _cacheBrief(brief);
        return brief;
      }
    } catch (_) {
      // Dashboard content is decorative; the app should stay useful offline.
    }

    return DashboardBrief.fromJson({'date': date});
  }

  Future<DashboardBrief?> _getCachedBrief(String date) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dashboardCache')
          .doc(date)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return DashboardBrief.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheBrief(DashboardBrief brief) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dashboardCache')
          .doc(brief.date)
          .set(brief.toJson());
    } catch (_) {
      // Ignore cache write failures; server/local fallback already works.
    }
  }
}

String _todayKey() {
  return DateTime.now().toIso8601String().split('T').first;
}

const _fallbackTip =
    'Pick one small prep task before cooking: wash herbs, measure sauce, or clear the cutting board.';

const _fallbackImage =
    'https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=1200&q=80';
