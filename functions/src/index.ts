import * as admin from "firebase-admin";

admin.initializeApp();

// AI Proxy functions
export { generateWorkoutPlan, parseWorkoutNotes, parseWorkoutImage, generateSessionComment } from "./ai-proxy";

// Stripe webhook for web payments
export { stripeWebhook, createCheckoutSession } from "./stripe";

// Scheduled function to reset monthly usage
export { resetMonthlyUsage } from "./scheduled";
