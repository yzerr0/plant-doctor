const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");
const admin = require("firebase-admin");
const { speciesCacheKey } = require("./lib/utils");

admin.initializeApp();
const db = admin.firestore();

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
const kindwiseKey = defineSecret("KINDWISE_API_KEY");

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

// ─── Claude: full analysis (cache miss) — disease detection + species info ────

async function diagnoseAndDescribe(imageUrl, species, apiKey) {
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

  const response = await client.messages.create({
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
  });

  let text = response.content[0].text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  return JSON.parse(text);
}

// ─── Claude: disease detection only (cache hit) — ~35-40% fewer tokens ────────

async function diagnoseDisease(imageUrl, species, apiKey) {
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

  const response = await client.messages.create({
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
  });

  let text = response.content[0].text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  return JSON.parse(text);
}

// ─── Main export ──────────────────────────────────────────────────────────────

exports.diagnosePlant = onCall(
  { secrets: [anthropicKey, kindwiseKey], timeoutSeconds: 120, minInstances: 1 },
  async (request) => {
    const { imageUrl } = request.data;

    // Step 1: Kindwise — species identification
    const kindwiseRaw = await identifySpecies(imageUrl, kindwiseKey.value());
    const species = parseSpeciesResult(kindwiseRaw);

    // Step 2: Species cache lookup
    const cacheKey = speciesCacheKey(species.scientificName);
    const cacheRef = db.collection("speciesCache").doc(cacheKey);
    const cacheDoc = await cacheRef.get();

    let claudeResult;
    if (cacheDoc.exists) {
      // Cache HIT — disease detection only (~35–40% fewer Claude output tokens)
      console.log(`Species cache HIT for ${species.scientificName}`);
      const diseaseResult = await diagnoseDisease(imageUrl, species, anthropicKey.value());
      const { cachedAt: _cachedAt, ...speciesInfoData } = cacheDoc.data();
      claudeResult = {
        speciesInfo: speciesInfoData,
        ...diseaseResult,
      };
    } else {
      // Cache MISS — full analysis, then write species info to cache
      console.log(`Species cache MISS for ${species.scientificName}`);
      claudeResult = await diagnoseAndDescribe(imageUrl, species, anthropicKey.value());
      // Non-blocking cache write — do not await, do not block the response
      cacheRef
        .set({
          ...claudeResult.speciesInfo,
          cachedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
        .catch((err) => console.error("Species cache write failed:", err));
    }

    // Step 3: Merge into final diagnosis object
    const diagnosis = {
      plantSpecies: species.displayName,
      identificationCertainty: scoreToCertainty(species.speciesScore),
      identificationLevel: species.speciesScore >= 0.15 ? "species" : "unknown",
      ...claudeResult,
    };

    return { success: true, diagnosis };
  }
);
