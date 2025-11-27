// Firebase Cloud Functions - index.js
// Bu dosyayı Firebase Functions projenize ekleyin
// Komut: firebase init functions && firebase deploy --only functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============ YENİ MESAJ BİLDİRİMİ ============
exports.onNewMessage = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const message = snap.data();
        const chatId = context.params.chatId;

        // Chat bilgilerini al
        const chatDoc = await db.collection('chats').doc(chatId).get();
        const chatData = chatDoc.data();

        if (!chatData) return null;

        // Alıcıyı bul
        const senderId = message.senderId;
        const users = chatData.users || [];
        const receiverId = users.find(id => id !== senderId);

        if (!receiverId) return null;

        // Alıcının bilgilerini al
        const receiverDoc = await db.collection('users').doc(receiverId).get();
        const receiverData = receiverDoc.data();

        if (!receiverData) return null;

        // Bildirim ayarlarını kontrol et
        const settings = receiverData.settings || {};
        if (settings.yeniMesajBildirim === false) return null;

        // FCM token kontrolü
        const fcmToken = receiverData.fcmToken;
        if (!fcmToken) return null;

        // Gönderen ismini al
        const senderDoc = await db.collection('users').doc(senderId).get();
        const senderName = senderDoc.data()?.name || 'Birisi';

        // Mesaj metnini kısalt
        let messageText = message.text || '';
        if (message.type === 'invite') {
            messageText = '🎮 Sana bir test daveti gönderdi!';
        } else if (messageText.length > 50) {
            messageText = messageText.substring(0, 50) + '...';
        }

        // Bildirim gönder
        try {
            await messaging.send({
                token: fcmToken,
                notification: {
                    title: `💬 ${senderName}`,
                    body: messageText,
                },
                data: {
                    type: 'message',
                    chatId: chatId,
                    senderId: senderId,
                },
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'mest_notifications',
                        color: '#FF5A5F',
                        sound: 'default',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1,
                        },
                    },
                },
            });

            console.log('Mesaj bildirimi gönderildi:', receiverId);
        } catch (error) {
            console.error('Bildirim gönderme hatası:', error);
            
            // Token geçersizse sil
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
                await db.collection('users').doc(receiverId).update({
                    fcmToken: admin.firestore.FieldValue.delete()
                });
            }
        }

        return null;
    });

// ============ YENİ EŞLEŞME BİLDİRİMİ ============
exports.onNewMatch = functions.firestore
    .document('bildirimler/{bildirimId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        const receiverId = notification.aliciId;

        if (!receiverId) return null;

        // Alıcının bilgilerini al
        const receiverDoc = await db.collection('users').doc(receiverId).get();
        const receiverData = receiverDoc.data();

        if (!receiverData) return null;

        // Bildirim ayarlarını kontrol et
        const settings = receiverData.settings || {};
        if (settings.eslesmeBildirim === false) return null;

        // FCM token kontrolü
        const fcmToken = receiverData.fcmToken;
        if (!fcmToken) return null;

        const senderName = notification.gonderenIsim || 'Birisi';
        const uyum = notification.uyum || 0;

        try {
            await messaging.send({
                token: fcmToken,
                notification: {
                    title: '💖 Yeni Eşleşme!',
                    body: `${senderName} seninle %${uyum} uyumlu!`,
                },
                data: {
                    type: 'match',
                    senderId: notification.gonderenId || '',
                },
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'mest_notifications',
                        color: '#FF5A5F',
                        sound: 'default',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1,
                        },
                    },
                },
            });

            console.log('Eşleşme bildirimi gönderildi:', receiverId);
        } catch (error) {
            console.error('Bildirim gönderme hatası:', error);
        }

        return null;
    });

// ============ YENİ ROZET BİLDİRİMİ ============
exports.onNewBadge = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const userId = context.params.userId;

        const oldBadges = before.badges || [];
        const newBadges = after.badges || [];

        // Yeni rozet eklendiyse
        if (newBadges.length > oldBadges.length) {
            const addedBadge = newBadges.find(b => !oldBadges.includes(b));
            
            if (addedBadge) {
                const fcmToken = after.fcmToken;
                if (!fcmToken) return null;

                try {
                    await messaging.send({
                        token: fcmToken,
                        notification: {
                            title: '🏆 Yeni Rozet!',
                            body: `"${addedBadge}" rozetini kazandın!`,
                        },
                        data: {
                            type: 'badge',
                            badgeName: addedBadge,
                        },
                        android: {
                            priority: 'high',
                            notification: {
                                channelId: 'mest_notifications',
                                color: '#FF5A5F',
                            },
                        },
                    });

                    console.log('Rozet bildirimi gönderildi:', userId);
                } catch (error) {
                    console.error('Bildirim gönderme hatası:', error);
                }
            }
        }

        return null;
    });

