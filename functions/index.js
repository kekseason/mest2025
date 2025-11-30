const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

setGlobalOptions({ 
  region: "europe-west1",
  maxInstances: 10 
});

// ============ ETKİNLİK SÜRESİ KONTROL ============
exports.checkExpiredEvents = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async (event) => {
    console.log("Süresi biten etkinlikler kontrol ediliyor...");

    try {
      const now = admin.firestore.Timestamp.now();

      const expiredEvents = await db
        .collection("events")
        .where("endTime", "<", now)
        .where("isConverted", "==", false)
        .where("status", "==", "active")
        .get();

      if (expiredEvents.empty) {
        console.log("Süresi biten etkinlik yok");
        return null;
      }

      console.log(`${expiredEvents.size} etkinlik dönüştürülecek`);

      const batch = db.batch();

      for (const eventDoc of expiredEvents.docs) {
        const eventData = eventDoc.data();
        const testId = eventData.testId;

        batch.update(eventDoc.ref, {
          isConverted: true,
          status: "completed",
          convertedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (testId) {
          const testRef = db.collection("testler").doc(testId);
          batch.update(testRef, {
            isEventTest: false,
            eventId: null,
            convertedFromEvent: true,
            convertedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        console.log(`Etkinlik dönüştürüldü: ${eventDoc.id}`);
      }

      await batch.commit();
      console.log("Tüm etkinlikler dönüştürüldü");

      return null;
    } catch (error) {
      console.error("Etkinlik kontrol hatası:", error);
      return null;
    }
  }
);

// ============ YENİ ETKİNLİK OLUŞTURULDUĞUNDA ============
exports.onEventCreated = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const eventData = snapshot.data();
    const eventId = event.params.eventId;

    console.log(`Yeni etkinlik oluşturuldu: ${eventId}`);

    try {
      const testId = eventData.testId;
      if (testId) {
        await db.collection("testler").doc(testId).update({
          isEventTest: true,
          eventId: eventId,
          eventStartTime: eventData.startTime,
          eventEndTime: eventData.endTime,
        });
        console.log(`Test etkinlik testi olarak işaretlendi: ${testId}`);
      }

      await snapshot.ref.update({
        isConverted: false,
        status: "active",
        participantCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    } catch (error) {
      console.error("Etkinlik oluşturma hatası:", error);
      return null;
    }
  }
);

// ============ ETKİNLİK BAŞLADIĞINDA BİLDİRİM ============
exports.notifyEventStart = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Europe/Istanbul",
  },
  async (event) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const oneMinuteAgo = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 60 * 1000)
      );

      const startingEvents = await db
        .collection("events")
        .where("startTime", ">", oneMinuteAgo)
        .where("startTime", "<=", now)
        .where("status", "==", "active")
        .where("notifiedStart", "==", false)
        .get();

      if (startingEvents.empty) return null;

      for (const eventDoc of startingEvents.docs) {
        const eventData = eventDoc.data();
        const participants = eventData.participants || [];

        for (const userId of participants) {
          const userDoc = await db.collection("users").doc(userId).get();
          if (!userDoc.exists) continue;

          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;

          if (fcmToken) {
            try {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: "🎉 Etkinlik Başladı!",
                  body: `"${eventData.title}" etkinliği şimdi başladı!`,
                },
                data: {
                  type: "event_start",
                  eventId: eventDoc.id,
                  testId: eventData.testId || "",
                },
              });
            } catch (e) {
              console.error("Bildirim hatası:", e);
            }
          }
        }

        await eventDoc.ref.update({ notifiedStart: true });
      }

      return null;
    } catch (error) {
      console.error("Etkinlik başlangıç bildirimi hatası:", error);
      return null;
    }
  }
);

