import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoopSolveScreen extends StatefulWidget {
  final String testId;
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String sessionId;

  const CoopSolveScreen({
    super.key,
    required this.testId,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.sessionId,
  });

  @override
  State<CoopSolveScreen> createState() => _CoopSolveScreenState();
}

class _CoopSolveScreenState extends State<CoopSolveScreen> {
  final PageController _pageController = PageController();
  late String myId;
  int _currentQuestionIndex = 0;
  
  // Benim yerel cevap haritam
  Map<int, int> _myAnswers = {};
  
  // 🔴 YENİ: Test verileri için cache
  Map<String, dynamic>? _testData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadTestData();
  }
  
  void _initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      myId = user.uid;
    } else {
      // Kullanıcı yoksa geri dön
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oturum hatası. Lütfen tekrar giriş yapın.")),
        );
      });
    }
  }
  
  // 🔴 YENİ: Test verilerini bir kere yükle
  Future<void> _loadTestData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('testler')
          .doc(widget.testId)
          .get();
          
      if (doc.exists) {
        setState(() {
          _testData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Test bulunamadı";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Hata: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- WIDGET: TEST BÖLÜMÜ (Üst Kısım) ---
  Widget _buildTestView(Map<String, dynamic> sessionData) {
    if (_testData == null) {
      return const Center(child: Text("Test verileri yüklenemedi.", style: TextStyle(color: Colors.white)));
    }

    // 🔴 DÜZELTİLDİ: 'sorular' yerine 'secenekler' kullanılıyor
    // Co-op modunda seçenekler arasından en sevdiğini seçme mantığı
    List<dynamic> secenekler = _testData!['secenekler'] ?? [];

    if (secenekler.isEmpty) {
      return const Center(child: Text("Testte seçenek yok.", style: TextStyle(color: Colors.white)));
    }

    // Karşı tarafın anlık cevaplarını çek
    Map<String, dynamic> otherUserAnswers = {};
    if (sessionData['answers'] != null && sessionData['answers'][widget.otherUserId] != null) {
      otherUserAnswers = Map<String, dynamic>.from(sessionData['answers'][widget.otherUserId]);
    }

    return Column(
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _testData!['baslik'] ?? 'Test',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Favorilerini seç ve karşılaştır!",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        
        // İlerleme
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _myAnswers.length / secenekler.length,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5A5F)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "${_myAnswers.length}/${secenekler.length}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Seçenekler Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: secenekler.length,
            itemBuilder: (context, index) {
              var secenek = secenekler[index];
              String isim = secenek['isim'] ?? '';
              String resimUrl = secenek['resimUrl'] ?? secenek['resim'] ?? '';
              
              bool isMySelection = _myAnswers.containsKey(index);
              bool isOtherSelection = otherUserAnswers.containsKey('$index');
              
              // Renk mantığı
              Color borderColor = Colors.transparent;
              if (isMySelection && isOtherSelection) {
                borderColor = Colors.green; // İkisi de aynı
              } else if (isMySelection) {
                borderColor = const Color(0xFFFF5A5F); // Benim seçimim
              } else if (isOtherSelection) {
                borderColor = Colors.blue; // Karşı tarafın seçimi
              }

              return GestureDetector(
                onTap: () => _toggleSelection(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: borderColor == Colors.transparent ? 1 : 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Resim
                        Image.network(
                          resimUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                        // Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                        // İsim ve indikatörler
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isim,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (isMySelection)
                                    _buildSmallIndicator(const Color(0xFFFF5A5F), "Sen"),
                                  if (isOtherSelection)
                                    _buildSmallIndicator(Colors.blue, widget.otherUserName.split(' ')[0]),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Seçim işareti
                        if (isMySelection)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5A5F),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Sonuçları Gör butonu
        if (_myAnswers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showResults,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Karşılaştır",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildSmallIndicator(Color color, String name) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- WIDGET: CEVAP İNDİKATÖRÜ ---
  Widget _buildAnswerIndicator(String name, Color color) {
    return Container(
      width: 28, height: 28,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  // --- WIDGET: SOHBET BÖLÜMÜ ---
  Widget _buildChatView() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Sohbet başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  child: Text(
                    widget.otherUserName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "${widget.otherUserName} ile Sohbet", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          
          // Mesajlar
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats').doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text("Yükleniyor...", style: TextStyle(color: Colors.grey)));
                }
                
                var docs = snapshot.data!.docs.reversed.toList();
                
                if (docs.isEmpty) {
                  return const Center(
                    child: Text("Henüz mesaj yok.\nBir şeyler yaz!", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == myId;
                    return _buildMessageBubble(data['text'] ?? '...', isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFF5A5F) : const Color(0xFF0D0D11),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(color: isMe ? Colors.transparent : Colors.white10)
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _buildMessageInput() {
    final TextEditingController controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Yorum yap...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0D0D11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.white10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: const BorderSide(color: Color(0xFFFF5A5F))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(controller);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFFF5A5F)),
            onPressed: () => _sendMessage(controller),
          ),
        ],
      ),
    );
  }

  // --- İŞLEMLER ---

  void _sendMessage(TextEditingController controller) async {
    if (controller.text.trim().isEmpty) return;
    String message = controller.text.trim();
    controller.clear();

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': myId,
      'text': message,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  void _toggleSelection(int index) async {
    setState(() {
      if (_myAnswers.containsKey(index)) {
        _myAnswers.remove(index);
      } else {
        _myAnswers[index] = 1; // Seçildi
      }
    });

    // Firestore'da güncelle
    Map<String, dynamic> answersUpdate = {};
    _myAnswers.forEach((key, value) {
      answersUpdate['$key'] = value;
    });

    await FirebaseFirestore.instance.collection('coop_sessions').doc(widget.sessionId).set({
      'answers': {
        myId: answersUpdate,
      }
    }, SetOptions(merge: true));
  }

  void _showResults() {
    // Sonuçları göster
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('coop_sessions')
              .doc(widget.sessionId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            var sessionData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            Map<String, dynamic> myAnswers = {};
            Map<String, dynamic> otherAnswers = {};
            
            if (sessionData['answers'] != null) {
              myAnswers = Map<String, dynamic>.from(sessionData['answers'][myId] ?? {});
              otherAnswers = Map<String, dynamic>.from(sessionData['answers'][widget.otherUserId] ?? {});
            }
            
            // Ortak seçimleri bul
            Set<String> myKeys = myAnswers.keys.toSet();
            Set<String> otherKeys = otherAnswers.keys.toSet();
            Set<String> commonKeys = myKeys.intersection(otherKeys);
            
            int uyumYuzdesi = myKeys.isEmpty ? 0 : ((commonKeys.length / myKeys.length) * 100).round();
            
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Uyum göstergesi
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: uyumYuzdesi / 100,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            uyumYuzdesi >= 70 ? Colors.green : 
                            uyumYuzdesi >= 40 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            "%$uyumYuzdesi",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text("UYUM", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    "${widget.otherUserName} ile $commonKeys seçimde ortaksınız!",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatBox("Senin", myKeys.length, const Color(0xFFFF5A5F)),
                      const SizedBox(width: 20),
                      _buildStatBox(widget.otherUserName.split(' ')[0], otherKeys.length, Colors.blue),
                      const SizedBox(width: 20),
                      _buildStatBox("Ortak", commonKeys.length, Colors.green),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A5F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Tamam", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatBox(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$count",
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Co-op: ${widget.otherUserName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D0D11),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF0D0D11),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('coop_sessions').doc(widget.sessionId).snapshots(),
        builder: (context, sessionSnapshot) {
          if (sessionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }
          
          if (!sessionSnapshot.hasData || !sessionSnapshot.data!.exists) {
            return const Center(child: Text("Oturum başlatılamadı.", style: TextStyle(color: Colors.white)));
          }
          
          var sessionData = sessionSnapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              // TEST BÖLÜMÜ (Ekranın 2/3'ü)
              Expanded(
                flex: 2,
                child: _buildTestView(sessionData),
              ),
              
              // CHAT BÖLÜMÜ (Ekranın 1/3'ü)
              Expanded(
                flex: 1,
                child: _buildChatView(),
              ),
            ],
          );
        },
      ),
    );
  }
}