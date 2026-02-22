# SkillMax AI Plan Setup

This project now supports onboarding profile storage + initial plan generation after successful paywall purchase.

## What is already implemented

- Onboarding answers are passed to the trial/paywall flow.
- On successful paywall purchase/restore, the app:
  1. Saves onboarding profile to Firestore.
  2. Calls AI plan generation endpoint (if configured).
  3. Falls back to local deterministic plan if endpoint is missing/fails.
  4. Saves generated plan to Firestore.

## Firestore locations

- `users/{uid}/profile/current`
  - profile summary + raw onboarding answers map
  - includes: age, height, weight, units, goal, level, skills, equipment, etc.
- `users/{uid}/plans/{planId}`
  - generated initial plan
- `users/{uid}/sessions/{sessionId}`
  - reserved for workout feedback/session results

## Required keys/secrets

Yes, for real AI-generated plans you need an AI API key.

- Secret name used by function: `GEMINI_API_KEY`
- The key is stored in Firebase Functions Secret Manager (server-side only), not in Flutter app.

## One-time setup steps (run these locally)

1. Install Firebase CLI (if not installed):

```bash
npm install -g firebase-tools
```

2. Login and select project:

```bash
firebase login
firebase use skillmax-e5b98
```

3. Install function dependencies:

```bash
cd functions
npm install
cd ..
```

4. Set Gemini secret for Functions:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

5. Deploy Firestore rules + Cloud Function:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

6. Get deployed function URL:

```bash
firebase functions:list
```

Look for `generateWorkoutPlan` HTTPS URL.

7. Run Flutter app with function URL:

```bash
flutter run --dart-define=PLAN_FUNCTION_URL=https://<YOUR_FUNCTION_URL>
```

## Notes

- If `PLAN_FUNCTION_URL` is missing or function fails, app still generates a fallback plan.
- Paywall dismiss/cancel keeps user on `Try for $0.00` screen.

## Verification checklist (very specific)

1. Confirm your function + secret are deployed:

```bash
firebase use skillmax-e5b98
firebase deploy --only functions:generateWorkoutPlan
firebase functions:secrets:access GEMINI_API_KEY
```

2. Copy the exact function URL:

```bash
firebase functions:list
```

3. Run the app with that exact URL (no quotes, no trailing spaces):

```bash
flutter run --dart-define=PLAN_FUNCTION_URL=https://<EXACT_FUNCTION_URL>
```

4. In another terminal, stream function logs while testing onboarding + purchase:

```bash
firebase functions:log --only generateWorkoutPlan
```

5. After purchase completes, check Firestore:
- `users/{uid}/plans/{planId}` should have `generator: "ai"` when Gemini worked.
- `users/{uid}/profile/current` should contain `lastPlanGenerationDiagnostic`.

6. If it still falls back, inspect:
- `lastPlanGenerationDiagnostic.remoteError`
- `lastPlanGenerationDiagnostic.attemptedFunctionUrl`
- function logs output from step 4

Those three values together will tell you the exact failure point (URL, auth token, secret, Gemini model/API response, or response parsing).
