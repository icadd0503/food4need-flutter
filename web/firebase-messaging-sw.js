importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyABWOwp34h9yopmVzGhFbwIKYYYDZyw1ZA",
  authDomain: "food4need-f72b3.firebaseapp.com",
  projectId: "food4need-f72b3",
  storageBucket: "food4need-f72b3.firebasestorage.app",
  messagingSenderId: "284872657712",
  appId: "1:284872657712:web:2aefb1f3c676dea2be16f5"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/firebase-logo.png' // You can change this to your app icon
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});