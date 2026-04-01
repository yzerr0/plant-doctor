const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

exports.diagnosePlant = onCall(
  { secrets: [anthropicKey], timeoutSeconds: 60, minInstances: 1 },
  async (request) => {
    const { imageUrl } = request.data;
    const client = new Anthropic({ apiKey: anthropicKey.value() });

    const response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "url", url: imageUrl },
            },
            {
              type: "text",
              text: `You are PlantDoctor, an expert botanist and plant pathologist.

Analyze this plant image and return ONLY a raw JSON object.
No markdown, no code fences, no explanation — just the JSON.

Use exactly this structure:
{
  "plantSpecies": "Common name (Scientific name) or 'Unknown Plant'",
  "confidence": 0.0,
  "speciesInfo": {
    "origin": "Where this plant originates from",
    "lifespan": "Annual / Perennial / Biennial",
    "difficulty": "Easy / Moderate / Difficult",
    "light": "Full sun / Partial shade / Low light / etc.",
    "water": "How often and how much",
    "humidity": "Preferred humidity level",
    "temperature": "Ideal temperature range in Fahrenheit",
    "toxicity": "Toxic to pets and/or humans, or Safe",
    "funFact": "One interesting fact about this species"
  },
  "overallSeverity": "healthy",
  "summary": "2-3 sentence plain English summary of this plant's current state.",
  "followUpIn": 7,
  "issues": [
    {
      "name": "Issue name",
      "severity": "low",
      "cause": "What caused this issue",
      "symptoms": ["visible symptom 1", "visible symptom 2"],
      "treatment": ["Step 1", "Step 2", "Step 3"],
      "preventionTips": ["Tip 1", "Tip 2"]
    }
  ]
}

Rules:
- overallSeverity must be exactly one of: healthy, low, medium, high (lowercase)
- severity inside each issue must be exactly one of: low, medium, high (lowercase)
- If the plant looks healthy, return an empty issues array and overallSeverity "healthy"
- If no plant is visible, return {"error": "No plant detected in this image"}
- confidence is a float between 0.0 and 1.0
- Return ONLY the JSON object, nothing else whatsoever`,
            },
          ],
        },
      ],
    });

    let text = response.content[0].text.trim();
    text = text
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```\s*$/i, "")
      .trim();

    const diagnosis = JSON.parse(text);
    if (diagnosis.error) throw new Error(diagnosis.error);

    return { success: true, diagnosis };
  }
);
