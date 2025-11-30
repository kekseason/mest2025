import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ============ PAYLAŞIM SERVİSİ ============
class ShareService {
  // Deep link base URL (Firebase Dynamic Links veya kendi sunucun)
  static const String _baseUrl = "https://mest.app/test/";
  static const String _inviteUrl = "https://mest.app/invite/";

  // ============ TEST SONUCU PAYLAŞIMI ============
  static Future<void> shareTestResult({
    required BuildContext context,
    required String testId,
    required String testTitle,
    required String winnerName,
    String? winnerImageUrl,
    int? uyumYuzdesi,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => ShareBottomSheet(
        testId: testId,
        testTitle: testTitle,
        winnerName: winnerName,
        winnerImageUrl: winnerImageUrl,
        uyumYuzdesi: uyumYuzdesi,
      ),
    );
  }

  // ============ ARKADAŞ DAVET LİNKİ ============
  static Future<String> generateInviteLink(String userId) async {
    // Kullanıcının referans kodunu al veya oluştur
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    String? referralCode = (userDoc.data() as Map<String, dynamic>?)?['referralCode'];
    
    if (referralCode == null) {
      // Yeni referans kodu oluştur
      referralCode = _generateReferralCode(userId);
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'referralCode': referralCode,
      });
    }

    return "$_inviteUrl$referralCode";
  }

  static String _generateReferralCode(String userId) {
    // Kullanıcı ID'sinin son 6 karakteri + rastgele 4 karakter
    String base = userId.length > 6 ? userId.substring(userId.length - 6) : userId;
    String random = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return "${base.toUpperCase()}$random";
  }

  // ============ TEST DAVET LİNKİ ============
  static String generateTestLink(String testId) {
    return "$_baseUrl$testId";
  }

  // ============ SOSYAL MEDYA PAYLAŞIMI ============
  static Future<void> shareToSocial({
    required String text,
    String? imageUrl,
  }) async {
    await Share.share(text);
  }

  // ============ LİNK KOPYALAMA ============
  static Future<void> copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check, color: Colors.white),
              SizedBox(width: 10),
              Text("Link kopyalandı!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ============ REFERANS KONTROLÜ ============
  static Future<void> checkAndApplyReferral(String userId, String? referralCode) async {
    if (referralCode == null || referralCode.isEmpty) return;

    try {
      // Referans kodunun sahibini bul
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      String referrerId = query.docs.first.id;
      
      // Kendi kendine referans olamaz
      if (referrerId == userId) return;

      // Daha önce referans kullanılmış mı kontrol et
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if ((userDoc.data() as Map<String, dynamic>?)?['usedReferral'] == true) return;

      // Her iki tarafa da bonus ver
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Yeni kullanıcıya bonus
      batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
        'usedReferral': true,
        'referredBy': referrerId,
        'totalXP': FieldValue.increment(100), // 100 XP bonus
      });

      // Davet eden kullanıcıya bonus
      batch.update(FirebaseFirestore.instance.collection('users').doc(referrerId), {
        'referralCount': FieldValue.increment(1),
        'totalXP': FieldValue.increment(200), // 200 XP bonus
      });

      await batch.commit();
    } catch (e) {
      debugPrint("Referans uygulama hatası: $e");
    }
  }
}

// ============ PAYLAŞIM BOTTOM SHEET ============
class ShareBottomSheet extends StatefulWidget {
  final String testId;
  final String testTitle;
  final String winnerName;
  final String? winnerImageUrl;
  final int? uyumYuzdesi;

