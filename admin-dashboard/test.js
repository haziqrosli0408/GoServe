import admin from 'firebase-admin';

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection("services").get();
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`Title: ${data.title}, Category: ${data.category}`);
  });
}
run();
