# Ambient Clinical Scribe & Linked Evidence Specification

GozVision incorporates an ambient clinical scribe engine tailored specifically for optometry and ophthalmology examinations.

---

## 1. Core Philosophy: "Grounding Over Generation"

Clinical AI documentation tools often suffer from clinician skepticism due to hallucinated details or ungrounded diagnoses. GozVision adheres to strict clinical principles:
1. **Draft-Only Status:** The scribe strictly produces an editable **DRAFT** for practitioner review. The AI never finalizes or signs off on a medical chart autonomously.
2. **Conversation Support Only:** The prompt strictly forbids inventing exam findings. Where data is absent, the model records `[not documented]`.
3. **Optometric Terminology:** Pre-trained prompts recognize refractive notation, intraocular pressure (IOP), visual acuity (VA), slit lamp findings, and ophthalmic medications (e.g. latanoprost, timolol).

---

## 2. SOAP Note Architecture

The ambient dialogue is parsed into standard clinical SOAP sections:

| Section | Focus in Eye Care | Example Extracted Content |
|---|---|---|
| **SUBJECTIVE** | Chief complaint, visual changes, comfort | *"Blurry distance vision in right eye for 3 weeks; mild evening stinging with drops."* |
| **OBJECTIVE** | Refraction, IOP, slit lamp, fundus exam | *"OD: 20/40, OS: 20/25. IOP OD 15 mmHg, OS 16 mmHg via applanation. Cornea clear OU."* |
| **ASSESSMENT** | Clinical impression | *"Primary open-angle glaucoma stable; mild surface dryness."* |
| **PLAN** | Rx, medications, follow-up horizon | *"Continue latanoprost 1 gtt QHS OU. Prescribed preservative-free tears QID. Follow-up 3 months."* |

---

## 3. "Linked Evidence" (Abridge-Style Verification)

In [`apps/clinic/lib/modules/scribe_page.dart`](file:///d:/pacy_labs/gozvision/apps/clinic/lib/modules/scribe_page.dart), each section and clinical metric includes **Linked Evidence**:

```
┌────────────────────────────────────────────────────────┐
│ OBJECTIVE: IOP OD 15 mmHg, OS 16 mmHg. Cornea clear.   │
│ [✓ Verify Quote] ──▶ Opens Evidence Modal              │
└─────────────────────────────────────────┬──────────────┘
                                          │
                                          ▼
┌────────────────────────────────────────────────────────┐
│ EVIDENCE MODAL                                         │
│ Clinical Extract: "IOP OD 15 mmHg, OS 16 mmHg"         │
│ ────────────────────────────────────────────────────── │
│ Source Transcript Snippet:                             │
│ "Doctor: Let's check intraocular pressures today.      │
│  OD is 15, OS is 16. Cornea is clear."                 │
└────────────────────────────────────────────────────────┘
```

Clinicians can verify critical measurements in seconds with a single click, eliminating "black box" hesitation before signing off on charts.

---

## 4. Doctor Clinical Copilot & Quick Reference

Integrated directly into [`apps/clinic/lib/screens/clinic_shell.dart`](file:///d:/pacy_labs/gozvision/apps/clinic/lib/screens/clinic_shell.dart) and [`apps/clinic/lib/modules/scribe_page.dart`](file:///d:/pacy_labs/gozvision/apps/clinic/lib/modules/scribe_page.dart), the **Doctor Quick-Reference (`DoctorReferenceDialog`)** provides practitioners with real-time, evidence-based clinical guidance during exam reviews:
- **Instant Guideline Lookups:** AAO Preferred Practice Patterns (PPP 2025/2026), AOA Clinical Practice Guidelines, TFOS DEWS II, and NEI AREDS2 trials.
- **Critical Pharmacology Checks:** Absolute contraindications for ocular medications (e.g., Timolol in asthma/COPD or severe sinus bradycardia; Prostaglandin analogs in active uveitis).
- **Metric Risk Algorithms:** Target IOP calculations based on baseline pressure and CCT (pachymetry), C/D ratio asymmetry thresholds (>0.2), and diabetic retinopathy screening horizons.

---

## 5. Clinical Knowledge Base Architecture & Scaling

GozVision utilizes a hybrid static-dynamic Retrieval-Augmented Generation (RAG) architecture engineered to keep clinical information current without service interruption:

```
┌────────────────────────────────────────────────────────┐
│ CLINICAL KNOWLEDGE SOURCES                             │
│ • AAO Preferred Practice Patterns                      │
│ • AOA Clinical Practice Guidelines                     │
│ • TFOS DEWS II / NEI AREDS2                            │
│ • Clinic-Specific Practice Protocols                   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ DYNAMIC POSTGRESQL STORE (`rag_documents`)             │
│ • Columns: domain ('optometry'|'medication'|'stats')   │
│ • Key: Unique clinical descriptor                      │
│ • Data: {answer, source, action, contraindications}    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ VECTOR INDEXING & EMBEDDINGS                           │
│ • Model: gemini-embedding-2                            │
│ • Cache: .embedding_cache.json (SHA-256 Fingerprinted) │
│ • Semantic Search: Cosine similarity with 0.55 cutoff  │
└────────────────────────────────────────────────────────┘
```

### How to Expand and Update the Knowledge Base:
1. **Dynamic Ingestion (Zero-Downtime):**
   - Insert new guideline records into the PostgreSQL `rag_documents` table via Supabase dashboard or API.
   - On backend startup or manual refresh, `SemanticKnowledgeBase` queries `rag_documents` and embeds new entries into the vector space.
2. **Deterministic Cache Invalidation:**
   - Embeddings are cached in `.embedding_cache.json` alongside their SHA-256 payload hashes. When guideline text is updated, the hash changes, prompting `gemini-embedding-2` to re-embed only the modified entries while preserving cached vectors.
3. **Clinician Correction Feedback Loop:**
   - Any edits made by clinicians in the Scribe note review screen are recorded in `encounters.scribe_draft` to flag potential gaps in prompt guidelines and feed back into practice-level protocols.
