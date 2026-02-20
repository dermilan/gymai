import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "", {
  apiVersion: "2023-10-16",
});

const PRICE_IDS: Record<string, string> = {
  plus: process.env.STRIPE_PRICE_PLUS || "",
  pro: process.env.STRIPE_PRICE_PRO || "",
};

export const createCheckoutSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const { tier, successUrl, cancelUrl } = request.data;

  if (!tier || !PRICE_IDS[tier]) {
    throw new HttpsError("invalid-argument", "Invalid tier");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data();

  // Get or create Stripe customer
  let customerId = userData?.stripeCustomerId;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: userData?.email,
      metadata: { firebaseUid: uid },
    });
    customerId = customer.id;
    await db.collection("users").doc(uid).update({ stripeCustomerId: customerId });
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    payment_method_types: ["card"],
    line_items: [
      {
        price: PRICE_IDS[tier],
        quantity: 1,
      },
    ],
    mode: "subscription",
    success_url: successUrl || "https://gym-progress-ai.web.app/subscription/success",
    cancel_url: cancelUrl || "https://gym-progress-ai.web.app/subscription",
    metadata: {
      firebaseUid: uid,
      tier,
    },
  });

  return { sessionId: session.id, url: session.url };
});

export const stripeWebhook = onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || "";

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig as string, webhookSecret);
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    res.status(400).send("Webhook Error");
    return;
  }

  const db = admin.firestore();

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const uid = session.metadata?.firebaseUid;
      const tier = session.metadata?.tier;

      if (uid && tier) {
        // Get subscription details
        const subscription = await stripe.subscriptions.retrieve(session.subscription as string);
        const expiresAt = new Date(subscription.current_period_end * 1000);

        await db.collection("users").doc(uid).update({
          tier,
          subscriptionExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          stripeSubscriptionId: subscription.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      break;
    }

    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      const customerId = subscription.customer as string;

      // Find user by Stripe customer ID
      const usersSnapshot = await db
        .collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        const userDoc = usersSnapshot.docs[0];
        const expiresAt = new Date(subscription.current_period_end * 1000);

        await userDoc.ref.update({
          subscriptionExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      const customerId = subscription.customer as string;

      const usersSnapshot = await db
        .collection("users")
        .where("stripeCustomerId", "==", customerId)
        .limit(1)
        .get();

      if (!usersSnapshot.empty) {
        const userDoc = usersSnapshot.docs[0];
        await userDoc.ref.update({
          tier: "free",
          subscriptionExpiresAt: null,
          stripeSubscriptionId: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      break;
    }
  }

  res.status(200).send("OK");
});
