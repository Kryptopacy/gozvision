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
