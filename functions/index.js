const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Set global options for all functions
setGlobalOptions({ region: "us-central1" });

/**
 * Safely delete a user from Auth and all Firestore collections (v2)
 */
exports.deleteUser = onCall({ cors: true }, async (request) => {
  const adminEmail = "admin@goserve.com";
  const userEmail = request.auth?.token?.email?.toLowerCase().trim();

  // Check if requested by admin
  if (!request.auth || userEmail !== adminEmail) {
    console.error(`Delete access denied for user: ${userEmail || 'Anonymous'}`);
    throw new HttpsError(
      "permission-denied",
      "Only admins can delete users."
    );
  }

  const { uid, role } = request.data;
  if (!uid) {
    throw new HttpsError("invalid-argument", "UID required.");
  }

  try {
    // 1. Delete from Firestore
    console.log(`Deleting ${role} document: ${uid}`);
    const collectionName = role === "Professional" ? "providers" : "users";
    await admin.firestore().collection(collectionName).doc(uid).delete();

    // 2. Delete from Auth (safely)
    try {
      await admin.auth().deleteUser(uid);
      console.log(`Successfully deleted auth account: ${uid}`);
    } catch (authError) {
      if (authError.code === "auth/user-not-found" || authError.code === "auth/invalid-uid") {
        console.warn(`Auth user not found for ${uid}, skipped auth deletion.`);
      } else {
        throw authError;
      }
    }

    return { success: true, message: `User ${uid} deleted successfully.` };
  } catch (error) {
    console.error("Critical error in deleteUser:", error);
    throw new HttpsError("internal", `Server error: ${error.message}`);
  }
});

/**
 * Toggle user account status (v2)
 */
exports.toggleUserStatus = onCall({ cors: true }, async (request) => {
  const adminEmail = "admin@goserve.com";
  const userEmail = request.auth?.token?.email?.toLowerCase().trim();

  if (!request.auth || userEmail !== adminEmail) {
    throw new HttpsError("permission-denied", "Unauthorized.");
  }

  const { uid, role, status } = request.data;
  const collectionName = role === "Professional" ? "providers" : "users";

  try {
    await admin.firestore().collection(collectionName).doc(uid).update({
      status: status,
    });
    return { success: true };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});
