import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AiService {
  // Buraya kendi Gemini API Key'ini yazacaksın
  final String apiKey = "BURAYA_GEMINI_API_KEY_GELECEK"; 
  
  // Unsplash Access Key (Ücretsiz alabilirsin: https://unsplash.com/developers)
  final String unsplashKey = "BURAYA_UNSPLASH_ACCESS_KEY_GELECEK";

  Future<List<Map<String, String>>> generateOptions(String topic) async {
    final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);

    // AI'ya verdiğimiz emir (Prompt Engineering)
    final prompt = '''
      Bana "$topic" konusuyla ilgili popüler olan 8 adet seçenek listele.
      Sadece JSON formatında cevap ver. Başka hiçbir metin yazma.
      Format şöyle olsun:
      [
        {"isim": "Örnek 1", "ingilizce_arama_terimi": "Example 1"},
        {"isim": "Örnek 2", "ingilizce_arama_terimi": "Example 2"}
      ]
      "ingilizce_arama_terimi" kısmını görsel aramak için kullanacağım, o yüzden o kısmı İngilizce yaz.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // Gelen cevabı temizle (Bazen ```json ... ``` içinde gelir)
      String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      
      List<dynamic> jsonList = jsonDecode(cleanJson);
      List<Map<String, String>> result = [];

      // Her seçenek için görsel bul
      for (var item in jsonList) {
        String name = item['isim'];
        String query = item['ingilizce_arama_terimi'];
        String imageUrl = await _getUnsplashImage(query);
        
        result.add({
          'isim': name,
          'resimUrl': imageUrl
        });
      }

      return result;
    } catch (e) {
      print("AI Hatası: $e");
      return [];
    }
  }

  // Unsplash'ten rastgele görsel bulma
  Future<String> _getUnsplashImage(String query) async {
    if (unsplashKey == "BURAYA_UNSPLASH_ACCESS_KEY_GELECEK") {
      // API Key yoksa placeholder dön
      return "https://via.placeholder.com/300?text=$query";
    }

    try {
      final url = Uri.parse('https://api.unsplash.com/photos/random?query=$query&client_id=$unsplashKey&orientation=squarish');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['urls']['small']; // Küçük boyutlu resim URL'i
      }
    } catch (e) {
      print("Resim hatası: $e");
    }
    return "https://via.placeholder.com/300?text=$query"; // Hata olursa yedek resim
  }
}