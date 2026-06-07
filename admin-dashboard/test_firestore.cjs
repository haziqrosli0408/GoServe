const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function check() {
  const s = await db.collection('reviews').get();
  s.forEach(doc => {
    console.log(doc.id, 'userProfileUrl:', doc.data().userProfileUrl);
  });
}
check();
