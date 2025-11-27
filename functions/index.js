// Firebase Cloud Functions v2 - Etkinlik ve Resim Proxy Sistemi

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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

// ============ RESİM PROXY FONKSİYONU (CORS DÜZELTME) ============
exports.imageProxy = onRequest(
  {
    region: "europe-west1",
    maxInstances: 10,
    cors: true, // <-- BU ÖNEMLİ! Otomatik CORS desteği
  },
  async (req, res) => {
    // CORS headers - HER ZAMAN gönder (başarılı veya hatalı)
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    // Preflight request
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    const imageUrl = req.query.url;

    if (!imageUrl) {
      return res.status(400).send("URL parametresi eksik.");
    }

    try {
      // HTTP ve HTTPS'e izin ver
      const response = await axios.get(imageUrl, { 
        responseType: "arraybuffer",
        timeout: 10000, // 10 saniye timeout
        headers: {
          'Referer': 'https://www.google.com', 
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });

      res.set("Cache-Control", "public, max-age=86400, s-maxage=86400"); // 24 saat cache
      res.set("Content-Type", response.headers["content-type"] || "image/jpeg");
      res.send(response.data);

    } catch (error) {
      console.error("Image Proxy Hatası:", error.message);
      
      // Hata durumunda placeholder resim gönder
      res.set("Content-Type", "image/svg+xml");
      res.send(`<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
        <rect width="200" height="200" fill="#1C1C1E"/>
        <text x="100" y="100" text-anchor="middle" fill="#666" font-size="14">Resim Yüklenemedi</text>
      </svg>`);
    }
  }
);

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

    try {
      const eventData = snapshot.data();
      const testId = eventData.testId;
      if (testId) {
        await db.collection("testler").doc(testId).update({ 
          isEventTest: true, 
          eventId: event.params.eventId, 
          eventStartTime: eventData.startTime, 
          eventEndTime: eventData.endTime 
        });
      }

      await snapshot.ref.update({ 
        isConverted: false, 
        status: "active", 
        participantCount: 0, 
        createdAt: admin.firestore.FieldValue.serverTimestamp() 
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

console.log("Functions yüklendi ✓");