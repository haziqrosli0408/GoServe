import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AiRecommendationService {
  static final _model = FirebaseAI.vertexAI().generativeModel(
    model: 'gemini-2.5-flash',
  );

  /// Get recommendations from Gemini based on user preferences, location, and available services
  static Future<List<Map<String, dynamic>>> getRecommendations({
    required List<String> userPreferences,
    required String userLocation,
    required List<Map<String, dynamic>> allServices,
  }) async {
    if (allServices.isEmpty) return [];

    try {
      // Create a simplified list of services to send to Gemini to save tokens
      final simplifiedServices = allServices.map((s) => {
        'id': s['serviceId'],
        'title': s['title'],
        'category': s['category'],
        'location': s['providerAddress'],
        'price': s['price'],
      }).toList();

      final prompt = """
      You are an intelligent recommendation engine for a home services app.
      
      User Preferences (Categories): ${userPreferences.join(', ')}
      User Location: $userLocation
      
      Available Services:
      ${jsonEncode(simplifiedServices)}
      
      Task:
      Analyze the available services and rank the top 5 most relevant services for this user.
      Prioritize matches based on:
      1. Category match (must align with their preferences)
      2. Location proximity (prioritize services in or near $userLocation)
      
      Return ONLY a raw JSON list of the recommended service 'id' strings, ordered from best match to worst.
      Do not include any markdown formatting, just the raw JSON array. Example: ["id1", "id2"]
      """;

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "[]";
      
      // Clean up markdown if Gemini accidentally included it
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> recommendedIds = jsonDecode(cleanJson);
      
      // Map the IDs back to the full service objects
      final List<Map<String, dynamic>> finalRecommendations = [];
      for (var id in recommendedIds) {
        final service = allServices.firstWhere((s) => s['serviceId'] == id, orElse: () => {});
        if (service.isNotEmpty) {
          finalRecommendations.add(service);
        }
      }
      
      // If AI fails to return anything, fallback to a simple match
      if (finalRecommendations.isEmpty) {
        return _fallbackRecommendations(userPreferences, userLocation, allServices);
      }
      
      return finalRecommendations;
    } catch (e) {
      debugPrint("Gemini Recommendation Error: $e");
      // Fallback to basic logic if API fails
      return _fallbackRecommendations(userPreferences, userLocation, allServices);
    }
  }

  static List<Map<String, dynamic>> _fallbackRecommendations(
    List<String> prefs, 
    String location, 
    List<Map<String, dynamic>> services
  ) {
    final normalizedPrefs = prefs.map((e) => e.toString().toLowerCase()).toList();
    return services.where((s) {
      final category = (s['category'] as String?)?.toLowerCase() ?? '';
      return normalizedPrefs.any((pref) => category.contains(pref));
    }).toList();
  }
}