// ============ ETKİNLİK BİTMEDEN 10 DAKİKA ÖNCE UYARI ============
exports.notifyEventEnding = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async (event) => {
    try {
      const tenMinutesLater = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 10 * 60 * 1000)
      );
      const fiveMinutesLater = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 5 * 60 * 1000)
      );

      const endingEvents = await db
        .collection("events")
        .where("endTime", ">", fiveMinutesLater)
        .where("endTime", "<=", tenMinutesLater)
        .where("status", "==", "active")
        .where("notifiedEnding", "==", false)
        .get();

      if (endingEvents.empty) return null;

      for (const eventDoc of endingEvents.docs) {
        const eventData = eventDoc.data();
        const participants = eventData.participants || [];

        for (const userId of participants) {
          const userDoc = await db.collection("users").doc(userId).get();
          if (!userDoc.exists) continue;

          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;

          if (fcmToken) {
            try {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: "⏰ Etkinlik Bitiyor!",
                  body: `"${eventData.title}" 10 dakika içinde bitiyor!`,
                },
                data: {
                  type: "event_ending",
                  eventId: eventDoc.id,
                  testId: eventData.testId || "",
                },
              });
            } catch (e) {
              console.error("Bildirim hatası:", e);
            }
          }
        }

        await eventDoc.ref.update({ notifiedEnding: true });
      }

      return null;
    } catch (error) {
      console.error("Etkinlik bitiş uyarısı hatası:", error);
      return null;
    }
  }
);

// ============ RESİM PROXY FONKSİYONU ============
exports.imageProxy = onRequest(
  {
    region: "europe-west1",
    maxInstances: 10,
  },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', '*');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const imageUrl = req.query.url;

    if (!imageUrl) {
      return res.status(400).send("URL parametresi eksik.");
    }

    try {
      const response = await axios.get(imageUrl, { 
          responseType: "arraybuffer",
          headers: { 
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
            'Referer': new URL(imageUrl).origin,
          },
          timeout: 8000
      });

      res.set("Cache-Control", "public, max-age=86400"); 
      res.set("Content-Type", response.headers["content-type"] || 'image/jpeg');
      res.send(response.data);

    } catch (error) {
      console.error("Proxy Hatası:", error.message);
      res.redirect(302, "https://placehold.co/600x600/1c1c1e/FFF?text=Resim+Yok");
    }
  }
);