  const ShareBottomSheet({
    super.key,
    required this.testId,
    required this.testTitle,
    required this.winnerName,
    this.winnerImageUrl,
    this.uyumYuzdesi,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    String shareLink = ShareService.generateTestLink(widget.testId);
    String shareText = "🏆 Mest'te \"${widget.testTitle}\" testinde benim favorim: ${widget.winnerName}!\n\nSen de dene: $shareLink";

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık
            const Text(
              "Sonucunu Paylaş",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Paylaşım kartı önizleme
            RepaintBoundary(
              key: _shareCardKey,
              child: _buildShareCard(),
            ),
            const SizedBox(height: 25),

            // Paylaşım butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: Icons.copy,
                  label: "Kopyala",
                  color: Colors.grey,
                  onTap: () => ShareService.copyToClipboard(context, shareLink),
                ),
                _buildShareButton(
                  icon: Icons.share,
                  label: "Paylaş",
                  color: const Color(0xFFFF5A5F),
                  onTap: () => _shareAsText(shareText),
                ),
                _buildShareButton(
                  icon: Icons.image,
                  label: "Resim",
                  color: Colors.purple,
                  onTap: _shareAsImage,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sosyal medya butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  "WhatsApp",
                  Colors.green,
                  Icons.chat,
                  () => _shareToWhatsApp(shareText),
                ),
                const SizedBox(width: 15),
                _buildSocialButton(
                  "Twitter",
                  Colors.blue,
                  Icons.alternate_email,
                  () => _shareToTwitter(shareText),
                ),
                const SizedBox(width: 15),
                _buildSocialButton(
                  "Instagram",
                  Colors.pink,
                  Icons.camera_alt,
                  () => _shareToInstagram(),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Logo
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Mest",
                style: TextStyle(
                  color: Color(0xFFFF5A5F),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 5),
              Text("🎯", style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 15),

          // Test başlığı
          Text(
            widget.testTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),

          // Kazanan
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.winnerImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.winnerImageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[800],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 15),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Benim Favorim:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.winnerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.uyumYuzdesi != null) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "💚 %${widget.uyumYuzdesi} Uyumlu eşleşmeler bulundu!",
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 15),
          const Text(
            "Sen de dene! mest.app",
            style: TextStyle(color: Color(0xFFFF5A5F), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSocialButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsText(String text) async {
    await Share.share(text);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareAsImage() async {
    setState(() => _isGenerating = true);

    try {
      // Widget'ı resme çevir
      RenderRepaintBoundary boundary = _shareCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Geçici dosyaya kaydet
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/mest_result.png');
      await file.writeAsBytes(pngBytes);

      // Paylaş
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Mest'te test sonucum! 🎯",
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Resim paylaşım hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resim oluşturulamadı"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareToWhatsApp(String text) async {
    final url = "whatsapp://send?text=${Uri.encodeComponent(text)}";
    await Share.share(text); // Fallback
  }

  Future<void> _shareToTwitter(String text) async {
    final url = "https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}";
    await Share.share(text); // Fallback
  }

  Future<void> _shareToInstagram() async {
    // Instagram için resim paylaşımı gerekir
    await _shareAsImage();
  }
}

// ============ ARKADAŞ DAVET EKRANI ============
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  String? _inviteLink;
  int _referralCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Davet linkini al
      _inviteLink = await ShareService.generateInviteLink(userId);

      // Referans sayısını al
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      _referralCount = (doc.data() as Map<String, dynamic>?)?['referralCount'] ?? 0;

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Arkadaşlarını Davet Et",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header resim
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF5A5F).withOpacity(0.8),
                          const Color(0xFFFF8A8E).withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 70),
                  ),
                  const SizedBox(height: 25),

                  // Başlık
                  const Text(
                    "Arkadaşını Davet Et,\nÖdül Kazan!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Açıklama
                  Text(
                    "Her başarılı davet için sen 200 XP, arkadaşın 100 XP kazanır!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 15),
                  ),
                  const SizedBox(height: 30),

                  // İstatistik
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              "$_referralCount",
                              style: const TextStyle(
                                color: Color(0xFFFF5A5F),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "Davet Edildi",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.white12),
                        Column(
                          children: [
                            Text(
                              "+${_referralCount * 200}",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "Kazanılan XP",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Davet linki
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _inviteLink ?? "Yükleniyor...",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () {
                            if (_inviteLink != null) {
                              ShareService.copyToClipboard(context, _inviteLink!);
                            }
                          },
                          icon: const Icon(Icons.copy, color: Color(0xFFFF5A5F)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Paylaş butonu
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_inviteLink != null) {
                          Share.share(
                            "Mest'e katıl! Eğlenceli testler çöz, benzer zevklere sahip insanlarla tanış! 🎯\n\n$_inviteLink",
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text(
                        "Arkadaşlarını Davet Et",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Nasıl çalışır
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Nasıl Çalışır?",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildHowItWorksStep(
                    number: "1",
                    title: "Linkini Paylaş",
                    description: "Arkadaşlarınla davet linkini paylaş",
                    icon: Icons.link,
                  ),
                  _buildHowItWorksStep(
                    number: "2",
                    title: "Arkadaşın Katılır",
                    description: "Arkadaşın linke tıklayıp hesap oluşturur",
                    icon: Icons.person_add,
                  ),
                  _buildHowItWorksStep(
                    number: "3",
                    title: "Ödülü Kazan",
                    description: "İkiniz de XP kazanırsınız!",
                    icon: Icons.card_giftcard,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHowItWorksStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A5F).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFFFF5A5F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(icon, color: Colors.grey, size: 24),
        ],
      ),
    );
  }
}