// ============ HESAP SİLME - VERİ TEMİZLİĞİ ============
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const batch = db.batch();

    try {
        // Kullanıcı dökümanını sil
        batch.delete(db.collection('users').doc(userId));

        // Bildirimleri sil
        const notifications = await db.collection('bildirimler')
            .where('aliciId', '==', userId)
            .get();
        notifications.forEach(doc => batch.delete(doc.ref));

        // Gönderilen bildirimleri sil
        const sentNotifications = await db.collection('bildirimler')
            .where('gonderenId', '==', userId)
            .get();
        sentNotifications.forEach(doc => batch.delete(doc.ref));

        // Turnuva sonuçlarını sil
        const tournaments = await db.collection('turnuvalar')
            .where('odenen', '==', userId)
            .get();
        tournaments.forEach(doc => batch.delete(doc.ref));

        // Feedback'leri sil
        const feedback = await db.collection('feedback')
            .where('userId', '==', userId)
            .get();
        feedback.forEach(doc => batch.delete(doc.ref));

        await batch.commit();
        console.log('Kullanıcı verileri silindi:', userId);
    } catch (error) {
        console.error('Veri silme hatası:', error);
    }

    return null;
});

// ============ GÜNLÜK ÖZET BİLDİRİMİ ============
exports.dailySummary = functions.pubsub
    .schedule('0 20 * * *') // Her gün saat 20:00
    .timeZone('Europe/Istanbul')
    .onRun(async (context) => {
        // Son 24 saatte giriş yapmayan kullanıcıları bul
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
        
        const inactiveUsers = await db.collection('users')
            .where('lastActive', '<', oneDayAgo)
            .where('fcmToken', '!=', null)
            .limit(100) // Batch limit
            .get();

        const promises = inactiveUsers.docs.map(async (doc) => {
            const userData = doc.data();
            const settings = userData.settings || {};
            
            // Pazarlama bildirimlerini kabul etmişse
            if (settings.pazarlamaBildirim !== false && userData.fcmToken) {
                try {
                    await messaging.send({
                        token: userData.fcmToken,
                        notification: {
                            title: '👋 Seni özledik!',
                            body: 'Yeni testler ve eşleşmeler seni bekliyor!',
                        },
                        data: {
                            type: 'reminder',
                        },
                    });
                } catch (error) {
                    console.error('Hatırlatma bildirimi hatası:', error);
                }
            }
        });

        await Promise.all(promises);
        console.log('Günlük özet bildirimleri gönderildi');
        
        return null;
    });

// ============ TEST İSTATİSTİKLERİ GÜNCELLEME ============
exports.updateTestStats = functions.firestore
    .document('turnuvalar/{turnuvaId}')
    .onCreate(async (snap, context) => {
        const result = snap.data();
        const testId = result.testId;

        if (!testId) return null;

        try {
            await db.collection('testler').doc(testId).update({
                playCount: admin.firestore.FieldValue.increment(1),
                lastPlayedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (error) {
            console.error('Test istatistik güncelleme hatası:', error);
        }

        return null;
    });

// ============ ŞİKAYET BİLDİRİMİ (Admin'e) ============
exports.onNewReport = functions.firestore
    .document('reports/{reportId}')
    .onCreate(async (snap, context) => {
        const report = snap.data();
        
        // Admin topic'ine bildirim gönder
        try {
            await messaging.sendToTopic('admin_reports', {
                notification: {
                    title: '🚨 Yeni Şikayet',
                    body: `${report.reason}: ${report.reportedUserName}`,
                },
                data: {
                    type: 'report',
                    reportId: context.params.reportId,
                },
            });
        } catch (error) {
            console.error('Admin bildirim hatası:', error);
        }

        return null;
    });