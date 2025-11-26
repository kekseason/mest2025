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
      id: map['id'] ?? '0',
      isim: map['isim'] ?? 'İsimsiz',
      resimUrl: map['resim'] ?? '',
    );
  }
}

class Eslesme {
  final String isim;
  final int uyumYuzdesi;
  final String userId;
  final String sehir;

  Eslesme({
    required this.isim, 
    required this.uyumYuzdesi, 
    required this.userId,
    this.sehir = ""
  });
}