// ============ GÜVENLİ AI TEST OLUŞTURUCU (GELİŞTİRİLMİŞ + ÖZEL PROMPT) ============
exports.generateAiTest = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 540,
    memory: "512MiB",
    cors: true, 
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    const { topic, count, customPrompt } = req.body;

    // --- API ANAHTARLARI ---
    const GEMINI_API_KEY = "AIzaSyDPCuJJjkB_GCPkIkRyubEUAwLHh8944fE"; 
    const GOOGLE_SEARCH_KEY = "AIzaSyAxE7quwjIzMwWxaabVMN2pkHRNKan_BiU"; 
    const SEARCH_ENGINE_ID = "d542295c561dd4ffc"; 
    const PROXY_BASE_URL = "https://imageproxy-n5yij6rjfq-ew.a.run.app"; 

    if (!topic) return res.status(400).json({ error: "Topic gerekli" });

    // --- SÜPER GELİŞTİRİLMİŞ URL KONTROL FONKSİYONU ---
    const getWorkingImageUrl = async (items, itemName) => {
        // Güvenilir siteler (Direkt kabul et)
        const trustedDomains = [
            'wikimedia.org', 'wikipedia.org', 'upload.wikimedia',
            'staticflickr.com', 'pexels.com', 'unsplash.com',
            'imgur.com', 'i.imgur.com', 'cdn.pixabay.com',
            'images.pexels.com', 'images.unsplash.com',
            'lezzet.blob', 'yemek.com', 'nefisyemek', 'tarif',
            'migros.com.tr', 'carrefoursa.com', 'a101.com.tr',
            'bim.com.tr', 'sokmarket.com.tr', 'trendyol.com',
            'hepsiburada.com', 'n11.com', 'gittigidiyor.com',
            'ulker.com.tr', 'eti.com.tr', 'nestle.com.tr',
            'imdb.com', 'themoviedb.org', 'image.tmdb.org'
        ];
        
        // Kara liste (Kesinlikle çalışmaz)
        const blacklistedDomains = [
            'tiktok.com', 'facebook.com', 'instagram.com', 'pinterest',
            'gettyimages', 'shutterstock', 'istockphoto', 'alamy.com',
            'dreamstime.com', 'depositphotos', 'stock.adobe', '123rf.com',
            'vectorstock', 'canva.com', 'freepik.com', 'istock.',
            'adobe.com', 'gstatic.com', 'googleusercontent'
        ];
        
        // Resim uzantıları
        const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
        
        // 1. Önce güvenilir sitelerden ara
        for (const item of items) {
            const url = item.link;
            const lowerUrl = url.toLowerCase();
            
            if (trustedDomains.some(domain => lowerUrl.includes(domain))) {
                console.log(`✅ [${itemName}] Güvenilir site: ${url.substring(0, 60)}...`);
                return url;
            }
        }
        
        // 2. Resim uzantısı olan ve kara listede olmayan URL'leri dene
        for (const item of items) {
            const url = item.link;
            const lowerUrl = url.toLowerCase();
            
            // Kara listede mi?
            if (blacklistedDomains.some(domain => lowerUrl.includes(domain))) {
                continue;
            }
            
            // Dosya uzantısı resim mi?
            const hasImageExtension = imageExtensions.some(ext => lowerUrl.includes(ext));
            if (!hasImageExtension) {
                continue;
            }
            
            // HEAD request ile kontrol
            try {
                const response = await axios.head(url, { 
                    timeout: 3000,
                    headers: { 
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        'Accept': 'image/*'
                    }
                });
                
                const contentType = response.headers['content-type'] || '';
                const contentLength = parseInt(response.headers['content-length'] || '0');
                
                // Content-Type resim mi ve boyutu 5KB'dan büyük mü?
                if (contentType.startsWith('image/') && contentLength > 5000) {
                    console.log(`✅ [${itemName}] Çalışan resim: ${url.substring(0, 60)}...`);
                    return url;
                }
            } catch (e) {
                continue;
            }
        }
        
        // 3. Kara listede olmayan herhangi bir resmi dene (son şans)
        for (const item of items) {
            const url = item.link;
            const lowerUrl = url.toLowerCase();
            
            if (blacklistedDomains.some(domain => lowerUrl.includes(domain))) {
                continue;
            }
            
            // GET request ile gerçek kontrol
            try {
                const response = await axios.get(url, { 
                    timeout: 4000,
                    responseType: 'arraybuffer',
                    maxContentLength: 50000,
                    headers: { 
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        'Accept': 'image/*'
                    }
                });
                
                const contentType = response.headers['content-type'] || '';
                
                if (contentType.startsWith('image/') && response.data.length > 5000) {
                    console.log(`✅ [${itemName}] GET ile onaylandı: ${url.substring(0, 60)}...`);
                    return url;
                }
            } catch (e) {
                continue;
            }
        }
        
        // 4. Thumbnail URL'sini dene
        for (const item of items) {
            if (item.image && item.image.thumbnailLink) {
                console.log(`⚠️ [${itemName}] Thumbnail kullanılıyor`);
                return item.image.thumbnailLink;
            }
        }
        
        // 5. Hiçbiri çalışmadı
        console.log(`❌ [${itemName}] Resim bulunamadı!`);
        return null;
    };

    try {
      console.log(`🚀 AI Test Başlıyor: "${topic}" (${count} adet)`);
      if (customPrompt) {
        console.log(`📝 Özel talimat: "${customPrompt}"`);
      }

      // 1. GEMINI API
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
      
      // Dinamik prompt oluştur
      const prompt = `
        Bana "${topic}" konusuyla ilgili ${count || 32} adet seçenek listele.
        
        ${customPrompt ? `ÖZEL TALİMAT (BU TALİMATI KESİNLİKLE UYGULA): ${customPrompt}` : ''}
        
        Sadece JSON formatında cevap ver, başka hiçbir şey yazma.
        Format: [{"isim": "Örnek İsim", "arama_terimi": "google görsel arama terimi"}]
        
        "arama_terimi" için kurallar (en iyi resmi bulmak için):
        - Yemek/içecek: "ürün adı yemek fotoğrafı" (örn: "mercimek çorbası yemek fotoğrafı")
        - Şekerleme/atıştırmalık: "ürün adı paket ambalaj ürün" (örn: "ülker çikolata paket ürün")
        - Film/dizi: "film adı movie poster" (örn: "inception movie poster 2010")
        - Kişi/ünlü: "kişi adı portre fotoğraf" (örn: "tarkan şarkıcı fotoğraf")
        - Marka/ürün: "marka adı logo ürün resmi" (örn: "eti browni ürün kutu")
        - Oyun: "oyun adı game cover art" (örn: "gta v game cover art")
        - Araba: "araba marka model fotoğraf" (örn: "bmw m3 2023 fotoğraf")
        - Dizi: "dizi adı tv series poster" (örn: "breaking bad tv series poster")
        
        Her zaman en tanınabilir ve net görseli getirecek spesifik arama terimini kullan.
        Genel terimlerden kaçın, mümkün olduğunca spesifik ol.
      `;

      const geminiResponse = await axios.post(geminiUrl, { 
        contents: [{ parts: [{ text: prompt }] }] 
      }, {
        timeout: 60000 // 60 saniye
      });
      
      const aiText = geminiResponse.data.candidates[0].content.parts[0].text;
      const cleanJson = aiText.replace(/```json/g, '').replace(/```/g, '').trim();
      const jsonList = JSON.parse(cleanJson);
      
      console.log(`📝 Gemini ${jsonList.length} seçenek üretti`);

      // 2. GOOGLE SEARCH - Her seçenek için paralel arama
      const resultPromises = jsonList.map(async (item, index) => {
        // Rate limiting için küçük gecikme
        await new Promise(resolve => setTimeout(resolve, index * 150));
        
        try {
          const searchUrl = `https://www.googleapis.com/customsearch/v1`;
          const searchParams = {
            q: item.arama_terimi,
            cx: SEARCH_ENGINE_ID,
            key: GOOGLE_SEARCH_KEY,
            searchType: "image",
            num: 10,
            safe: "active",
            imgType: "photo",
            imgSize: "large"
          };

          const searchRes = await axios.get(searchUrl, { 
            params: searchParams,
            timeout: 15000 // 15 saniye
          });
          
          // Varsayılan placeholder
          let finalImageUrl = `https://placehold.co/600x600/2a2a2e/FF5A5F?text=${encodeURIComponent(item.isim.substring(0, 12))}`;
          
          if (searchRes.data.items && searchRes.data.items.length > 0) {
            const validUrl = await getWorkingImageUrl(searchRes.data.items, item.isim);
            
            if (validUrl) {
              // Proxy ile sarmalayarak gönder
              finalImageUrl = `${PROXY_BASE_URL}/?url=${encodeURIComponent(validUrl)}`;
            }
          } else {
            console.log(`⚠️ [${item.isim}] Google sonuç döndürmedi`);
          }

          return {
            id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
            isim: item.isim,
            resimUrl: finalImageUrl,
            secilmeSayisi: 0
          };

        } catch (err) {
          console.error(`❌ [${item.isim}] Arama hatası:`, err.message);
          return { 
            id: Date.now().toString() + Math.random().toString(36).substr(2, 9), 
            isim: item.isim, 
            resimUrl: `https://placehold.co/600x600/2a2a2e/FF5A5F?text=${encodeURIComponent(item.isim.substring(0, 12))}`, 
            secilmeSayisi: 0 
          };
        }
      });

      const finalResults = await Promise.all(resultPromises);
      
      // Başarılı resimleri say
      const successCount = finalResults.filter(r => !r.resimUrl.includes('placehold.co')).length;
      console.log(`✅ Tamamlandı: ${successCount}/${finalResults.length} resim bulundu`);
      
      res.status(200).json({ success: true, data: finalResults });

    } catch (error) {
      console.error("❌ AI Hatası:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ============ BİLDİRİM FONKSİYONLARI ============

// Yeni eşleşme bildirimi
exports.onNewMatch = onDocumentCreated(
  "matches/{matchId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const matchData = snapshot.data();
    const users = matchData.users || [];

    if (users.length < 2) return null;

    try {
      for (const userId of users) {
        const otherUserId = users.find(id => id !== userId);
        const otherUserDoc = await db.collection("users").doc(otherUserId).get();
        const otherUserName = otherUserDoc.exists ? otherUserDoc.data().name : "Birisi";

        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) continue;

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) continue;

        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: "🎉 Yeni Eşleşme!",
              body: `${otherUserName} ile eşleştin! Hemen sohbete başla.`,
            },
            data: {
              type: "match",
              targetId: event.params.matchId,
            },
          });
          console.log(`✅ Eşleşme bildirimi gönderildi: ${userId}`);
        } catch (e) {
          console.error("Bildirim hatası:", e);
        }

        // Firestore'a da kaydet
        await db.collection("notifications").add({
          receiverId: userId,
          title: "🎉 Yeni Eşleşme!",
          body: `${otherUserName} ile eşleştin!`,
          type: "match",
          targetId: event.params.matchId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error("Eşleşme bildirimi hatası:", error);
    }

    return null;
  }
);

