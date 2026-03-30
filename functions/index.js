const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");
const admin = require("firebase-admin");
const { speciesCacheKey } = require("./lib/utils");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
const kindwiseKey = defineSecret("KINDWISE_API_KEY");
const openWeatherKey = defineSecret("OPENWEATHER_API_KEY");

// ─── Kindwise plant.id — species identification only ─────────────────────────

async function identifySpecies(imageUrl, apiKey) {
  const imgRes = await fetch(imageUrl);
  if (!imgRes.ok) throw new Error(`Image download failed: ${imgRes.status}`);
  const imgBuffer = await imgRes.arrayBuffer();
  const base64 = Buffer.from(imgBuffer).toString("base64");

  console.log("Calling Kindwise plant.id for species ID...");

  const res = await fetch("https://plant.id/api/v3/identification", {
    method: "POST",
    headers: {
      "Api-Key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      images: [`data:image/jpeg;base64,${base64}`],
    }),
  });

  const responseText = await res.text();
  console.log(`Kindwise status: ${res.status}`);
  console.log(`Kindwise response: ${responseText.substring(0, 500)}`);

  if (!res.ok) {
    throw new HttpsError(
      "internal",
      `Kindwise API error ${res.status}: ${responseText}`
    );
  }

  return JSON.parse(responseText);
}

function parseSpeciesResult(data) {
  const result = data.result;

  if (!result?.is_plant?.binary) {
    throw new HttpsError("invalid-argument", "No plant detected in this image");
  }

  const topSpecies = result.classification?.suggestions?.[0];
  const scientificName = topSpecies?.name ?? "Unknown Plant";
  const commonNames = topSpecies?.details?.common_names ?? [];
  const commonName = commonNames[0] ?? scientificName;
  const speciesScore = topSpecies?.probability ?? 0;

  const displayName =
    commonName && commonName !== scientificName
      ? `${commonName} (${scientificName})`
      : scientificName;

  const genus = scientificName.split(" ")[0] ?? "";

  console.log(
    `Identified: ${displayName} — score: ${(speciesScore * 100).toFixed(0)}%`
  );
  console.log(`Top 3 suggestions:`,
    result.classification?.suggestions
      ?.slice(0, 3)
      .map((s) => `${s.name} (${(s.probability * 100).toFixed(0)}%)`)
      .join(", ")
  );

  return { displayName, scientificName, commonName, genus, speciesScore };
}

function scoreToCertainty(score) {
  if (score >= 0.70) return "certain";
  if (score >= 0.35) return "likely";
  return "uncertain";
}

// ─── Retry helper for transient Claude overload errors (529) ─────────────────

