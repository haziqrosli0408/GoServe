const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Safely delete a user from Auth and all Firestore collections
 */
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // Check if requested by admin
  if (!context.auth || context.auth.token.email !== "admin@goserve.com") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can delete users.",
    );
  }

  const {uid, role} = data;
  if (!uid) {
    throw new functions.https.HttpsError("invalid-argument", "UID required.");
  }

  try {
    // 1. Delete from Firestore
    const collectionName = role === "Professional" ? "providers" : "users";
    await admin.firestore().collection(collectionName).doc(uid).delete();

    // 2. Delete from Auth
    await admin.auth().deleteUser(uid);

    return {success: true, message: `User ${uid} deleted successfully.`};
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Toggle user account status (Active/Suspended)
 */
exports.toggleUserStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.email !== "admin@goserve.com") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Unauthorized.",
    );
  }

  const {uid, role, status} = data;
  const collectionName = role === "Professional" ? "providers" : "users";

  try {
    await admin.firestore().collection(collectionName).doc(uid).update({
      status: status,
    });
    return {success: true};
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});
