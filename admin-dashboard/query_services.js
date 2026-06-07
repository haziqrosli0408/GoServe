const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // assuming it exists or default credential
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});
const db = admin.firestore();
db.collection('services').get().then(snapshot => {
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`Service: ${data.title}, Category: ${data.category}, ProviderAddress: ${data.providerAddress}`);
  });
}).catch(console.error);