async function withRetry(fn, maxAttempts = 3) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (err?.status === 529 && attempt < maxAttempts) {
        const delay = Math.pow(2, attempt) * 1000; // 2s, 4s
        console.warn(`Claude overloaded (attempt ${attempt}/${maxAttempts}), retrying in ${delay}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
      } else {
        throw err;
      }
    }
  }
}

// ─── Claude: full analysis (cache miss) — disease detection + species info ────

async function diagnoseAndDescribe(imageUrl, species, apiKey, weatherContext = '') {
  const client = new Anthropic({ apiKey });
  const { displayName, scientificName, genus, speciesScore } = species;

  const prompt = `You are PlantDoctor, a world-class plant pathologist. A specialized identification API has confirmed:
  Species: ${displayName} (${(speciesScore * 100).toFixed(0)}% confidence)

STEP 1 — VISUAL INSPECTION (do this mentally before writing JSON)
Examine the image systematically:

LEAVES
• Color: Any yellowing (chlorosis), browning, blackening, purple/red discoloration, or pale patches?
• Spots/lesions: Water-soaked spots, dry necrotic spots, rings, halos, or powdery coatings?
• Texture: Wilting, drooping, curling inward or outward, crispy edges, or distortion?
• Patterns: Mosaic/mottled pattern (viral), uniform yellowing (nutrient), edge burn (salt/drought)?

STEMS & PETIOLES
• Darkening, water-soaked lesions, cankers, soft rot, or unusual discoloration at base?
• Wilting of otherwise green stems (bacterial wilt)?

OVERALL PLANT
• Is the whole plant or only parts affected? (Patchy = biotic; uniform = abiotic)
• Signs of pests: holes, stippling, webbing, sticky residue, insect frass?
• Root/crown rot signs if any part of soil/base is visible?

STEP 2 — DIAGNOSE
Based on what you physically see, identify all distinct problems. Common ${genus || scientificName} problems:
- Fungal: leaf spots with defined edges/rings/halos, powdery white coating, gray mold, rust pustules
- Bacterial: water-soaked lesions that turn brown, stem blackening, wilting with no dry tissue, foul smell evidence
- Viral: mosaic/mottled leaves, stunted growth, distorted/curled leaves with no spots
- Nutrient: interveinal chlorosis (iron/manganese), overall pale yellow (nitrogen), purple tint (phosphorus), tip burn (calcium/potassium)
- Environmental: uniform crispy edges (drought/salt), bleached patches (sunburn), dark mushy areas (overwatering/root rot)
- Pests: irregular holes, stippling, webbing, sticky deposits

${weatherContext ? `\nCURRENT LOCAL CONDITIONS (consider these as contributing factors):\n${weatherContext}\n` : ''}
STEP 3 — OUTPUT
Return ONLY this JSON (no markdown, no code fences):
{
  "speciesInfo": {
    "origin": "Geographic origin",
    "lifespan": "Annual / Perennial / Biennial",
    "difficulty": "Easy / Moderate / Difficult",
    "light": "Light requirement",
    "water": "Watering frequency and method",
    "humidity": "Preferred humidity",
    "temperature": "Ideal range in Fahrenheit",
    "toxicity": "Toxic to [cats/dogs/humans] — specify — or Safe",
    "funFact": "One genuinely interesting fact"
  },
  "overallSeverity": "healthy|low|medium|high",
  "summary": "2-3 sentences: name this plant, then describe exactly what health issues you observe or confirm it looks healthy.",
  "followUpIn": <integer days>,
  "issues": [
    {
      "name": "Specific condition name (e.g. 'Bacterial Leaf Spot', 'Iron Chlorosis', 'Powdery Mildew')",
      "severity": "low|medium|high",
      "cause": "Pathogen or root cause",
      "symptoms": ["describe what you SEE in this specific image", "another visible sign"],
      "treatment": ["Immediate action step", "Follow-up step", "Monitoring step"],
      "preventionTips": ["Tip 1", "Tip 2"]
    }
  ]
}

CRITICAL RULES:
- symptoms[] must describe what is ACTUALLY VISIBLE in this photo — never generic textbook symptoms
- Include ALL distinct issues you observe — plants often have more than one problem
- overallSeverity = worst single issue severity (or "healthy" if none)
- If truly healthy: empty issues array, overallSeverity "healthy"
- Never invent issues; never ignore visible symptoms
- Return ONLY the JSON`;

  const response = await withRetry(() => client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 2048,
    messages: [
      {
        role: "user",
        content: [
          { type: "image", source: { type: "url", url: imageUrl } },
          { type: "text", text: prompt },
        ],
      },
    ],
  }));

  let text = response.content[0].text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  return JSON.parse(text);
}

// ─── Claude: disease detection only (cache hit) — ~35-40% fewer tokens ────────

async function diagnoseDisease(imageUrl, species, apiKey, weatherContext = '') {
  const client = new Anthropic({ apiKey });
  const { displayName, scientificName, genus, speciesScore } = species;

  const prompt = `You are PlantDoctor, a world-class plant pathologist. A specialized identification API has confirmed:
  Species: ${displayName} (${(speciesScore * 100).toFixed(0)}% confidence)

STEP 1 — VISUAL INSPECTION (do this mentally before writing JSON)
Examine the image systematically:

LEAVES
• Color: Any yellowing (chlorosis), browning, blackening, purple/red discoloration, or pale patches?
• Spots/lesions: Water-soaked spots, dry necrotic spots, rings, halos, or powdery coatings?
• Texture: Wilting, drooping, curling inward or outward, crispy edges, or distortion?
• Patterns: Mosaic/mottled pattern (viral), uniform yellowing (nutrient), edge burn (salt/drought)?

STEMS & PETIOLES
• Darkening, water-soaked lesions, cankers, soft rot, or unusual discoloration at base?
• Wilting of otherwise green stems (bacterial wilt)?

OVERALL PLANT
• Is the whole plant or only parts affected? (Patchy = biotic; uniform = abiotic)
• Signs of pests: holes, stippling, webbing, sticky residue, insect frass?
• Root/crown rot signs if any part of soil/base is visible?

STEP 2 — DIAGNOSE
Based on what you physically see, identify all distinct problems. Common ${genus || scientificName} problems:
- Fungal: leaf spots with defined edges/rings/halos, powdery white coating, gray mold, rust pustules
- Bacterial: water-soaked lesions that turn brown, stem blackening, wilting with no dry tissue, foul smell evidence
- Viral: mosaic/mottled leaves, stunted growth, distorted/curled leaves with no spots
- Nutrient: interveinal chlorosis (iron/manganese), overall pale yellow (nitrogen), purple tint (phosphorus), tip burn (calcium/potassium)
- Environmental: uniform crispy edges (drought/salt), bleached patches (sunburn), dark mushy areas (overwatering/root rot)
- Pests: irregular holes, stippling, webbing, sticky deposits

${weatherContext ? `\nCURRENT LOCAL CONDITIONS (consider these as contributing factors):\n${weatherContext}\n` : ''}
STEP 3 — OUTPUT
Return ONLY this JSON (no markdown, no code fences):
{
  "overallSeverity": "healthy|low|medium|high",
  "summary": "2-3 sentences: name this plant, then describe exactly what health issues you observe or confirm it looks healthy.",
  "followUpIn": <integer days>,
  "issues": [
    {
      "name": "Specific condition name",
      "severity": "low|medium|high",
      "cause": "Pathogen or root cause",
      "symptoms": ["describe what you SEE in this specific image"],
      "treatment": ["Immediate action step", "Follow-up step"],
      "preventionTips": ["Tip 1", "Tip 2"]
    }
  ]
}

CRITICAL RULES:
- symptoms[] must describe what is ACTUALLY VISIBLE in this photo — never generic textbook symptoms
- Include ALL distinct issues you observe
- overallSeverity = worst single issue severity (or "healthy" if none)
- If truly healthy: empty issues array, overallSeverity "healthy"
- Return ONLY the JSON`;

  const response = await withRetry(() => client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1536,
    messages: [
      {
        role: "user",
        content: [
          { type: "image", source: { type: "url", url: imageUrl } },
          { type: "text", text: prompt },
        ],
      },
    ],
  }));

  let text = response.content[0].text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  return JSON.parse(text);
}

// ─── Internal weather fetch helper (used by both getWeather and diagnosePlant) ─

function mapCondition(weatherId) {
  if (weatherId >= 200 && weatherId < 300) return 'stormy';
  if (weatherId >= 300 && weatherId < 600) return 'rainy';
  if (weatherId >= 600 && weatherId < 700) return 'rainy'; // snow
  if (weatherId === 800) return 'sunny';
  return 'cloudy';
}

async function fetchWeatherFromApi(lat, lng, apiKey) {
  const [currentRes, forecastRes] = await Promise.all([
    fetch(`https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lng}&appid=${apiKey}&units=metric`),
    fetch(`https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lng}&appid=${apiKey}&units=metric&cnt=40`),
  ]);

  if (!currentRes.ok || !forecastRes.ok) {
    throw new Error(`OpenWeatherMap error: ${currentRes.status} / ${forecastRes.status}`);
  }

  const [currentData, forecastData] = await Promise.all([
    currentRes.json(),
    forecastRes.json(),
  ]);

  const current = {
    tempC: Math.round(currentData.main.temp * 10) / 10,
    humidityPct: currentData.main.humidity,
    uvIndex: 0, // not available on OWM 2.5 free tier
    rainChancePct: currentData.rain?.['1h'] > 0 ? 100 : 0,
    condition: mapCondition(currentData.weather[0].id),
    windKph: Math.round(currentData.wind.speed * 3.6 * 10) / 10,
  };

  // Aggregate 3-hour slots into daily forecast
  const days = {};
  for (const item of forecastData.list) {
    const date = item.dt_txt.split(' ')[0];
    if (!days[date]) {
      days[date] = { rainChancePct: 0, minTempC: item.main.temp_min, maxTempC: item.main.temp_max };
    }
    days[date].rainChancePct = Math.max(days[date].rainChancePct, Math.round((item.pop ?? 0) * 100));
    days[date].minTempC = Math.min(days[date].minTempC, item.main.temp_min);
    days[date].maxTempC = Math.max(days[date].maxTempC, item.main.temp_max);
  }

  const forecast = Object.entries(days)
    .slice(0, 5)
    .map(([date, data]) => ({
      date,
      rainChancePct: data.rainChancePct,
      minTempC: Math.round(data.minTempC * 10) / 10,
      maxTempC: Math.round(data.maxTempC * 10) / 10,
    }));

  const now = new Date();
  return {
    current,
    forecast,
    fetchedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + 30 * 60 * 1000).toISOString(),
  };
}

async function getWeatherCached(lat, lng, apiKey) {
  const key = `${parseFloat(lat).toFixed(2)}_${parseFloat(lng).toFixed(2)}`;
  const cacheRef = db.collection('weatherCache').doc(key);

  let cached;
  try {
    cached = await Promise.race([
      cacheRef.get(),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Firestore weather cache read timeout after 10s')), 10000)
      ),
    ]);
  } catch (err) {
    console.error(`Weather cache read failed: ${err.message} — fetching fresh from OpenWeatherMap`);
    cached = { exists: false };
  }

  if (cached.exists && new Date(cached.data().expiresAt) > new Date()) {
    console.log(`Weather cache HIT for ${key}`);
    return cached.data();
  }

  console.log(`Weather cache MISS for ${key} — fetching from OpenWeatherMap`);
  const result = await fetchWeatherFromApi(lat, lng, apiKey);
  cacheRef.set(result).catch((err) => console.error('Weather cache write failed:', err));
  return result;
}

// ─── Cloud Function: getWeather callable ─────────────────────────────────────

exports.getWeather = onCall(
  { secrets: [openWeatherKey] },
  async (request) => {
    const { lat, lng } = request.data;
    if (lat == null || lng == null) {
      throw new HttpsError('invalid-argument', 'lat and lng are required');
    }
    return getWeatherCached(lat, lng, openWeatherKey.value());
  }
);

// ─── Scheduled: daily weather alerts (frost + heat wave) ─────────────────────

exports.sendWeatherAlerts = onSchedule(
  { schedule: '0 7 * * *', timeZone: 'UTC', secrets: [openWeatherKey] },
  async () => {
    const usersSnap = await db.collection('users')
      .where('fcmToken', '!=', null)
      .get();

    let sent = 0;
    const tasks = usersSnap.docs.map(async (doc) => {
      const { fcmToken, lastLat, lastLng } = doc.data();
      if (!fcmToken || lastLat == null || lastLng == null) return;

      let weatherResult;
      try {
        weatherResult = await getWeatherCached(lastLat, lastLng, openWeatherKey.value());
      } catch (err) {
        console.warn(`Weather fetch failed for user ${doc.id}:`, err.message);
        return;
      }

      const tomorrow = weatherResult.forecast?.[0];
      if (!tomorrow) return;

      const messages = [];

      if (tomorrow.minTempC <= 2) {
        messages.push({
          token: fcmToken,
          notification: {
            title: '❄️ Frost Alert',
            body: `Tomorrow's low is ${tomorrow.minTempC.toFixed(1)}°C. Move sensitive plants indoors tonight.`,
          },
        });
      }

      if (tomorrow.maxTempC >= 38) {
        messages.push({
          token: fcmToken,
          notification: {
            title: '🌡️ Heat Wave Alert',
            body: `Tomorrow's high is ${tomorrow.maxTempC.toFixed(1)}°C. Water plants in the evening and provide shade.`,
          },
        });
      }

      for (const msg of messages) {
        try {
          await admin.messaging().send(msg);
          sent++;
        } catch (err) {
          console.warn(`FCM send failed for user ${doc.id}:`, err.message);
        }
      }
    });

    await Promise.allSettled(tasks);
    console.log(`sendWeatherAlerts complete — ${sent} alert(s) sent to ${usersSnap.docs.length} user(s) checked`);
  }
);

