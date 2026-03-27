# PlantDoctor — 2-Minute Demo Script

---

**[0:00–0:20] Pitch**
"PlantDoctor identifies any plant and diagnoses its health from a single photo.
Point your phone at a plant — you get the species, what's wrong with it, how to treat it, and a full care guide. Backed by a specialized plant health AI and Claude."

---

**[0:20–0:45] Design + Code (quick overview)**
- Flutter app — Android and iOS from one codebase
- 3-layer AI pipeline: Kindwise (species ID) → Claude Vision (disease detection + care guide) → Firestore (persistence)
- API keys in Firebase Secret Manager — never in the app
- Severity system: green → yellow → orange → red, consistent across all screens

---

**[0:45–1:30] Live Demo**
1. Tap **Scan Plant** → pick a plant photo with visible disease
2. Loading screen ("Analyzing your plant...")
3. Result screen — walk top to bottom:
   - Species name + confidence chip
   - Severity banner (red = high severity)
   - Tap a care grid cell → full detail sheet
   - Expand an issue card → cause, symptoms, treatment steps
4. Navigate back → scan appears in journal list
5. Tap journal entry → full result reloads (proves persistence)

---

**[1:30–1:50] Current Version + Timeline**

**v0.2.0 — demo-ready today**
Working: species ID, disease detection, care guide, journal, persistence, anonymous auth

**Roadmap:**
- v0.3 — camera input, Firebase security rules, Google sign-in
- v0.4 — custom CNN trained on PlantVillage (replace Kindwise)
- v1.0 — Play Store + App Store, ~6–8 weeks out

---

**[1:50–2:00] Close**
"The next step is training our own disease detection model on the PlantVillage dataset — that removes the dependency on a third-party API and gives us full control over accuracy. Questions?"
