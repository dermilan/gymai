import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/workout.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Workout?> pickAndParseImage({bool fromCamera = true}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    
    if (image == null) return null;

    try {
      // Read image as bytes and convert to base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Determine mime type from extension
      final extension = image.path.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      
      // Call Cloud Function with extended timeout for image processing
      final callable = _functions.httpsCallable(
        'parseWorkoutImage',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call({
        'imageBase64': base64Image,
        'mimeType': mimeType,
      });
      
      final parsed = result.data['parsed'] as String;
      
      // Parse the JSON response
      // The AI returns JSON embedded in the response, extract it
      String jsonStr = parsed;
      
      // Try to extract JSON from markdown code blocks if present
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(parsed);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1) ?? parsed;
      }
      
      final Map<String, dynamic> workoutData = jsonDecode(jsonStr);
      
      // Check for error response
      if (workoutData.containsKey('error')) {
        throw Exception(workoutData['error']);
      }
      
      return Workout.fromJson(workoutData);
    } catch (e) {
      debugPrint('OCR parsing error: $e');
      rethrow;
    }
  }
}