// ─── USDA hardiness zone detection (US only via phzmapi.org) ─────────────────

async function detectHardinessZone(lat, lng) {
  try {
    const res = await fetch(`https://phzmapi.org/${lat}/${lng}.json`, {
      signal: AbortSignal.timeout(3000), // 3s timeout — non-critical
    });
    if (!res.ok) return null;
    const data = await res.json();
    return data.zone ?? null;
  } catch {
    return null; // non-US coordinates or API unavailable — silently return null
  }
}

// ─── Main export ──────────────────────────────────────────────────────────────

exports.diagnosePlant = onCall(
  { secrets: [anthropicKey, kindwiseKey, openWeatherKey], timeoutSeconds: 120, minInstances: 1 },
  async (request) => {
    const { imageUrl, lat, lng } = request.data;
    const uid = request.auth?.uid;

    // Step 1: Kindwise — species identification
    const kindwiseRaw = await identifySpecies(imageUrl, kindwiseKey.value());
    const species = parseSpeciesResult(kindwiseRaw);

    // Step 2: Weather (optional — only if lat/lng provided)
    let weatherData = null;
    let hardinessZone = null;
    let weatherContext = '';

    if (lat != null && lng != null) {
      try {
        weatherData = await getWeatherCached(lat, lng, openWeatherKey.value());
        const w = weatherData.current;
        const tomorrow = weatherData.forecast?.[0];
        weatherContext = [
          `Temperature: ${w.tempC}°C, Humidity: ${w.humidityPct}%, Conditions: ${w.condition}`,
          `Wind: ${w.windKph} km/h, UV index: ${w.uvIndex}`,
          tomorrow
            ? `Tomorrow: High ${tomorrow.maxTempC}°C / Low ${tomorrow.minTempC}°C, ${tomorrow.rainChancePct}% rain chance`
            : '',
          'Consider whether these conditions may be stressing the plant.',
        ].filter(Boolean).join('\n');

        // Detect hardiness zone (non-blocking — doesn't delay response if slow)
        hardinessZone = await detectHardinessZone(lat, lng);
      } catch (err) {
        console.warn('Weather fetch failed — continuing without weather context:', err.message);
      }

      // Store user's last location for weather alert scheduler (non-blocking)
      if (uid) {
        db.collection('users').doc(uid).set({
          lastLat: lat,
          lastLng: lng,
          lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
          ...(hardinessZone ? { hardinessZone } : {}),
        }, { merge: true }).catch((err) => console.error('User location update failed:', err));
      }
    }

    // Step 3: Species cache lookup
    const cacheKey = speciesCacheKey(species.scientificName);
    const cacheRef = db.collection('speciesCache').doc(cacheKey);
    console.log(`Species cache lookup starting for ${cacheKey}...`);
    let cacheDoc;
    try {
      cacheDoc = await Promise.race([
        cacheRef.get(),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Firestore read timeout after 10s')), 10000)
        ),
      ]);
      console.log(`Species cache lookup completed — exists: ${cacheDoc.exists}`);
    } catch (err) {
      console.error(`Species cache read failed: ${err.message} — treating as cache miss`);
      cacheDoc = { exists: false };
    }

    let claudeResult;
    if (cacheDoc.exists) {
      console.log(`Species cache HIT for ${species.scientificName}`);
      const diseaseResult = await diagnoseDisease(imageUrl, species, anthropicKey.value(), weatherContext);
      const { cachedAt: _cachedAt, ...speciesInfoData } = cacheDoc.data();
      claudeResult = { speciesInfo: speciesInfoData, ...diseaseResult };
    } else {
      console.log(`Species cache MISS for ${species.scientificName}`);
      claudeResult = await diagnoseAndDescribe(imageUrl, species, anthropicKey.value(), weatherContext);
      cacheRef.set({
        ...claudeResult.speciesInfo,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch((err) => console.error('Species cache write failed:', err));
    }

    // Step 4: Assemble final diagnosis
    const diagnosis = {
      plantSpecies: species.displayName,
      identificationCertainty: scoreToCertainty(species.speciesScore),
      identificationLevel: species.speciesScore >= 0.15 ? 'species' : 'unknown',
      ...claudeResult,
      ...(weatherData ? { weatherAtScan: weatherData.current } : {}),
      ...(hardinessZone != null ? { usHardinessZone: hardinessZone } : {}),
    };

    return { success: true, diagnosis };
  }
);
