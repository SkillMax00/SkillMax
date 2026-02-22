const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const geminiApiKey = defineSecret('GEMINI_API_KEY');

exports.generateWorkoutPlan = onRequest(
  {
    region: 'us-central1',
    secrets: [geminiApiKey],
    cors: true,
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      logger.warn('generateWorkoutPlan rejected non-POST request');
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ')
        ? authHeader.slice('Bearer '.length)
        : '';

      if (!token) {
        logger.warn('generateWorkoutPlan missing bearer token');
        res.status(401).json({ error: 'Missing bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(token);
      const uid = decoded.uid;

      const profile = req.body && req.body.profile;
      if (!profile || typeof profile !== 'object') {
        logger.warn('generateWorkoutPlan missing profile payload');
        res.status(400).json({ error: 'Missing profile payload' });
        return;
      }

      if (profile.userId && profile.userId !== uid) {
        logger.warn('generateWorkoutPlan profile/user mismatch', {
          uid,
          profileUserId: profile.userId,
        });
        res.status(403).json({ error: 'Profile user does not match auth user' });
        return;
      }

      const apiKey = geminiApiKey.value();
      if (!apiKey) {
        logger.error('generateWorkoutPlan missing GEMINI_API_KEY secret value');
        res.status(500).json({ error: 'GEMINI_API_KEY is not configured' });
        return;
      }

      logger.info('generateWorkoutPlan request accepted', { uid });
      const prompt = buildPrompt(profile, uid);
      const plan = await generatePlanWithGemini(prompt, apiKey, uid, profile);
      logger.info('generateWorkoutPlan success', {
        uid,
        planId: plan.id,
        generator: plan.generator,
      });

      res.status(200).json({ plan });
    } catch (error) {
      logger.error('generateWorkoutPlan failed', error);
      res.status(500).json({ error: 'Failed to generate plan' });
    }
  },
);

function buildPrompt(profile, uid) {
  return [
    'You are a calisthenics programming coach for SkillMax.',
    'Create a safe beginner-to-advanced personalized weekly plan.',
    'Return ONLY valid JSON with the shape:',
    '{"plan":{"id":"string","userId":"string","createdAt":"ISO-8601 string","daysPerWeek":number,"workoutLength":"string","weeklySplit":["string"],"skillTrack":["string"],"blocks":["string"],"generator":"ai"}}',
    'Constraints:',
    '- weeklySplit length must equal daysPerWeek.',
    '- Respect user equipment and level.',
    '- Max 6 workout days.',
    '- Include mobility and recovery in blocks.',
    '- Keep responses concise in field values.',
    `User ID: ${uid}`,
    `Profile: ${JSON.stringify(profile)}`,
  ].join('\n');
}

async function generatePlanWithGemini(prompt, apiKey, uid, profile) {
  const candidateModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  let lastError = 'No Gemini model call attempted.';
  let data = null;

  for (const model of candidateModels) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          generationConfig: {
            temperature: 0.2,
            responseMimeType: 'application/json',
          },
          contents: [
            {
              role: 'user',
              parts: [{ text: prompt }],
            },
          ],
        }),
      },
    );

    if (response.ok) {
      data = await response.json();
      logger.info('Gemini model call succeeded', { model });
      break;
    }

    const text = await response.text();
    lastError = `model=${model} status=${response.status} body=${text}`;
    logger.warn('Gemini model call failed', { model, status: response.status });

    // Try next model on not-found. For other errors, continue trying in case
    // the issue is model-specific permissions.
  }

  if (!data) {
    throw new Error(`Gemini request failed for all models: ${lastError}`);
  }

  const text =
    data.candidates &&
    data.candidates[0] &&
    data.candidates[0].content &&
    data.candidates[0].content.parts &&
    data.candidates[0].content.parts[0] &&
    data.candidates[0].content.parts[0].text
      ? data.candidates[0].content.parts[0].text
      : '';
  const parsed = parseJsonSafely(text);
  const candidate = parsed && parsed.plan ? parsed.plan : parsed;

  if (!candidate || typeof candidate !== 'object') {
    throw new Error('Model did not return a valid plan object');
  }

  return normalizePlan(candidate, uid, profile);
}

function parseJsonSafely(value) {
  if (!value || typeof value !== 'string') return null;
  try {
    return JSON.parse(value);
  } catch (_) {
    const firstBrace = value.indexOf('{');
    const lastBrace = value.lastIndexOf('}');
    if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
      return null;
    }
    const slice = value.slice(firstBrace, lastBrace + 1);
    try {
      return JSON.parse(slice);
    } catch (_) {
      return null;
    }
  }
}

function normalizePlan(plan, uid, profile) {
  const days = clampNumber(toInt(plan.daysPerWeek) || toInt(profile.daysPerWeek) || 4, 2, 6);
  const split = Array.isArray(plan.weeklySplit)
    ? plan.weeklySplit.map(String).slice(0, days)
    : [];

  const normalizedSplit = split.length === days ? split : defaultSplit(days);

  return {
    id: typeof plan.id === 'string' && plan.id.trim() ? plan.id : `plan_${Date.now()}`,
    userId: uid,
    createdAt:
      typeof plan.createdAt === 'string' && plan.createdAt.trim()
        ? plan.createdAt
        : new Date().toISOString(),
    daysPerWeek: days,
    workoutLength:
      typeof plan.workoutLength === 'string' && plan.workoutLength.trim()
        ? plan.workoutLength
        : String(profile.workoutLength || '25-35'),
    weeklySplit: normalizedSplit,
    skillTrack: arrayOfStrings(plan.skillTrack).slice(0, 3),
    blocks: arrayOfStrings(plan.blocks).length
      ? arrayOfStrings(plan.blocks)
      : ['Strength block', 'Skill progression', 'Mobility / prehab', 'Recovery targets'],
    generator: 'ai',
  };
}

function toInt(value) {
  const n = Number.parseInt(String(value), 10);
  return Number.isNaN(n) ? null : n;
}

function clampNumber(n, min, max) {
  return Math.max(min, Math.min(max, n));
}

function arrayOfStrings(value) {
  if (!Array.isArray(value)) return [];
  return value.map((e) => String(e));
}

function defaultSplit(days) {
  if (days <= 2) return ['Full Body + Skills', 'Full Body + Mobility'];
  if (days === 3) return ['Push + Skill', 'Pull + Skill', 'Legs + Core'];
  if (days === 4) return ['Push', 'Pull', 'Legs + Core', 'Skill Focus'];
  if (days === 5) {
    return [
      'Push',
      'Pull',
      'Legs + Core',
      'Skill Focus',
      'Conditioning + Mobility',
    ];
  }
  return [
    'Push',
    'Pull',
    'Legs + Core',
    'Skill Focus',
    'Volume Strength',
    'Mobility + Recovery',
  ];
}
