import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'welcome_screen.dart';
import 'blocked_users_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Bildirim Tercihleri
  bool _yeniMesajBildirim = true;
  bool _eslesmeBegen = true;
  bool _yeniTestBildirim = true;
  bool _pazarlamaBildirim = false;

  // Gizlilik Ayarları
  bool _profilHerkesGorebilir = true;
  bool _sonGorulmeGoster = true;
  bool _aktifDurumGoster = true;

  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        var settings = data['settings'] as Map<String, dynamic>? ?? {};

        setState(() {
          // Bildirim Tercihleri
          _yeniMesajBildirim = settings['yeniMesajBildirim'] ?? true;
          _eslesmeBegen = settings['eslesmeBildirim'] ?? true;
          _yeniTestBildirim = settings['yeniTestBildirim'] ?? true;
          _pazarlamaBildirim = settings['pazarlamaBildirim'] ?? false;

          // Gizlilik
          _profilHerkesGorebilir = settings['profilHerkesGorebilir'] ?? true;
          _sonGorulmeGoster = settings['sonGorulmeGoster'] ?? true;
          _aktifDurumGoster = settings['aktifDurumGoster'] ?? true;

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Ayarlar yüklenemedi: $e");
    }
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'settings': {
          'yeniMesajBildirim': _yeniMesajBildirim,
          'eslesmeBildirim': _eslesmeBegen,
          'yeniTestBildirim': _yeniTestBildirim,
          'pazarlamaBildirim': _pazarlamaBildirim,
          'profilHerkesGorebilir': _profilHerkesGorebilir,
          'sonGorulmeGoster': _sonGorulmeGoster,
          'aktifDurumGoster': _aktifDurumGoster,
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ayarlar kaydedildi ✓"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============ HESAP SİLME ============
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Hesabı Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Bu işlem geri alınamaz! Hesabınızı sildiğinizde:",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 15),
                _buildDeleteWarningItem("Tüm verileriniz silinecek"),
                _buildDeleteWarningItem("Test sonuçlarınız kaldırılacak"),
                _buildDeleteWarningItem("Sohbetleriniz silinecek"),
                _buildDeleteWarningItem("Eşleşmeleriniz iptal edilecek"),
                _buildDeleteWarningItem("Rozetleriniz kaybolacak"),
                const SizedBox(height: 20),
                const Text(
                  "Onaylamak için şifrenizi girin:",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Şifreniz",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Şifre gerekli")),
                        );
                        return;
                      }

                      setDialogState(() => isDeleting = true);

                      try {
                        // Kullanıcıyı yeniden doğrula
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) throw Exception("Kullanıcı bulunamadı");

                        AuthCredential credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: passwordController.text,
                        );

                        await user.reauthenticateWithCredential(credential);

                        // Firestore verilerini sil
                        await _deleteUserData(user.uid);

                        // Firebase Auth hesabını sil
                        await user.delete();

                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                            (route) => false,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Hesabınız silindi. Hoşça kalın! 👋"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isDeleting = false);
                        String message = "Hata oluştu";
                        if (e.code == 'wrong-password') {
                          message = "Şifre yanlış!";
                        } else if (e.code == 'too-many-requests') {
                          message = "Çok fazla deneme. Lütfen bekleyin.";
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isDeleting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Hesabı Sil", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUserData(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Kullanıcı dökümanını sil
    batch.delete(firestore.collection('users').doc(userId));

    // 2. Kullanıcının turnuva sonuçlarını sil
    var turnuvalar = await firestore
        .collection('turnuvalar')
        .where('odenen', isEqualTo: userId)
        .get();
    for (var doc in turnuvalar.docs) {
      batch.delete(doc.reference);
    }

    // 3. Kullanıcının bildirimlerini sil
    var bildirimler = await firestore
        .collection('bildirimler')
        .where('aliciId', isEqualTo: userId)
        .get();
    for (var doc in bildirimler.docs) {
      batch.delete(doc.reference);
    }

    // 4. Kullanıcının gönderdiği bildirimleri sil
    var gonderilenBildirimler = await firestore
        .collection('bildirimler')
        .where('gonderenId', isEqualTo: userId)
        .get();
    for (var doc in gonderilenBildirimler.docs) {
      batch.delete(doc.reference);
    }

    // 5. Kullanıcının sohbetlerini işaretle (tamamen silmek yerine)
    var chats = await firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .get();
    for (var doc in chats.docs) {
      batch.update(doc.reference, {
        'deletedBy': FieldValue.arrayUnion([userId])
      });
    }

    // 6. Blok listesinden kaldır
    var blockedBy = await firestore
        .collection('users')
        .where('blockedUsers', arrayContains: userId)
        .get();
    for (var doc in blockedBy.docs) {
      batch.update(doc.reference, {
        'blockedUsers': FieldValue.arrayRemove([userId])
      });
    }

    await batch.commit();
  }

  // ============ ÇIKIŞ YAP ============
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Hesabından çıkış yapmak istediğine emin misin?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Çıkış Yap", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============ GERİ BİLDİRİM ============
  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    String selectedType = "Öneri";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Geri Bildirim", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tür seçin:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ["Öneri", "Hata", "Şikayet", "Diğer"].map((type) {
                    bool isSelected = selectedType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF5A5F),
                      backgroundColor: const Color(0xFF2C2C2E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                      onSelected: (selected) {
                        setDialogState(() => selectedType = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: feedbackController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Düşüncelerinizi yazın...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (feedbackController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lütfen bir şeyler yazın")),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('feedback').add({
                    'userId': _userId,
                    'type': selectedType,
                    'message': feedbackController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                    'platform': 'mobile',
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Geri bildiriminiz alındı. Teşekkürler! 💜"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hata: $e")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A5F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Gönder", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D11),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Ayarlar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ BİLDİRİM TERCİHLERİ ============
          _buildSectionTitle("Bildirim Tercihleri", Icons.notifications_outlined),
          _buildSettingsCard([
            _buildSwitchTile(
              "Yeni Mesaj",
              "Birisi sana mesaj attığında bildir",
              _yeniMesajBildirim,
              (val) => setState(() => _yeniMesajBildirim = val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              "Eşleşme & Beğeni",
              "Biriyle eşleştiğinde veya beğenildiğinde",
              _eslesmeBegen,
              (val) => setState(() => _eslesmeBegen = val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              "Yeni Testler",
              "İlgini çekebilecek yeni testler eklendiğinde",
              _yeniTestBildirim,
              (val) => setState(() => _yeniTestBildirim = val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              "Kampanya & Duyurular",
              "Özel fırsatlar ve haberler",
              _pazarlamaBildirim,
              (val) => setState(() => _pazarlamaBildirim = val),
            ),
          ]),

          const SizedBox(height: 25),

          // ============ GİZLİLİK AYARLARI ============
          _buildSectionTitle("Gizlilik", Icons.lock_outline),
          _buildSettingsCard([
            _buildSwitchTile(
              "Profilim Herkese Açık",
              "Kapalıysa sadece eşleşmeler görür",
              _profilHerkesGorebilir,
              (val) => setState(() => _profilHerkesGorebilir = val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              "Son Görülme",
              "Ne zaman çevrimiçi olduğunu göster",
              _sonGorulmeGoster,
              (val) => setState(() => _sonGorulmeGoster = val),
            ),
            _buildDivider(),
            _buildSwitchTile(
              "Aktif Durumu Göster",
              "Çevrimiçi olduğunda yeşil nokta",
              _aktifDurumGoster,
              (val) => setState(() => _aktifDurumGoster = val),
            ),
            _buildDivider(),
            _buildNavigationTile(
              "Engellenen Kullanıcılar",
              Icons.block,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 25),

          // ============ DESTEK ============
          _buildSectionTitle("Destek", Icons.help_outline),
          _buildSettingsCard([
            _buildNavigationTile(
              "Yardım & SSS",
              Icons.question_answer_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
            _buildDivider(),
            _buildNavigationTile(
              "Geri Bildirim Gönder",
              Icons.feedback_outlined,
              _showFeedbackDialog,
            ),
            _buildDivider(),
            _buildNavigationTile(
              "Bize Ulaşın",
              Icons.mail_outline,
              () => _launchEmail(),
            ),
          ]),

          const SizedBox(height: 25),

          // ============ YASAL ============
          _buildSectionTitle("Yasal", Icons.description_outlined),
          _buildSettingsCard([
            _buildNavigationTile(
              "Gizlilik Politikası",
              Icons.privacy_tip_outlined,
              () => _launchUrl("https://mestapp.com/privacy"),
            ),
            _buildDivider(),
            _buildNavigationTile(
              "Kullanım Koşulları",
              Icons.article_outlined,
              () => _launchUrl("https://mestapp.com/terms"),
            ),
          ]),

          const SizedBox(height: 25),

          // ============ HESAP İŞLEMLERİ ============
          _buildSectionTitle("Hesap", Icons.person_outline),
          _buildSettingsCard([
            _buildNavigationTile(
              "Çıkış Yap",
              Icons.logout,
              _showLogoutDialog,
              color: Colors.orange,
            ),
            _buildDivider(),
            _buildNavigationTile(
              "Hesabı Sil",
              Icons.delete_forever,
              _showDeleteAccountDialog,
              color: Colors.red,
            ),
          ]),

          const SizedBox(height: 30),

          // Kaydet Butonu
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A5F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text(
                "Ayarları Kaydet",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Versiyon
          Center(
            child: Text(
              "Mest v1.0.0",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5A5F), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFFF5A5F),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildNavigationTile(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white, size: 22),
      title: Text(
        title,
        style: TextStyle(color: color ?? Colors.white, fontSize: 15),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'destek@mestapp.com',
      query: 'subject=Mest Uygulaması Desteği',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}