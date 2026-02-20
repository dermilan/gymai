import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Default model configuration (used if Remote Config is not set up)
const DEFAULT_PRIMARY_MODEL = "x-ai/grok-4.1-fast";
const DEFAULT_FALLBACK_MODEL = "openai/gpt-oss-120b:free";

// Cached model config with TTL
interface ModelConfig {
  primaryModel: string;
  fallbackModel: string;
  lastFetched: number;
}

let cachedModelConfig: ModelConfig | null = null;
const CONFIG_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Fetches model configuration from Firebase Remote Config.
 * Falls back to defaults if Remote Config is not set up.
 * Results are cached for 5 minutes to reduce API calls.
 */
async function getModelConfig(): Promise<{ primaryModel: string; fallbackModel: string }> {
  const now = Date.now();

  // Return cached config if still valid
  if (cachedModelConfig && (now - cachedModelConfig.lastFetched) < CONFIG_CACHE_TTL_MS) {
    return {
      primaryModel: cachedModelConfig.primaryModel,
      fallbackModel: cachedModelConfig.fallbackModel,
    };
  }

  try {
    const remoteConfig = admin.remoteConfig();
    const template = await remoteConfig.getTemplate();

    const primaryParam = template.parameters?.["ai_primary_model"];
    const fallbackParam = template.parameters?.["ai_fallback_model"];

    // Extract default values from Remote Config parameters
    const primaryModel = (primaryParam?.defaultValue as { value?: string })?.value || DEFAULT_PRIMARY_MODEL;
    const fallbackModel = (fallbackParam?.defaultValue as { value?: string })?.value || DEFAULT_FALLBACK_MODEL;

    // Cache the result
    cachedModelConfig = {
      primaryModel,
      fallbackModel,
      lastFetched: now,
    };

    console.log(`Model config loaded from Remote Config: primary=${primaryModel}, fallback=${fallbackModel}`);

    return { primaryModel, fallbackModel };
  } catch (error) {
    console.warn("Failed to fetch Remote Config, using defaults:", error);

    // Cache defaults to avoid repeated failed fetches
    cachedModelConfig = {
      primaryModel: DEFAULT_PRIMARY_MODEL,
      fallbackModel: DEFAULT_FALLBACK_MODEL,
      lastFetched: now,
    };

    return {
      primaryModel: DEFAULT_PRIMARY_MODEL,
      fallbackModel: DEFAULT_FALLBACK_MODEL,
    };
  }
}

interface UserData {
  tier: "free" | "plus" | "pro";
  aiRequestsThisMonth: number;
  subscriptionExpiresAt?: admin.firestore.Timestamp;
}

const TIER_LIMITS: Record<string, number> = {
  free: 15,
  plus: 150,
  pro: -1, // Unlimited
};

