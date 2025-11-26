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
  final String myId = FirebaseAuth.instance.currentUser!.uid;
  int _currentQuestionIndex = 0;
  
  // Benim yerel cevap haritam
  Map<int, int> _myAnswers = {}; 

  // --- WIDGET: TEST BÖLÜMÜ (Üst Kısım) ---
  Widget _buildTestView(AsyncSnapshot<DocumentSnapshot> testSnapshot, Map<String, dynamic> sessionData) {
    if (!testSnapshot.hasData || !testSnapshot.data!.exists) {
      return const Center(child: Text("Test verileri yüklenemedi.", style: TextStyle(color: Colors.white)));
    }

    var testData = testSnapshot.data!.data() as Map<String, dynamic>;
    List<dynamic> questions = testData['sorular'] ?? [];

    if (questions.isEmpty) {
      return const Center(child: Text("Testte soru yok.", style: TextStyle(color: Colors.white)));
    }

    // Karşı tarafın anlık cevaplarını çek
    Map<String, dynamic> otherUserAnswers = sessionData['answers']?[widget.otherUserId] ?? {};

    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(), // Butonlarla kontrol edilecek
      itemCount: questions.length,
      onPageChanged: (index) {
        setState(() {
          _currentQuestionIndex = index;
        });
        // Soru indeksi değişince Firestore'u güncelle
        _updateSessionIndex(index);
      },
      itemBuilder: (context, index) {
        var question = questions[index];
        List<dynamic> options = question['secenekler'] ?? [];
        
        int? mySelectedOption = _myAnswers[index];
        // Karşı tarafın o anki soruya verdiği cevap (string index'ten int'e çevriliyor)
        int? otherSelectedOption = otherUserAnswers['$index'] != null ? int.tryParse(otherUserAnswers['$index'].toString()) : null; 

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Soru İlerlemesi
              Text(
                "Soru ${index + 1} / ${questions.length}", 
                style: const TextStyle(color: Colors.white70, fontSize: 14)
              ),
              const SizedBox(height: 10),

              // Soru Metni
              Expanded(
                child: Text(
                  question['soruMetni'] ?? 'Soru Metni Yüklenemedi.',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.visible,
                ),
              ),
              const SizedBox(height: 20),

              // Seçenekler
              ...options.asMap().entries.map((entry) {
                int optionIndex = entry.key;
                String optionText = entry.value.toString();
                bool isMySelection = mySelectedOption == optionIndex;
                bool isOtherSelection = otherSelectedOption == optionIndex;
                
                // Renk mantığı
                Color bgColor = const Color(0xFF1C1C1E);
                if (isMySelection && isOtherSelection) {
                  bgColor = Colors.green.withOpacity(0.5); // İkisi de aynı
                } else if (isMySelection) {
                  bgColor = const Color(0xFFFF5A5F).withOpacity(0.7); // Benim cevabım
                } else if (isOtherSelection) {
                  bgColor = Colors.blue.withOpacity(0.7); // Karşı tarafın cevabı
                }

                return GestureDetector(
                  onTap: () => _selectAnswer(index, optionIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMySelection ? const Color(0xFFFF5A5F) : Colors.transparent, 
                        width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Seçenek Metni
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        
                        // Cevap İndikatörleri (Profil Resimleri)
                        Row(
                          children: [
                            if (isMySelection) 
                              _buildAnswerIndicator(myId, true),
                            if (isOtherSelection) 
                              _buildAnswerIndicator(widget.otherUserId, false),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 20),

              // Navigasyon Butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (index > 0)
                    TextButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white70),
                      label: const Text("Geri", style: TextStyle(color: Colors.white70)),
                    ),
                  
                  if (index < questions.length - 1)
                    ElevatedButton(
                      onPressed: mySelectedOption != null ? _nextQuestion : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mySelectedOption != null ? const Color(0xFFFF5A5F) : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 25)
                      ),
                      child: const Text("İleri", style: TextStyle(color: Colors.white)),
                    )
                  else
                    ElevatedButton(
                      onPressed: mySelectedOption != null ? _finishSession : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mySelectedOption != null ? Colors.green : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 25)
                      ),
                      child: const Text("Bitir ve Gör", style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET: CEVAP İNDİKATÖRÜ ---
  Widget _buildAnswerIndicator(String userId, bool isMe) {
    String initial = isMe ? (FirebaseAuth.instance.currentUser?.email?[0] ?? 'S').toUpperCase() : widget.otherUserName[0].toUpperCase();
    Color color = isMe ? const Color(0xFFFF5A5F) : Colors.blue;

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
          initial, 
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
  
  // --- WIDGET: CHAT BÖLÜMÜ (Alt Kısım) ---
  Widget _buildChatView() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              "${widget.otherUserName} ile Sohbet", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats').doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(10) // Sadece son 10 mesaj
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: Text("Yükleniyor...", style: TextStyle(color: Colors.grey)));
                
                var docs = snapshot.data!.docs.reversed.toList();
                
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
        constraints: const BoxConstraints(maxWidth: 200), // Mesaj kutusu genişliği
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

  // --- İŞLEMLER (Firebase Güncellemeleri) ---

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

  void _selectAnswer(int questionIndex, int optionIndex) async {
    setState(() {
      _myAnswers[questionIndex] = optionIndex;
    });

    // Firestore'da co-op oturumunu güncelle
    await FirebaseFirestore.instance.collection('coop_sessions').doc(widget.sessionId).set({
      'answers': {
        myId: {
          '$questionIndex': optionIndex, // Firestore'da anahtarlar string olmalı
        }
      }
    }, SetOptions(merge: true));
  }
  
  void _updateSessionIndex(int index) {
    FirebaseFirestore.instance.collection('coop_sessions').doc(widget.sessionId).update({
      'currentQuestionIndex': index,
    });
  }
  
  void _nextQuestion() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void _previousQuestion() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void _finishSession() {
    // TODO: Burada sonuçları hesapla ve sonucu gösteren bir ekrana yönlendir.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Co-op: ${widget.otherUserName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D0D11),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Co-op oturum verilerini dinle
        stream: FirebaseFirestore.instance.collection('coop_sessions').doc(widget.sessionId).snapshots(),
        builder: (context, sessionSnapshot) {
          if (sessionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
          }
          
          if (!sessionSnapshot.hasData || !sessionSnapshot.data!.exists) {
            return const Center(child: Text("Oturum başlatılamadı.", style: TextStyle(color: Colors.white)));
          }
          
          var sessionData = sessionSnapshot.data!.data() as Map<String, dynamic>;
          
          // Uygulama yeniden başlatılırsa kendi cevaplarımı Firestore'dan çek
          _myAnswers = (sessionData['answers']?[myId] as Map? ?? {}).map((k, v) => MapEntry(int.parse(k), v as int));
          
          // Test sorularını çek (FutureBuilder, veri stabil olduğu için daha uygun)
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('testler').doc(widget.testId).get(),
            builder: (context, testSnapshot) {
              if (testSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A5F)));
              }

              // --- BÖLÜNMÜŞ EKRAN GÖRÜNÜMÜ ---
              return Column(
                children: [
                  // TEST BÖLÜMÜ (Ekranın 2/3'ü)
                  Expanded(
                    flex: 2,
                    child: _buildTestView(testSnapshot, sessionData),
                  ),
                  
                  // CHAT BÖLÜMÜ (Ekranın 1/3'ü)
                  Expanded(
                    flex: 1,
                    child: _buildChatView(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}