// Yeni mesaj bildirimi
exports.onNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const text = messageData.text || "Yeni mesaj";
    const chatId = event.params.chatId;

    try {
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      const participants = chatData.users || chatData.participants || [];

      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data().name : "Birisi";

      const receivers = participants.filter(id => id !== senderId);

      for (const receiverId of receivers) {
        const receiverDoc = await db.collection("users").doc(receiverId).get();
        if (!receiverDoc.exists) continue;

        const fcmToken = receiverDoc.data().fcmToken;
        if (!fcmToken) continue;

        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: senderName,
              body: text.length > 50 ? text.substring(0, 50) + "..." : text,
            },
            data: {
              type: "message",
              targetId: chatId,
            },
          });
        } catch (e) {
          console.error("Mesaj bildirimi hatası:", e);
        }
      }
    } catch (error) {
      console.error("Mesaj bildirimi hatası:", error);
    }

    return null;
  }
);

// Test onay/red bildirimi
exports.onTestStatusChange = onDocumentUpdated(
  "pending_tests/{testId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return null;

    const userId = after.createdBy;
    const testTitle = after.baslik || "Test";

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) return null;

      const fcmToken = userDoc.data().fcmToken;
      
      let title, body, type;

      if (after.status === "approved") {
        title = "✅ Test Onaylandı!";
        body = `"${testTitle}" testiniz onaylandı ve yayınlandı!`;
        type = "test_approved";
      } else if (after.status === "rejected") {
        title = "❌ Test Reddedildi";
        body = `"${testTitle}" testiniz reddedildi. Sebep: ${after.rejectionReason || "Belirtilmedi"}`;
        type = "test_rejected";
      } else {
        return null;
      }

      if (fcmToken) {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: { type, targetId: event.params.testId },
          });
        } catch (e) {
          console.error("Test bildirimi hatası:", e);
        }
      }

      // Firestore'a kaydet
      await db.collection("notifications").add({
        receiverId: userId,
        title,
        body,
        type,
        targetId: event.params.testId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error("Test durumu bildirimi hatası:", error);
    }

    return null;
  }
);

// Streak hatırlatma (Her gün 20:00)
exports.streakReminder = onSchedule(
  {
    schedule: "0 20 * * *",
    timeZone: "Europe/Istanbul",
  },
  async (event) => {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const usersSnapshot = await db.collection("users")
        .where("currentStreak", ">", 0)
        .get();

      let sentCount = 0;

      for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) continue;

        const lastActive = userData.lastActiveDate?.toDate();
        if (!lastActive) continue;

        const lastActiveDay = new Date(lastActive);
        lastActiveDay.setHours(0, 0, 0, 0);

        // Bugün aktif olmamışsa hatırlat
        if (lastActiveDay < today) {
          try {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: "🔥 Streak'ini Kaybetme!",
                body: `${userData.currentStreak} günlük streak'in tehlikede! Hemen gir ve devam et.`,
              },
              data: { type: "streak" },
            });
            sentCount++;
          } catch (e) {
            // Token geçersiz olabilir
          }
        }
      }

      console.log(`✅ ${sentCount} streak hatırlatması gönderildi`);
      return null;
    } catch (error) {
      console.error("Streak hatırlatma hatası:", error);
      return null;
    }
  }
);