import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

// Reset AI usage counters on the 1st of each month
export const resetMonthlyUsage = onSchedule({
  schedule: "0 0 1 * *", // At midnight on the 1st of every month
  timeZone: "UTC"
}, async (event) => {
  const db = admin.firestore();
  const batch = db.batch();

  const usersSnapshot = await db.collection("users").get();

  let count = 0;
  for (const doc of usersSnapshot.docs) {
    batch.update(doc.ref, {
      aiRequestsThisMonth: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;

    // Firestore batches are limited to 500 operations
    if (count % 450 === 0) {
      await batch.commit();
    }
  }

  await batch.commit();
  console.log(`Reset AI usage for ${count} users`);
});
