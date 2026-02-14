import 'package:image_picker/image_picker.dart';
import '../app_services.dart';
import '../models/parsed_workout.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();

  static Future<ParsedWorkout?> pickAndParseImage({bool fromCamera = true}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final mimeType = _getMimeType(image.path);

    final prefs = await AppServices.store.fetchPrefs();
    final client = AppServices.createAiClient(prefs);

    return await client.parseWorkoutImage(prefs, bytes, mimeType);
  }

  static String _getMimeType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
