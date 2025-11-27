// Dosya: lib/screens/models.dart

class Secenek {
  final String id;
  final String isim;
  final String resimUrl;

  Secenek({
    required this.id,
    required this.isim,
    required this.resimUrl,
  });

  factory Secenek.fromMap(Map<String, dynamic> map) {
    return Secenek(
      id: map['id']?.toString() ?? '0',
      isim: map['isim'] ?? 'İsimsiz',
      // 🔴 HATA DÜZELTİLDİ: Admin panelinde 'resim' kaydediliyor ama burada 'resimUrl' okunuyordu
      // Her iki alan adını da kontrol ediyoruz
      resimUrl: map['resimUrl'] ?? map['resim'] ?? '',
    );
  }

  // Firestore'a kaydetmek için Map'e çevirme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isim': isim,
      'resimUrl': resimUrl,
    };
  }
}

class Eslesme {
  final String isim;
  final int uyumYuzdesi;
  final String userId;
  final String sehir;
  final String? photoUrl;

  Eslesme({
    required this.isim, 
    required this.uyumYuzdesi, 
    required this.userId,
    this.sehir = "",
    this.photoUrl,
  });
}

// Test modeli - opsiyonel kullanım için
class MestTest {
  final String id;
  final String baslik;
  final String category;
  final String? kapakResmi;
  final List<Secenek> secenekler;
  final int playCount;
  final bool aktifMi;
  final bool isEvent;
  final DateTime? eventDate;

  MestTest({
    required this.id,
    required this.baslik,
    required this.category,
    this.kapakResmi,
    required this.secenekler,
    this.playCount = 0,
    this.aktifMi = true,
    this.isEvent = false,
    this.eventDate,
  });

  factory MestTest.fromFirestore(String docId, Map<String, dynamic> data) {
    List<Secenek> secenekListesi = [];
    if (data['secenekler'] != null) {
      secenekListesi = (data['secenekler'] as List)
          .map((e) => Secenek.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return MestTest(
      id: docId,
      baslik: data['baslik'] ?? 'İsimsiz Test',
      category: data['category'] ?? 'Genel',
      kapakResmi: data['kapakResmi'],
      secenekler: secenekListesi,
      playCount: data['playCount'] ?? 0,
      aktifMi: data['aktif_mi'] ?? false,
      isEvent: data['isEvent'] ?? false,
      eventDate: data['eventDate'] != null 
          ? (data['eventDate'] as dynamic).toDate() 
          : null,
    );
  }
}