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

exports.coachChat = onRequest(
  {
    region: 'us-central1',
    secrets: [geminiApiKey],
    cors: true,
    timeoutSeconds: 60,
    memory: '256MiB',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const authHeader = req.headers.authorization || '';
      const token = authHeader.startsWith('Bearer ')
        ? authHeader.slice('Bearer '.length)
        : '';

      if (!token) {
        res.status(401).json({ error: 'Missing bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(token);
      const uid = decoded.uid;

      const body = req.body || {};
      const message = String(body.message || '').trim();
      const context = body.context && typeof body.context === 'object'
        ? body.context
        : {};

      if (!message) {
        res.status(400).json({ error: 'Missing message' });
        return;
      }

      const profileUserId = context.profile && context.profile.userId
        ? String(context.profile.userId)
        : null;
      if (profileUserId && profileUserId !== uid) {
        res.status(403).json({ error: 'Profile user does not match auth user' });
        return;
      }

      const apiKey = geminiApiKey.value();
      if (!apiKey) {
        res.status(500).json({ error: 'GEMINI_API_KEY is not configured' });
        return;
      }

      const prompt = buildCoachPrompt({ uid, message, context });
      const json = await generateJsonWithGemini(prompt, apiKey, { temperature: 0.35 });
      const result = normalizeCoachResponse(json);

      res.status(200).json(result);
    } catch (error) {
      logger.error('coachChat failed', error);
      res.status(500).json({
        message: 'Coach is unavailable right now. Try again in a moment.',
      });
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
  const data = await generateJsonWithGemini(prompt, apiKey, { temperature: 0.2 });

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

async function generateJsonWithGemini(prompt, apiKey, options = {}) {
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
            temperature: typeof options.temperature === 'number' ? options.temperature : 0.2,
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
  }

  if (!data) {
    throw new Error(`Gemini request failed for all models: ${lastError}`);
  }

  return data;
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
  const weekStart = startOfWeek(new Date());

  const scheduleDays = normalizedSplit.map((type, index) => ({
    date: new Date(weekStart.getTime() + index * 24 * 60 * 60 * 1000).toISOString(),
    type,
    status: 'scheduled',
  }));

  const workoutDays = scheduleDays.map((day) => ({
    date: day.date,
    type: day.type,
    estimatedMinutes: lengthBucketToMinutes(
      typeof plan.workoutLength === 'string' && plan.workoutLength.trim()
        ? plan.workoutLength
        : String(profile.workoutLength || '25-35'),
    ),
    status: 'scheduled',
    exercises: buildExercisesForType(day.type, profile),
  }));

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
    activeWeekStartDate: weekStart.toISOString(),
    scheduleDays,
    skillTracks: arrayOfStrings(plan.skillTrack)
      .slice(0, 3)
      .map((name) => ({
        name,
        currentStep: 1,
        ladderSteps: [`${name} Foundation`, `${name} Capacity`, `${name} Strength`, `${name} Control`],
      })),
    volumeTargets: buildVolumeTargets(profile.goal),
    progressionRules: [
      'If all prescribed reps are met for 2 sessions, increase progression by 1 step.',
      'If RPE > 9 for 2 sessions, deload by reducing one set.',
      'If workout day is missed and adaptation is enabled, reshuffle remaining sessions.',
    ],
    workoutDays,
    generator: 'ai',
  };
}

function buildCoachPrompt({ uid, message, context }) {
  return [
    'You are SkillMax AI Coach.',
    'You must provide practical coaching guidance and optionally return structured plan/workout edits.',
    'Return ONLY valid JSON with this shape:',
    '{"message":"string","proposedPlanDiff":{"action":"adapt_week|keep_schedule|none","before":"string","after":"string","notes":"string"},"proposedWorkoutEdits":{"action":"swap_today|ease_today|none","summary":"string","edits":[{"exercise":"string","change":"string"}]}}',
    'Rules:',
    '- If user missed a day and asks for adjustment, set proposedPlanDiff.action to adapt_week.',
    '- If user reports pain/injury, propose safer exercise edits.',
    '- Keep message concise, supportive, and specific to user context.',
    '- If no change needed, set actions to "none".',
    `User ID: ${uid}`,
    `User message: ${message}`,
    `Context: ${JSON.stringify(context)}`,
  ].join('\n');
}

function normalizeCoachResponse(raw) {
  const text =
    raw.candidates &&
    raw.candidates[0] &&
    raw.candidates[0].content &&
    raw.candidates[0].content.parts &&
    raw.candidates[0].content.parts[0] &&
    raw.candidates[0].content.parts[0].text
      ? raw.candidates[0].content.parts[0].text
      : '';
  const parsed = parseJsonSafely(text);
  if (!parsed || typeof parsed !== 'object') {
    return {
      message: 'I can adjust your plan and swap exercises. Tell me what feels off today.',
      proposedPlanDiff: null,
      proposedWorkoutEdits: null,
    };
  }

  const message = typeof parsed.message === 'string' && parsed.message.trim()
    ? parsed.message.trim()
    : 'I can adjust your plan and swap exercises. Tell me what feels off today.';

  const planDiff = parsed.proposedPlanDiff && typeof parsed.proposedPlanDiff === 'object'
    ? parsed.proposedPlanDiff
    : null;
  const workoutEdits = parsed.proposedWorkoutEdits && typeof parsed.proposedWorkoutEdits === 'object'
    ? parsed.proposedWorkoutEdits
    : null;

  return {
    message,
    proposedPlanDiff: planDiff,
    proposedWorkoutEdits: workoutEdits,
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

function buildVolumeTargets(goal) {
  if (String(goal || '').toLowerCase().includes('mobility')) {
    return [
      { category: 'Mobility', target: 5, completed: 0, unit: 'sessions' },
      { category: 'Skill practice', target: 3, completed: 0, unit: 'sessions' },
      { category: 'Core', target: 6, completed: 0, unit: 'sets' },
    ];
  }
  return [
    { category: 'Push', target: 12, completed: 0, unit: 'sets' },
    { category: 'Pull', target: 12, completed: 0, unit: 'sets' },
    { category: 'Legs', target: 10, completed: 0, unit: 'sets' },
    { category: 'Core', target: 10, completed: 0, unit: 'sets' },
    { category: 'Skill practice', target: 4, completed: 0, unit: 'sessions' },
    { category: 'Mobility', target: 3, completed: 0, unit: 'sessions' },
  ];
}

function buildExercisesForType(type, profile) {
  const lower = String(type || '').toLowerCase();
  const noEquipment = Array.isArray(profile.equipment)
    && profile.equipment.some((e) => String(e).toLowerCase().includes('none'));
  const pullZero = String(profile.baselinePull || '').toLowerCase().includes('0');

  if (lower.includes('pull')) {
    return [
      {
        id: 'pull_focus',
        name: pullZero || noEquipment ? 'Band-Assisted Row' : 'Strict Pull-Up',
        category: 'pull',
        progressionLevel: pullZero ? 1 : 3,
        sets: 4,
        reps: pullZero ? '6-8' : '5-7',
        restSeconds: 120,
        altExercises: ['Ring Row', 'Inverted Row'],
      },
      {
        id: 'pull_accessory',
        name: 'Scapular Pull-Up',
        category: 'pull',
        progressionLevel: 2,
        sets: 3,
        reps: '10',
        restSeconds: 90,
        altExercises: ['Band Pulldown'],
      },
    ];
  }

  if (lower.includes('legs')) {
    return [
      {
        id: 'leg_focus',
        name: 'Bulgarian Split Squat',
        category: 'legs',
        progressionLevel: 3,
        sets: 4,
        reps: '8/side',
        restSeconds: 90,
        altExercises: ['Reverse Lunge'],
      },
      {
        id: 'core_finish',
        name: 'Hollow Hold',
        category: 'core',
        progressionLevel: 2,
        sets: 4,
        reps: '25s',
        restSeconds: 60,
        altExercises: ['Dead Bug'],
      },
    ];
  }

  if (lower.includes('skill')) {
    const skill = Array.isArray(profile.skills) && profile.skills.length ? String(profile.skills[0]) : 'Handstand';
    return [
      {
        id: 'skill_focus',
        name: `${skill} Progression`,
        category: 'skill',
        progressionLevel: 2,
        sets: 5,
        reps: '20s',
        restSeconds: 75,
        altExercises: ['Wall Drill'],
      },
      {
        id: 'skill_support',
        name: 'Scapular Stability Drill',
        category: 'skill',
        progressionLevel: 2,
        sets: 3,
        reps: '10',
        restSeconds: 60,
        altExercises: ['Band Pull-Apart'],
      },
    ];
  }

  if (lower.includes('mobility')) {
    return [
      {
        id: 'mobility_flow',
        name: 'Shoulder CARs',
        category: 'mobility',
        progressionLevel: 2,
        sets: 3,
        reps: '8',
        restSeconds: 40,
        altExercises: ['Wall Slides'],
      },
      {
        id: 'spine_flow',
        name: 'Thoracic Rotation Flow',
        category: 'mobility',
        progressionLevel: 2,
        sets: 3,
        reps: '8/side',
        restSeconds: 40,
        altExercises: ['Open Book'],
      },
    ];
  }

  return [
    {
      id: 'push_focus',
      name: noEquipment ? 'Deficit Push-Up' : 'Ring Dip',
      category: 'push',
      progressionLevel: 3,
      sets: 4,
      reps: '6-8',
      restSeconds: 105,
      altExercises: ['Bench Dip', 'Elevated Push-Up'],
    },
    {
      id: 'push_accessory',
      name: 'Pseudo Planche Push-Up',
      category: 'push',
      progressionLevel: 3,
      sets: 3,
      reps: '8',
      restSeconds: 90,
      altExercises: ['Incline Push-Up'],
    },
  ];
}

function lengthBucketToMinutes(bucket) {
  const value = String(bucket || '');
  if (value.includes('15-20')) return 20;
  if (value.includes('25-35')) return 32;
  if (value.includes('60+')) return 60;
  return 48;
}

function startOfWeek(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + diff);
  return d;
}