async function checkAndIncrementUsage(uid: string): Promise<{ allowed: boolean; remaining: number; tier: string }> {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  return db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);

    // Create user document if it doesn't exist (new user)
    if (!userDoc.exists) {
      console.log("Creating new user document for:", uid);
      transaction.set(userRef, {
        tier: "free",
        aiRequestsThisMonth: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { allowed: true, remaining: TIER_LIMITS.free - 1, tier: "free" };
    }

    const userData = userDoc.data() as UserData;
    let effectiveTier = userData.tier || "free";

    // Check if subscription is expired
    if (userData.tier !== "free" && userData.subscriptionExpiresAt) {
      const expiresAt = userData.subscriptionExpiresAt.toDate();
      if (expiresAt < new Date()) {
        effectiveTier = "free";
      }
    }

    const limit = TIER_LIMITS[effectiveTier];
    const currentUsage = userData.aiRequestsThisMonth || 0;

    // Unlimited for pro
    if (limit === -1) {
      transaction.update(userRef, {
        aiRequestsThisMonth: currentUsage + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { allowed: true, remaining: -1, tier: effectiveTier };
    }

    if (currentUsage >= limit) {
      return { allowed: false, remaining: 0, tier: effectiveTier };
    }

    transaction.update(userRef, {
      aiRequestsThisMonth: currentUsage + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { allowed: true, remaining: limit - currentUsage - 1, tier: effectiveTier };
  });
}

// Message content can be string or array of content parts (for multimodal)
type MessageContent = string | Array<{ type: string; text?: string; image_url?: { url: string } }>;
type Message = { role: string; content: MessageContent };

async function callOpenRouter(messages: Message[], model: string): Promise<string> {
  const apiKey = process.env.OPENROUTER_API_KEY || "";

  if (!apiKey) {
    throw new HttpsError("internal", "OpenRouter API key not configured");
  }

  const response = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
      "HTTP-Referer": "https://gym-progress-ai.web.app",
      "X-Title": "Gym Progress AI",
    },
    body: JSON.stringify({
      model,
      messages,
      max_tokens: 2000,
      temperature: 0.7,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new HttpsError("internal", `OpenRouter error: ${errorText}`);
  }

  const data = await response.json() as { choices: Array<{ message: { content: string } }> };
  return data.choices[0]?.message?.content || "";
}

// Remove obsolete v1 wrappers
// Configure functions directly in the onCall options

export const generateWorkoutPlan = onCall({
  secrets: ["OPENROUTER_API_KEY"],
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;

    // Accept both 'prefs' and 'preferences' for compatibility
    const { recentWorkouts, prefs, preferences } = request.data || {};
    const userPrefs = prefs || preferences || {};

    // Check usage limits
    const usage = await checkAndIncrementUsage(uid);

    if (!usage.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI limit reached. Upgrade to ${usage.tier === "free" ? "Plus or Pro" : "Pro"} for more requests.`
      );
    }

    // Get API key from environment
    const apiKey = process.env.OPENROUTER_API_KEY || "";
    if (!apiKey) {
      throw new HttpsError("internal", "AI service not configured");
    }

    // Fetch model config from Remote Config
    const { primaryModel, fallbackModel } = await getModelConfig();

    const systemPrompt = `You are a knowledgeable fitness coach. Generate a personalized workout plan based on the user's history and preferences. Return the plan as JSON with this structure:
{
  "name": "Workout name",
  "summary": "Brief description",
  "durationMinutes": 45,
  "exercises": [
    {
      "exerciseName": "Exercise Name",
      "sets": 3,
      "reps": 10,
      "weight": 50,
      "type": "strength",
      "durationMinutes": null,
      "notes": "Optional notes"
    }
  ]
}
Type can be "strength", "cardio", or "flexibility".
For cardio exercises (rowing, running, cycling, etc.), use durationMinutes instead of sets/reps (set sets to 1, reps to 0, weight to 0).`;

    const userPrompt = `Recent workouts: ${JSON.stringify(recentWorkouts || [])}
Preferences: ${JSON.stringify(userPrefs)}
Generate a workout plan for today.`;

    let result: string;
    try {
      result = await callOpenRouter(
        [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        primaryModel
      );
    } catch (primaryError) {
      // Try fallback model
      result = await callOpenRouter(
        [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        fallbackModel
      );
    }

    return { plan: result, remaining: usage.remaining, tier: usage.tier };
  } catch (error: unknown) {
    console.error("generateWorkoutPlan error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new HttpsError("internal", `Error: ${errorMessage}`);
  }
});

export const parseWorkoutNotes = onCall({
  secrets: ["OPENROUTER_API_KEY"],
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const uid = request.auth.uid;
  const { notes } = request.data;

  if (!notes || typeof notes !== "string") {
    throw new HttpsError("invalid-argument", "Notes are required");
  }

  const usage = await checkAndIncrementUsage(uid);
  if (!usage.allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Monthly AI limit reached. Upgrade for more requests."
    );
  }

  // Provide current date context for relative date parsing
  const today = new Date().toISOString().split('T')[0];

  const systemPrompt = `Parse workout notes into structured JSON. Today's date is ${today}.

IMPORTANT: Extract the session date if mentioned. Look for:
- Explicit dates (Feb 15, 2025-02-15, 15/02)
- Relative dates (yesterday, last Monday, 3 days ago, this morning)
- Day references (Monday, Tuesday, etc.)
If no date mentioned, set sessionDate to null (DO NOT default to today).

Return this JSON structure:
{
  "name": "Workout name",
  "summary": "Brief summary",
  "durationMinutes": 45,
  "sessionDate": "2025-02-15T10:00:00.000Z or null if not mentioned",
  "exercises": [
    {
      "exerciseName": "Exercise Name",
      "sets": 3,
      "reps": 10,
      "weight": 50,
      "type": "strength",
      "durationMinutes": null,
      "notes": "Optional notes"
    }
  ]
}
Type can be "strength", "cardio", or "flexibility".
For cardio exercises, use durationMinutes instead of sets/reps (set sets to 1, reps to 0, weight to 0).`;

  // Fetch model config from Remote Config
  const { primaryModel, fallbackModel } = await getModelConfig();

  let result: string;
  try {
    result = await callOpenRouter(
      [
        { role: "system", content: systemPrompt },
        { role: "user", content: notes },
      ],
      primaryModel
    );
  } catch (primaryError) {
    // Try fallback model
    result = await callOpenRouter(
      [
        { role: "system", content: systemPrompt },
        { role: "user", content: notes },
      ],
      fallbackModel
    );
  }

  let finalWorkout;
  try {
    finalWorkout = JSON.parse(result);
  } catch (parseError) {
    console.warn("Failed to parse LLM string into JSON:", result);
    throw new HttpsError("internal", "Failed to parse workout notes");
  }

  return { workout: finalWorkout, remaining: usage.remaining };
});

export const parseWorkoutImage = onCall({
  secrets: ["OPENROUTER_API_KEY"],
  timeoutSeconds: 120,
  memory: "512MiB",
}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;
    const { imageBase64, mimeType } = request.data;

    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError("invalid-argument", "Image data is required");
    }

    console.log(`parseWorkoutImage called by ${uid}, image size: ${imageBase64.length} chars`);

    const usage = await checkAndIncrementUsage(uid);
    if (!usage.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Monthly AI limit reached. Upgrade for more requests."
      );
    }

    // Provide current date context for relative date parsing
    const today = new Date().toISOString().split('T')[0];

    const systemPrompt = `You are analyzing an image of a workout log, exercise machine display, or fitness tracking screenshot.
Today's date is ${today}.

IMPORTANT: Look for any date on the image (timestamps, dates shown on displays/apps).
If no date is visible, set sessionDate to null (DO NOT default to today).

Extract the workout information and return it as JSON:
{
  "name": "Workout name or type",
  "summary": "Brief description of what you see",
  "durationMinutes": 45,
  "sessionDate": "2025-02-15T10:00:00.000Z or null if not visible",
  "exercises": [
    {
      "exerciseName": "Exercise name",
      "sets": 3,
      "reps": 10,
      "weight": 50,
      "type": "strength",
      "durationMinutes": null,
      "notes": "Any visible notes"
    }
  ]
}
Type can be "strength", "cardio", or "flexibility".
For cardio exercises, use durationMinutes instead of sets/reps (set sets to 1, reps to 0, weight to 0).
If you cannot identify workout data in the image, return { "error": "Could not parse workout from image" }.`;

    const imageUrl = `data:${mimeType || "image/jpeg"};base64,${imageBase64}`;

    // Fetch model config from Remote Config
    const { primaryModel, fallbackModel } = await getModelConfig();

    let result: string;
    try {
      result = await callOpenRouter(
        [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              { type: "text", text: "Please analyze this workout image and extract the exercise data." },
              { type: "image_url", image_url: { url: imageUrl } }
            ]
          },
        ],
        primaryModel
      );
    } catch (primaryError) {
      // Try fallback model (may not support images)
      result = await callOpenRouter(
        [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              { type: "text", text: "Please analyze this workout image and extract the exercise data." },
              { type: "image_url", image_url: { url: imageUrl } }
            ]
          },
        ],
        fallbackModel
      );
    }

    return { parsed: result, remaining: usage.remaining };
  } catch (error: unknown) {
    console.error("parseWorkoutImage error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError(
      "internal",
      error instanceof Error ? error.message : "Image parsing failed"
    );
  }
});

export const generateSessionComment = onCall({
  secrets: ["OPENROUTER_API_KEY"],
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;

    // Accept both naming conventions for compatibility
    const { current, previous, prefs, currentSession, previousSession, userPrefs } = request.data || {};
    const currentData = current || currentSession || {};
    const previousData = previous || previousSession || null;
    const prefsData = prefs || userPrefs || {};

    // Check usage limits
    const usage = await checkAndIncrementUsage(uid);

    if (!usage.allowed) {
      throw new HttpsError(
        "resource-exhausted",
        `Monthly AI limit reached. Upgrade to ${usage.tier === "free" ? "Plus or Pro" : "Pro"} for more requests.`
      );
    }

    // Get API key from environment
    const apiKey = process.env.OPENROUTER_API_KEY || "";
    if (!apiKey) {
      throw new HttpsError("internal", "AI service not configured");
    }

    // Fetch model config from Remote Config
    const { primaryModel, fallbackModel } = await getModelConfig();

    const systemPrompt = `You are a supportive fitness coach. Generate a brief, encouraging comment about the user's completed workout session. Keep it to 1-2 sentences. Be specific about their achievements when possible.`;

    const userPrompt = `Current session: ${JSON.stringify(currentData)}
Previous session (for comparison): ${JSON.stringify(previousData)}
User preferences: ${JSON.stringify(prefsData)}
Generate a brief encouraging comment about their workout.`;

    let result: string;
    try {
      result = await callOpenRouter(
        [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        primaryModel
      );
    } catch (primaryError) {
      // Try fallback model
      try {
        result = await callOpenRouter(
          [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
          fallbackModel
        );
      } catch (fallbackError) {
        // Return a generic comment instead of throwing
        return {
          comment: "Nice work on your session! Keep pushing towards your goals.",
          remaining: usage.remaining,
          tier: usage.tier
        };
      }
    }

    return { comment: result, remaining: usage.remaining, tier: usage.tier };
  } catch (error: unknown) {
    console.error("generateSessionComment error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new HttpsError("internal", `Error: ${errorMessage}`);
  }
});
