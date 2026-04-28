const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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

// --- HELPER FUNCTIONS ---

async function getUserTokenAndEmail(uid, isProvider = false) {
  const collection = isProvider ? 'providers' : 'users';
  const doc = await admin.firestore().collection(collection).doc(uid).get();
  if (!doc.exists) return null;
  return doc.data();
}

async function sendPushNotification(token, title, body, data = {}) {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
    });
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
}

// --- CLOUD FUNCTIONS FOR NOTIFICATIONS ---

exports.onBookingStatusChange = onDocumentUpdated("bookings/{bookingId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // If status changed
  if (before.status !== after.status) {
    const customer = await getUserTokenAndEmail(after.customerId, false);
    if (customer && customer.fcmToken) {
      await sendPushNotification(
        customer.fcmToken,
        "Booking Update",
        `Your booking for ${after.serviceName} is now ${after.status}.`,
        { type: "booking", bookingId: event.params.bookingId }
      );
    }
  }

  // If status is "Completed", send email to provider
  if (before.status !== "Completed" && after.status === "Completed") {
    const provider = await getUserTokenAndEmail(after.providerId, true);
    if (provider && provider.email) {
      await admin.firestore().collection("mail").add({
        to: provider.email,
        message: {
          subject: "Payment Received - GoServe",
          html: `
            <div style="font-family: Arial, sans-serif; color: #333;">
              <h2 style="color: #FF6B00;">Payment Received!</h2>
              <p>Hi ${provider.name},</p>
              <p>Your service <strong>${after.serviceName}</strong> has been marked as completed.</p>
              <p>Payment of <strong>RM ${after.totalPrice}</strong> has been successfully received.</p>
              <br/>
              <p>Thank you for using GoServe!</p>
            </div>
          `
        }
      });
    }
  }
});

exports.onNewBookingCreated = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const booking = event.data.data();

  // 1. Notify Provider via Push
  const provider = await getUserTokenAndEmail(booking.providerId, true);
  if (provider && provider.fcmToken) {
    await sendPushNotification(
      provider.fcmToken,
      "New Service Request",
      `You have a new booking request for ${booking.serviceName}.`,
      { type: "booking", bookingId: event.params.bookingId }
    );
  }

  // 2. Email Customer (Payment Confirmation)
  const customer = await getUserTokenAndEmail(booking.customerId, false);
  if (customer && customer.email) {
    await admin.firestore().collection("mail").add({
      to: customer.email,
      message: {
        subject: "Payment Confirmed & Booking Created - GoServe",
        html: `
          <div style="font-family: Arial, sans-serif; color: #333;">
            <h2 style="color: #FF6B00;">Booking Confirmed</h2>
            <p>Hi ${customer.name || 'Customer'},</p>
            <p>Your booking for <strong>${booking.serviceName}</strong> with ${booking.providerName} is confirmed!</p>
            <p><strong>Order ID:</strong> ${booking.orderId}</p>
            <p><strong>Date & Time:</strong> ${booking.date} at ${booking.time}</p>
            <p><strong>Total Paid:</strong> RM ${booking.totalPrice}</p>
            <br/>
            <p>Thank you for using GoServe!</p>
          </div>
        `
      }
    });
  }
});

exports.onNewChatMessage = onDocumentCreated("chats/{chatId}/messages/{msgId}", async (event) => {
  const message = event.data.data();
  
  // Find receiver's FCM token (try users collection, then providers collection)
  let receiver = await getUserTokenAndEmail(message.receiverId, false);
  if (!receiver) {
    receiver = await getUserTokenAndEmail(message.receiverId, true);
  }

  if (receiver && receiver.fcmToken) {
    // Find sender's name
    let senderName = "Someone";
    let sender = await getUserTokenAndEmail(message.senderId, false);
    if (!sender) sender = await getUserTokenAndEmail(message.senderId, true);
    if (sender) senderName = sender.name || senderName;

    await sendPushNotification(
      receiver.fcmToken,
      `New message from ${senderName}`,
      message.text,
      { type: "chat", chatId: event.params.chatId }
    );
  }
});

exports.onUpcomingServiceReminder = onSchedule("0 8 * * *", async (event) => {
  // Runs every day at 8:00 AM. Finds bookings for "tomorrow".
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0]; // YYYY-MM-DD format

  const bookingsSnapshot = await admin.firestore().collection('bookings')
    .where('date', '==', tomorrowStr)
    .where('status', 'in', ['Confirmed', 'Pending'])
    .get();

  for (const doc of bookingsSnapshot.docs) {
    const booking = doc.data();
    const provider = await getUserTokenAndEmail(booking.providerId, true);
    if (provider && provider.fcmToken) {
      await sendPushNotification(
        provider.fcmToken,
        "Upcoming Service Reminder",
        `You have a service appointment tomorrow for ${booking.serviceName} at ${booking.time}.`,
        { type: "booking", bookingId: doc.id }
      );
    }
  }
});
