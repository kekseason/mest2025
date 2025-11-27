import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Şikayet Sebepleri
  static const List<Map<String, dynamic>> reportReasons = [
    {
      'id': 'spam',
      'title': 'Spam',
      'description': 'İstenmeyen veya tekrarlayan mesajlar',
      'icon': Icons.report_gmailerrorred,
    },
    {
      'id': 'harassment',
      'title': 'Taciz veya Zorbalık',
      'description': 'Rahatsız edici, tehditkar veya aşağılayıcı davranış',
      'icon': Icons.mood_bad,
    },
    {
      'id': 'inappropriate_content',
      'title': 'Uygunsuz İçerik',
      'description': 'Cinsel, şiddet içeren veya rahatsız edici içerik',
      'icon': Icons.no_adult_content,
    },
    {
      'id': 'fake_profile',
      'title': 'Sahte Profil',
      'description': 'Başka biri gibi davranan veya sahte bilgiler kullanan',
      'icon': Icons.person_off,
    },
    {
      'id': 'scam',
      'title': 'Dolandırıcılık',
      'description': 'Para isteme, şüpheli linkler veya dolandırıcılık girişimi',
      'icon': Icons.money_off,
    },
    {
      'id': 'underage',
      'title': 'Yaş Altı Kullanıcı',
      'description': '18 yaşından küçük olduğunu düşünüyorum',
      'icon': Icons.child_care,
    },
    {
      'id': 'hate_speech',
      'title': 'Nefret Söylemi',
      'description': 'Irkçı, homofobik veya ayrımcı içerik',
      'icon': Icons.do_not_disturb,
    },
    {
      'id': 'other',
      'title': 'Diğer',
      'description': 'Yukarıdakilerden farklı bir sebep',
      'icon': Icons.more_horiz,
    },
  ];

  // Şikayet Dialog'unu göster
  static Future<bool> showReportDialog({
    required BuildContext context,
    required String reportedUserId,
    required String reportedUserName,
    String? messageId,
    String? chatId,
  }) async {
    String? selectedReason;
    String additionalInfo = "";
    bool isSubmitting = false;

    bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.red, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Kullanıcıyı Şikayet Et",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            reportedUserName,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              // Sebep Listesi
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Şikayet sebebini seç:",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),

                    ...reportReasons.map((reason) {
                      bool isSelected = selectedReason == reason['id'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF5A5F).withOpacity(0.15)
                              : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFFFF5A5F))
                              : null,
                        ),
                        child: ListTile(
                          leading: Icon(
                            reason['icon'] as IconData,
                            color: isSelected ? const Color(0xFFFF5A5F) : Colors.grey,
                          ),
                          title: Text(
                            reason['title'] as String,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFFF5A5F) : Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            reason['description'] as String,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFFFF5A5F))
                              : null,
                          onTap: () {
                            setModalState(() => selectedReason = reason['id'] as String);
                          },
                        ),
                      );
                    }).toList(),

                    // Ek Bilgi
                    if (selectedReason != null) ...[
                      const SizedBox(height: 10),
                      const Text(
                        "Ek bilgi (isteğe bağlı):",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 3,
                        maxLength: 500,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Detayları açıklayabilirsin...",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterStyle: const TextStyle(color: Colors.grey),
                        ),
                        onChanged: (val) => additionalInfo = val,
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Alt Butonlar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  children: [
                    // Bilgi Notu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Şikayetiniz gizli tutulacak. Raporlanan kullanıcı bilgilendirilmeyecektir.",
                              style: TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: selectedReason == null || isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);

                                try {
                                  String? myId = FirebaseAuth.instance.currentUser?.uid;
                                  if (myId == null) throw Exception("Giriş yapmalısınız");

                                  await _firestore.collection('reports').add({
                                    'reporterId': myId,
                                    'reportedUserId': reportedUserId,
                                    'reportedUserName': reportedUserName,
                                    'reason': selectedReason,
                                    'additionalInfo': additionalInfo,
                                    'messageId': messageId,
                                    'chatId': chatId,
                                    'status': 'pending',
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'platform': 'mobile',
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hata: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          disabledBackgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Şikayeti Gönder",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Sonuç mesajı
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text("Şikayetin alındı. En kısa sürede incelenecek."),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    return result ?? false;
  }

  // Hızlı şikayet ve engelle
  static Future<void> reportAndBlock({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String myId,
  }) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 10),
            Text("Şikayet Et ve Engelle", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          "$targetUserName kullanıcısını hem şikayet etmek hem de engellemek istiyor musun?",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Devam", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Şikayet dialogunu aç
    bool reported = await showReportDialog(
      context: context,
      reportedUserId: targetUserId,
      reportedUserName: targetUserName,
    );

    // Şikayet başarılıysa engelle
    if (reported && context.mounted) {
      try {
        await _firestore.collection('users').doc(myId).update({
          'blockedUsers': FieldValue.arrayUnion([targetUserId])
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$targetUserName engellendi"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint("Engelleme hatası: $e");
      }
    }
  }
}

// Kullanıcı Aksiyon Menüsü (Profile veya Chat'te kullanılabilir)
class UserActionMenu extends StatelessWidget {
  final String targetUserId;
  final String targetUserName;
  final VoidCallback? onBlocked;

  const UserActionMenu({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 10),
              Text("Şikayet Et", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text("Engelle", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'report_block',
          child: Row(
            children: [
              Icon(Icons.report, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text("Şikayet Et ve Engelle", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        String? myId = FirebaseAuth.instance.currentUser?.uid;
        if (myId == null) return;

        switch (value) {
          case 'report':
            await ReportService.showReportDialog(
              context: context,
              reportedUserId: targetUserId,
              reportedUserName: targetUserName,
            );
            break;

          case 'block':
            // BlockService'i import etmeli
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text("$targetUserName Engelle", style: const TextStyle(color: Colors.white)),
                content: const Text(
                  "Bu kişi sana mesaj atamayacak ve profilini göremeyecek.",
                  style: TextStyle(color: Colors.grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("İptal", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Engelle", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await FirebaseFirestore.instance.collection('users').doc(myId).update({
                'blockedUsers': FieldValue.arrayUnion([targetUserId])
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$targetUserName engellendi"),
                    backgroundColor: Colors.orange,
                  ),
                );
                onBlocked?.call();
              }
            }
            break;

          case 'report_block':
            await ReportService.reportAndBlock(
              context: context,
              targetUserId: targetUserId,
              targetUserName: targetUserName,
              myId: myId,
            );
            onBlocked?.call();
            break;
        }
      },
    );
  }
}