import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyCVgCia5MyH3leBEhAZsJeQV2EoLy18i-M",
  authDomain: "goserve-50b3b.firebaseapp.com",
  projectId: "goserve-50b3b",
  storageBucket: "goserve-50b3b.firebasestorage.app",
  messagingSenderId: "382033508368",
  appId: "1:382033508368:web:f311d50413f3998d313295"
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app;
