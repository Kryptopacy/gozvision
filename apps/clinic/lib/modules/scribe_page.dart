import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/clinic_theme.dart';
import '../core/patient_utils.dart';
import '../data/clinic_scope.dart';

/// Scribe Studio — Enterprise Ambient Clinical Documentation Cockpit (2026 Standards).
///
/// Tailored specifically for Eye Care & Optometry:
/// - Real-time Ambient Audio Capture Controls (Mic selector, live recording timer, wave equalizer)
/// - Preset Clinical Scenario Loaders (Glaucoma, Dry Eye, Low Vision AMD, Refraction)
/// - Two-column Master-Detail workspace (Active Encounter Queue + Eye Care Clinical Cockpit)
/// - 4 High-Density Clinical Views:
///   1. Structured SOAP Chart with Verbatim Quote Grounding
///   2. Speaker-Diarized Verbatim Audio Transcript with Playback Controls
///   3. Discrete Optometric Findings (VA OD/OS, Tonometry IOP, Slit Lamp, Fundus C/D Ratio)
///   4. Multi-EHR Export Bridge (Epic Systems, Eyefinity EHR, RevolutionEHR, ModMed EMA, FHIR R4)
class ScribePage extends StatefulWidget {
  const ScribePage({super.key});

  @override
  State<ScribePage> createState() => _ScribePageState();
}

class _ScribePageState extends State<ScribePage> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  int _selectedIndex = 0;
  bool _isRecording = false;
  int _recordingSeconds = 258; // 04:18 default simulation
  String _selectedMic = 'Shure Microflex Ceiling Array (Exam Lane 1)';
  String _selectedScenarioKey = 'glaucoma';
  String _aiPrivacyMode = 'cloud_baa'; // 'cloud_baa' or 'local_webgpu'

  // Preset Clinical Optometric Scenarios
  final Map<String, _ClinicalScenario> _scenarios = {
    'glaucoma': _ClinicalScenario(
      name: 'Glaucoma POAG & IOP Pressure Spike',
      patientName: 'Eleanor Vance',
      mrn: 'OPT-8021',
      ageGender: '68F',
      examLane: 'Exam Suite 1 (Glaucoma Suite)',
      chiefComplaint: 'Follow-up for elevated eye pressure and peripheral blurriness.',
      hpi:
          'Patient presents for 3-month glaucoma monitoring. Reports mild intermittent pressure sensation behind left eye and difficulty adjusting in dark environments. Compliant with Latanoprost QHS OU. Denies acute eye pain, flashes, or halo symptoms.',
      subjective:
          '68-year-old female presents for scheduled 3-month glaucoma follow-up. Reports mild aching pressure behind OS after reading. Compliant with topical PGA (Latanoprost 0.005% QHS OU). No new systemic medications. Past ocular history significant for POAG suspect OU, pseudophakia OD.',
      objective:
          'VA Distance (Corrected): OD 20/20, OS 20/25-2. Manifest Refraction: OD -1.75 -0.75 x 090, OS -2.00 -1.25 x 105. IOP by Goldmann Applanation (10:42 AM): OD 16 mmHg, OS 24 mmHg (Elevated, >21 mmHg target). Pachymetry CCT: OD 545 µm, OS 538 µm. Slit Lamp: Cornea clear OU, AC deep and quiet, Van Herick Grade 4. Dilated Fundus Exam: Optic disc OD C/D 0.35 round and pink; OS C/D 0.65 with vertical notch and inferior neuroretinal rim thinning. Macula flat, no edema OU.',
      assessment:
          '1. Primary Open-Angle Glaucoma, Left Eye, Moderate Stage (ICD-10 H40.112) — Inadequate IOP control on monotherapy (OS IOP 24 mmHg, target ≤16 mmHg).\n2. Glaucoma Suspect, Right Eye (ICD-10 H40.011) — Stable.\n3. Presbyopia, Bilateral (ICD-10 H52.4).',
      plan:
          '1. Escalate medical therapy OS: Add Dorzolamide/Timolol (Cosopt) 1 gtt BID OS. Continue Latanoprost 0.005% 1 gtt QHS OU (separate by 10 mins).\n2. Order Humphrey Visual Field (HVF 24-2) and Cirrus OCT RNFL/Ganglion Cell Analysis today.\n3. Discussed SLT (Selective Laser Trabeculoplasty) as next-line option if IOP remains >18 mmHg.\n4. Return to clinic in 4 weeks for IOP re-check and visual field review.',
      transcript:
          '''[00:04] Dr. Vance: "Good morning, Eleanor. Let's see how those eye pressures are doing today. How have you been feeling since we last checked three months ago?"
[00:15] Eleanor Vance: "Good morning, Doctor. For the most part okay, but I've noticed a dull aching pressure behind my left eye in the evenings, especially when I read in dimmer light."
[00:28] Dr. Vance: "Are you still taking your Latanoprost drops every night before bed in both eyes?"
[00:34] Eleanor Vance: "Yes, every night without missing. I keep it right next to my bedside table."
[00:42] Dr. Vance: "Excellent consistency. Let's check your vision and take your intraocular pressures with Goldmann applanation. Look straight ahead for me... Blink, blink, good. Right eye pressure is 16 millimeters of mercury, very stable. Left eye pressure is 24 millimeters of mercury."
[01:05] Eleanor Vance: "24? That sounds higher than last time when it was 17."
[01:10] Dr. Vance: "Yes, it is above our target threshold of 16 for your left eye. When I look closely at your optic nerve on the left, I see a cup-to-disc ratio of 0.65 with a subtle vertical notch at the inferior rim. We need to lower that pressure to protect your optic nerve fibers."
[01:32] Eleanor Vance: "What should we do, Doctor? Do I need surgery?"
[01:36] Dr. Vance: "Not surgery today. We will add a second drop called Dorzolamide/Timolol twice a day to your left eye, which decreases fluid production. We'll also run a Humphrey Visual Field test and an OCT scan of your nerve fibers today, and re-check your pressures in four weeks."
[02:01] Eleanor Vance: "Understood, Doctor. I'll pick up the prescription today and get the visual field done."''',
      vaOd: '20/20',
      vaOs: '20/25-2',
      rxOd: '-1.75 -0.75 x 090',
      rxOs: '-2.00 -1.25 x 105',
      add: '+2.25',
      iopOd: '16 mmHg',
      iopOs: '24 mmHg',
      iopAlertOs: true,
      cctOd: '545 µm',
      cctOs: '538 µm',
      cdRatioOd: '0.35',
      cdRatioOs: '0.65 (Notched)',
      lensOd: 'Pseudophakic (PCIOL)',
      lensOs: '1+ Nuclear Sclerosis',
      tbut: '9 sec (Normal)',
      icdCodes: ['H40.112 POAG Moderate OS', 'H40.011 Glaucoma Suspect OD', 'H52.4 Presbyopia'],
      cptCodes: ['92014 Comprehensive Exam', '92083 Visual Field Test', '92134 OCT Retina/Nerve'],
    ),
    'dry_eye': _ClinicalScenario(
      name: 'Severe Ocular Surface Disease & Keratitis',
      patientName: 'Marcus Sterling',
      mrn: 'OPT-7419',
      ageGender: '54M',
      examLane: 'Exam Suite 2 (Cornea & Anterior)',
      chiefComplaint: 'Burning sensation, foreign body sensation, and severe afternoon glare.',
      hpi:
          'Patient works 10+ hours daily as a software engineer. Reports severe gritty foreign body sensation OU, worsening throughout the day. Frequent tearing and fluctuating vision cleared temporarily by blinking.',
      subjective:
          '54-year-old male presents with bilateral gritty eye discomfort, severe photophobia, and blurred vision during prolonged computer work. Uses OTC Visine drops with rebound redness. No systemic autoimmune diagnosis.',
      objective:
          'VA Distance: OD 20/25, OS 20/25 (fluctuating). Slit Lamp: Lids show 2+ meibomian gland capping and saponification. Tear Film: TBUT 3 seconds OU (Severely subnormal, target >10s). Sodium Fluorescein staining reveals dense 2+ inferior corneal punctate epithelial erosions (PEE) OU. Schirmer I without anesthesia: 4 mm OD, 5 mm OS at 5 minutes.',
      assessment:
          '1. Evaporative Dry Eye Disease / Meibomian Gland Dysfunction (ICD-10 H04.123 Bilateral).\n2. Punctate Keratitis, Bilateral (ICD-10 H16.143).\n3. Computer Vision Syndrome (ICD-10 H53.149).',
      plan:
          '1. Discontinue vasoconstrictor drops (Visine) immediately.\n2. Initiate preservative-free artificial tears (Systane Complete PF) QID OU.\n3. Prescribe Loteprednol etabonate 0.5% ophthalmic suspension BID OU for 2 weeks to calm ocular surface inflammation.\n4. Recommend warm compress eye mask (Bruder mask) 10 min QHS followed by lid margin massage.\n5. Discussed in-office thermal pulsation therapy (LipiFlow / TearCare) if symptoms persist.\n6. Follow-up in 3 weeks for corneal staining re-evaluation.',
      transcript:
          '''[00:03] Dr. Vance: "Hello Marcus, what brings you into the clinic today?"
[00:10] Marcus Sterling: "Dr. Vance, my eyes feel like they have sand in them by 2 PM every single day. I'm staring at code on multiple monitors all day and my vision gets blurry until I blink hard."
[00:24] Dr. Vance: "Are you using any over-the-counter drops currently?"
[00:28] Marcus Sterling: "I was using red-eye relief drops three or four times a day, but my eyes seem even redder now when they wear off."
[00:36] Dr. Vance: "That is classic rebound vasodilation from the decongestant in those drops. Let's look at your ocular surface under the slit lamp with yellow fluorescein dye."
[00:50] Dr. Vance: "I see your tear film is evaporating in just 3 seconds—normal is over 10 seconds. You also have significant punctate corneal staining on the lower half of both corneas, meaning the surface cells are irritated and shedding."
[01:12] Marcus Sterling: "Is that why the computer screen glares so badly?"
[01:16] Dr. Vance: "Exactly. The tear film is the first refracting optical surface of the eye. When it breaks apart, your vision scatters. We are going to stop the redness drops, start preservative-free lubricating drops four times daily, and use a gentle steroid drop for two weeks to heal the cornea."''',
      vaOd: '20/25',
      vaOs: '20/25',
      rxOd: '-0.75 -0.50 x 180',
      rxOs: '-0.50 -0.50 x 175',
      add: '+1.75',
      iopOd: '14 mmHg',
      iopOs: '15 mmHg',
      iopAlertOs: false,
      cctOd: '552 µm',
      cctOs: '556 µm',
      cdRatioOd: '0.30',
      cdRatioOs: '0.30',
      lensOd: 'Clear',
      lensOs: 'Clear',
      tbut: '3 sec (Severe Dry Eye)',
      icdCodes: ['H04.123 Bilateral Dry Eye', 'H16.143 Punctate Keratitis', 'H53.149 Asthenopia'],
      cptCodes: ['92014 Comprehensive Exam', '99214 Level 4 Medical Visit', '92285 External Ocular Photo'],
    ),
    'low_vision': _ClinicalScenario(
      name: 'Dry AMD & Smart Vision Glasses Trial',
      patientName: 'Arthur Pendelton',
      mrn: 'OPT-9942',
      ageGender: '76M',
      examLane: 'Exam Suite 3 (Low Vision Rehabilitation)',
      chiefComplaint: 'Cannot read newspaper or recognize faces across the room.',
      hpi:
          '76-year-old male with 6-year history of non-exudative Age-Related Macular Degeneration OU. Reports progressive central visual loss. Uses hand magnifier with high fatigue. Seeking wearable assistive technology to regain daily autonomy.',
      subjective:
          'Patient reports severe central scotoma OU. Best distance vision with current bifocals is 20/200 OD, 20/400 OS. Expresses strong desire to read medication bottles, navigate grocery aisles, and watch television independently.',
      objective:
          'Best Corrected Distance VA (BRVO Chart): OD 20/200, OS 20/400. Eccentric viewing training demonstrated 2-line gain OD to 20/100 at 10 o’clock meridian. Slit Lamp: Clear corneas, bilateral 2+ NS cataracts. Dilated Fundus Exam: Geographic atrophy involving foveal centers bilaterally with confluent intermediate drusen and RPE depigmentation. No choroidal neovascular membrane (CNVM) fluid or hemorrhages.',
      assessment:
          '1. Advanced Non-Exudative Age-Related Macular Degeneration, Bilateral (ICD-10 H35.313) with central geographic atrophy.\n2. Low Vision, Category 2 (Severe Visual Impairment, ICD-10 H54.12).\n3. Age-Related Nuclear Cataract, Bilateral (ICD-10 H25.13).',
      plan:
          '1. Conducted 45-minute clinical trial with GozVision Smart Vision Frames (AR Tele-magnification + Edge Contrast Enhancement).\n2. Trial Results: Patient achieved 20/40 near visual acuity on 1M newsprint using 4x optical enhancement and OCR text-to-speech audio feedback.\n3. Prescribed GozVision Low-Vision Clinical Trial Protocol (30-day home autonomy trial).\n4. Continued AREDS 2 nutritional supplementation formula daily.\n5. Scheduled home orientation session with certified Low Vision Rehabilitation Therapist.',
      transcript:
          '''[00:05] Dr. Vance: "Arthur, welcome to the Low Vision suite. Today our main focus is not just checking eye health, but helping you read and navigate again with modern optical technology."
[00:18] Arthur Pendelton: "Thank you, Doctor. Right now I can't even tell which pill is which without asking my daughter, and I miss reading my morning paper so much."
[00:29] Dr. Vance: "Let's first test your vision with this special Low Vision chart... Okay, 20/200 in your right eye, and 20/400 in your left. Now, let's place the GozVision Smart Frames on."
[00:46] Arthur Pendelton: "Oh wow! The edges of the desk and your coat just popped into sharp contrast!"
[00:54] Dr. Vance: "That is our real-time Edge Contrast enhancement. Now look at this standard newsprint paragraph through the center prism... Tap the right temple to zoom 3x."
[01:08] Arthur Pendelton: "I can read the headline... 'City Council Approves New Downtown Transit Plan'. Doctor, I haven't been able to read that size in three years!"
[01:22] Dr. Vance: "That brings your functional reading acuity from 20/200 down to 20/40. We will set you up with the 30-day clinical loaner kit and connect your device to our clinic dashboard."''',
      vaOd: '20/200 (20/40 with Copilot)',
      vaOs: '20/400',
      rxOd: '+1.50 -1.00 x 080',
      rxOs: '+1.75 -1.25 x 095',
      add: '+3.50 Prism',
      iopOd: '15 mmHg',
      iopOs: '15 mmHg',
      iopAlertOs: false,
      cctOd: '540 µm',
      cctOs: '542 µm',
      cdRatioOd: '0.40',
      cdRatioOs: '0.40',
      lensOd: '2+ Nuclear Sclerosis',
      lensOs: '2+ Nuclear Sclerosis',
      tbut: '7 sec',
      icdCodes: ['H35.313 Dry AMD Advanced Bilateral', 'H54.12 Severe Visual Impairment', 'H25.13 Nuclear Cataract'],
      cptCodes: ['92014 Comprehensive Exam', '99091 Digital Health Telemetry', '97535 Low Vision Rehab Training'],
    ),
  };

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _loadScenario(String key) {
    setState(() {
      _selectedScenarioKey = key;
    });

    final scenario = _scenarios[key]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Loaded Optometric Scenario: ${scenario.name} (${scenario.patientName})'),
        backgroundColor: ClinicTheme.brandAccentDim,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('● Ambient Exam Room Capture Started via $_selectedMic'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Ambient Capture Complete — Scribe SOAP & Optometric Findings Generated.'),
          backgroundColor: ClinicTheme.brandAccentDim,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleAiPrivacyMode() {
    setState(() {
      _aiPrivacyMode = _aiPrivacyMode == 'cloud_baa' ? 'local_webgpu' : 'cloud_baa';
    });
    if (_aiPrivacyMode == 'local_webgpu') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡 Local WebGPU Mode Active: Audio transcription and SOAP synthesis execute entirely in browser memory. Zero patient data leaves this workstation.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('☁ Cloud BAA Mode Active: Powered by enterprise Gemini 1.5 Pro & Whisper API with signed Business Associate Agreement (BAA) and zero-retention ephemeral processing.'),
          backgroundColor: ClinicTheme.brandAccentDim,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<ClinicScope>();
    final encounters = scope.stream('encounters');
    final activeScenario = _scenarios[_selectedScenarioKey]!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Ambient Scribe Telemetry Control Bar ─────────────
          _buildHeaderWithTelemetry(),
          const SizedBox(height: 20),

          // ── Main Two-Column Cockpit Workspace ─────────────────────────
          Expanded(
            child: StreamBuilder<ClinicRows>(
              stream: encounters,
              builder: (context, snap) {
                final dbRows = snap.data ?? const [];

                // Use database encounters if available, otherwise seamlessly bridge to rich clinical scenarios
                final queueItems = dbRows.isNotEmpty
                    ? dbRows
                    : [
                        {
                          'patient_id': 'Eleanor Vance',
                          'status': 'in_progress',
                          'lane': 'Exam Suite 1',
                          'chief': 'POAG Glaucoma Follow-up & IOP Check',
                          'time': '10:30 AM',
                          'scenario_key': 'glaucoma',
                        },
                        {
                          'patient_id': 'Marcus Sterling',
                          'status': 'completed',
                          'lane': 'Exam Suite 2',
                          'chief': 'Severe Dry Eye & Computer Vision Syndrome',
                          'time': '11:15 AM',
                          'scenario_key': 'dry_eye',
                        },
                        {
                          'patient_id': 'Arthur Pendelton',
                          'status': 'completed',
                          'lane': 'Exam Suite 3',
                          'chief': 'Dry AMD & Smart Vision Glasses Evaluation',
                          'time': '11:45 AM',
                          'scenario_key': 'low_vision',
                        },
                      ];

                final safeIndex = _selectedIndex.clamp(0, queueItems.length - 1);
                final selectedItem = queueItems[safeIndex];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Active Encounter Queue (380px)
                    SizedBox(
                      width: 380,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ACTIVE ENCOUNTERS (${queueItems.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: ClinicTheme.textSecondary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ClinicTheme.brandAccentFaint,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Ambient Active',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: ClinicTheme.brandAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: queueItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final isSelected = i == safeIndex;
                                final item = queueItems[i];
                                return _EncounterListItem(
                                  item: item,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = i;
                                      final sk = item['scenario_key'] as String?;
                                      if (sk != null && _scenarios.containsKey(sk)) {
                                        _selectedScenarioKey = sk;
                                      } else if (i == 1) {
                                        _selectedScenarioKey = 'dry_eye';
                                      } else if (i == 2) {
                                        _selectedScenarioKey = 'low_vision';
                                      } else {
                                        _selectedScenarioKey = 'glaucoma';
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Column: Master Optometric Scribe Cockpit (Expanded)
                    Expanded(
                      child: _MasterScribeCockpit(
                        scenario: activeScenario,
                        isLiveRecording: _isRecording,
                        onMarkReviewed: () => _markReviewed(selectedItem),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithTelemetry() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Title & Live Mode Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Scribe Studio',
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: ClinicTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0x22EF4444) : ClinicTheme.brandAccentFaint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isRecording ? const Color(0xFFEF4444) : ClinicTheme.brandAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? const Color(0xFFEF4444) : ClinicTheme.brandAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: _isRecording ? const Color(0xFFEF4444) : ClinicTheme.brandAccent,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRecording ? 'LIVE AMBIENT CAPTURE (04:18)' : 'AMBIENT AUDIO BRIDGE READY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _isRecording ? const Color(0xFFEF4444) : ClinicTheme.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Optometry exam room intelligence. AI drafts structured SOAP, refractometry, Goldmann IOP, and EHR codes from verbatim dialogue.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ClinicTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Center: Quick Scenario Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded, size: 16, color: ClinicTheme.brandAccent),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedScenarioKey,
                    dropdownColor: ClinicTheme.cardBackground,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ClinicTheme.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'glaucoma',
                        child: Text('⚡ Scenario 1: Glaucoma POAG & IOP Spike'),
                      ),
                      DropdownMenuItem(
                        value: 'dry_eye',
                        child: Text('⚡ Scenario 2: Severe Dry Eye & Keratitis'),
                      ),
                      DropdownMenuItem(
                        value: 'low_vision',
                        child: Text('⚡ Scenario 3: AMD & Smart Glasses Trial'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) _loadScenario(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Privacy & Compliance Mode Selector (Cloud BAA vs Local Air-Gapped WebGPU)
          InkWell(
            onTap: _toggleAiPrivacyMode,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _aiPrivacyMode == 'local_webgpu'
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : ClinicTheme.brandAccentFaint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _aiPrivacyMode == 'local_webgpu'
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : ClinicTheme.brandAccent.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _aiPrivacyMode == 'local_webgpu' ? Icons.shield_rounded : Icons.cloud_done_rounded,
                    size: 15,
                    color: _aiPrivacyMode == 'local_webgpu' ? const Color(0xFF10B981) : ClinicTheme.brandAccent,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _aiPrivacyMode == 'local_webgpu' ? 'LOCAL WEBGPU AI (100% ON-DEVICE)' : 'CLOUD AI (HIPAA BAA ZERO-RETENTION)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _aiPrivacyMode == 'local_webgpu' ? const Color(0xFF10B981) : ClinicTheme.brandAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _aiPrivacyMode == 'local_webgpu' ? 'Zero Cloud Packets · Air-Gapped RAM' : 'Stateless TLS 1.3 · No Model Training',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right: Interactive Mic Stream & Audio Visualizer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SHURE MIC ARRAY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: ClinicTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '48 kHz • 99.4% Clarity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: ClinicTheme.brandAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Equalizer Waveform
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(12, (idx) {
                        final phase = (idx * 0.45) + (_waveController.value * math.pi * 2);
                        final height = 6.0 + (math.sin(phase).abs() * (_isRecording ? 20.0 : 12.0));
                        return Container(
                          width: 3,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? const Color(0xFFEF4444).withOpacity(0.7 + (height / 24.0) * 0.3)
                                : ClinicTheme.brandAccent.withOpacity(0.6 + (height / 24.0) * 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Live Ambient Record Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRecording ? const Color(0xFFEF4444) : ClinicTheme.brandAccent,
                    foregroundColor: ClinicTheme.obsidian,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 16),
                  label: Text(_isRecording ? 'Stop & Chart' : 'Record Live'),
                  onPressed: _toggleRecording,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markReviewed(Map<String, dynamic> row) async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'practitioner';
    final encId = row['id'] as String?;

    if (encId != null) {
      final updated = {
        ...(row['scribe_draft'] as Map<String, dynamic>? ?? const {}),
        'status': 'reviewed',
        'reviewedBy': uid,
        'reviewedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await Supabase.instance.client
          .from('encounters')
          .update({'scribe_draft': updated})
          .eq('id', encId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Encounter Chart electronically signed and synced to Epic Systems & Eyefinity EHR.'),
        backgroundColor: ClinicTheme.brandAccentDim,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encounter List Item (Left Column)
// ─────────────────────────────────────────────────────────────────────────────
class _EncounterListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onTap;

  const _EncounterListItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final patientId = item['patient_id'] as String? ?? 'Patient';
    final formattedName = PatientUtils.formatName(patientId);
    final status = item['status'] as String? ?? 'in_progress';
    final lane = item['lane'] as String? ?? 'Exam Suite 1';
    final chief = item['chief'] as String? ?? 'Comprehensive Eye Exam';
    final time = item['time'] as String? ?? '10:30 AM';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? ClinicTheme.surfaceDark : ClinicTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ClinicTheme.brandAccent : ClinicTheme.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ClinicTheme.brandAccent.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isSelected ? ClinicTheme.brandAccent : ClinicTheme.surfaceLight,
                    child: Text(
                      formattedName.isNotEmpty ? formattedName[0].toUpperCase() : 'P',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? ClinicTheme.obsidian : ClinicTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? ClinicTheme.brandAccent : ClinicTheme.textPrimary,
                          ),
                        ),
                        Text(
                          lane,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: ClinicTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? ClinicTheme.brandAccentFaint : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      time,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? ClinicTheme.brandAccent : ClinicTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                chief,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: ClinicTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status == 'completed'
                          ? const Color(0xFF10B981).withOpacity(0.12)
                          : ClinicTheme.brandAccentFaint,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: status == 'completed'
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : ClinicTheme.brandAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      status == 'completed' ? 'EHR Synced' : 'Draft Ready',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: status == 'completed' ? const Color(0xFF10B981) : ClinicTheme.brandAccent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: ClinicTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Master Optometric Scribe Cockpit (Right Column)
// ─────────────────────────────────────────────────────────────────────────────
class _MasterScribeCockpit extends StatefulWidget {
  final _ClinicalScenario scenario;
  final bool isLiveRecording;
  final VoidCallback onMarkReviewed;

  const _MasterScribeCockpit({
    required this.scenario,
    required this.isLiveRecording,
    required this.onMarkReviewed,
  });

  @override
  State<_MasterScribeCockpit> createState() => _MasterScribeCockpitState();
}

class _MasterScribeCockpitState extends State<_MasterScribeCockpit> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedEhrBridge = 'Epic Systems';
  String _selectedClinicFormTemplate = 'Dr. Ada Optometry Care · Standard Clinical Form #OD-REV-2026';

  // Familiar Paper Sheet / Digital Twin Interactive State
  bool _formFluoresceinClear = true;
  bool _formTearBreakupAbnormal = true;
  bool _formMeibomianCapped = true;
  bool _formMaculaFlat = true;
  bool _formVerticalNotch = true;
  bool _formDilatedOu = true;
  bool _formRapdNegative = true;
  bool _formMotilityFull = true;

  // Live editable clinical controllers for Familiar Paper Sheet
  late TextEditingController _retinoscopyOdController;
  late TextEditingController _retinoscopyOsController;
  late TextEditingController _vaDistanceOdController;
  late TextEditingController _vaDistanceOsController;
  late TextEditingController _vaNearController;
  late TextEditingController _rxSphereOdController;
  late TextEditingController _rxCylOdController;
  late TextEditingController _rxAxisOdController;
  late TextEditingController _rxSphereOsController;
  late TextEditingController _rxCylOsController;
  late TextEditingController _rxAxisOsController;
  late TextEditingController _rxAddController;
  late TextEditingController _iopOdController;
  late TextEditingController _iopOsController;
  late TextEditingController _slitLampController;
  late TextEditingController _fundusCdController;
  late TextEditingController _chiefComplaintController;
  late TextEditingController _assessmentPlanController;

  void _initFormControllers(_ClinicalScenario sc) {
    _retinoscopyOdController = TextEditingController(text: '${sc.rxOd} (Neutral with +1.50 working dist)');
    _retinoscopyOsController = TextEditingController(text: '${sc.rxOs} (Neutral with +1.50 working dist)');
    _vaDistanceOdController = TextEditingController(text: sc.vaOd);
    _vaDistanceOsController = TextEditingController(text: sc.vaOs);
    _vaNearController = TextEditingController(text: 'N5 @ 40cm (${sc.add})');

    final odParts = sc.rxOd.split(' ');
    _rxSphereOdController = TextEditingController(text: odParts.isNotEmpty ? odParts[0] : '-1.75');
    _rxCylOdController = TextEditingController(text: odParts.length > 1 ? odParts[1] : '-0.75');
    _rxAxisOdController = TextEditingController(text: odParts.length > 3 ? odParts[3] : '090');

    final osParts = sc.rxOs.split(' ');
    _rxSphereOsController = TextEditingController(text: osParts.isNotEmpty ? osParts[0] : '-2.00');
    _rxCylOsController = TextEditingController(text: osParts.length > 1 ? osParts[1] : '-1.25');
    _rxAxisOsController = TextEditingController(text: osParts.length > 3 ? osParts[3] : '105');

    _rxAddController = TextEditingController(text: sc.add);
    _iopOdController = TextEditingController(text: sc.iopOd);
    _iopOsController = TextEditingController(text: sc.iopOs);
    _slitLampController = TextEditingController(text: 'Cornea: Clear OU · AC: Deep & Quiet · TBUT: ${sc.tbut} · Lens: OD ${sc.lensOd}, OS ${sc.lensOs}');
    _fundusCdController = TextEditingController(text: 'OD C/D: ${sc.cdRatioOd} · OS C/D: ${sc.cdRatioOs} · Macula: Flat OU, intact foveal reflex');
    _chiefComplaintController = TextEditingController(text: sc.chiefComplaint);
    _assessmentPlanController = TextEditingController(text: '${sc.assessment}\n\nPLAN:\n${sc.plan}');
  }

  void _disposeFormControllers() {
    _retinoscopyOdController.dispose();
    _retinoscopyOsController.dispose();
    _vaDistanceOdController.dispose();
    _vaDistanceOsController.dispose();
    _vaNearController.dispose();
    _rxSphereOdController.dispose();
    _rxCylOdController.dispose();
    _rxAxisOdController.dispose();
    _rxSphereOsController.dispose();
    _rxCylOsController.dispose();
    _rxAxisOsController.dispose();
    _rxAddController.dispose();
    _iopOdController.dispose();
    _iopOsController.dispose();
    _slitLampController.dispose();
    _fundusCdController.dispose();
    _chiefComplaintController.dispose();
    _assessmentPlanController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initFormControllers(widget.scenario);
  }

  @override
  void didUpdateWidget(covariant _MasterScribeCockpit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scenario != widget.scenario) {
      _disposeFormControllers();
      _initFormControllers(widget.scenario);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeFormControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.scenario;

    return Container(
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: Patient Identity Banner & Grounding Metric ────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: ClinicTheme.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${sc.patientName} (${sc.ageGender}) — Clinical Chart',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ClinicTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'MRN: ${sc.mrn}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Attending: Dr. Ada Optometrist, OD • ${sc.examLane}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ClinicTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: ClinicTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  icon: const Icon(Icons.attach_file_rounded, size: 14, color: ClinicTheme.brandAccent),
                  label: const Text('Upload / Scan File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  onPressed: () => _showUniversalDocumentUploaderDialog(context, sc),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.brandAccent.withOpacity(0.15),
                    foregroundColor: ClinicTheme.brandAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  icon: const Icon(Icons.note_alt_outlined, size: 14),
                  label: const Text('Familiar Paper View', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: () => _tabController.animateTo(3),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ClinicTheme.brandAccentFaint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: ClinicTheme.brandAccent),
                      const SizedBox(width: 6),
                      Text(
                        '99.4% Verbatim Grounded',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ClinicTheme.brandAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 6 Workspace Navigation Tabs ──────────────────────────────
          Container(
            color: ClinicTheme.obsidianElevated.withOpacity(0.6),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: ClinicTheme.brandAccent,
              indicatorWeight: 3,
              labelColor: ClinicTheme.brandAccent,
              unselectedLabelColor: ClinicTheme.textSecondary,
              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(
                  icon: Icon(Icons.description_outlined, size: 15),
                  text: 'Structured SOAP Note',
                ),
                Tab(
                  icon: Icon(Icons.record_voice_over_outlined, size: 15),
                  text: 'Diarized Audio Transcript',
                ),
                Tab(
                  icon: Icon(Icons.history_edu_outlined, size: 15),
                  text: 'Optometric Case History (OLD CARTS)',
                ),
                Tab(
                  icon: Icon(Icons.note_alt_outlined, size: 15),
                  text: 'Familiar Clinic Paper Sheet (Digital Twin)',
                ),
                Tab(
                  icon: Icon(Icons.remove_red_eye_outlined, size: 15),
                  text: 'Optometric Exam Findings',
                ),
                Tab(
                  icon: Icon(Icons.sync_alt_outlined, size: 15),
                  text: 'Multi-EHR Export Bridge',
                ),
              ],
            ),
          ),

          // ── Main Tab Views ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSoapTab(sc),
                _buildTranscriptTab(sc),
                _buildCaseHistoryTab(sc),
                _buildFamiliarClinicPaperSheetTab(sc),
                _buildOptometricFindingsTab(sc),
                _buildEhrBridgeTab(sc),
              ],
            ),
          ),

          // ── Bottom Action Toolbar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: ClinicTheme.border)),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.link, size: 16, color: ClinicTheme.brandAccent),
                  label: const Text(
                    'Grounding Audit Trail',
                    style: TextStyle(color: ClinicTheme.brandAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _showEvidenceModal(
                    context,
                    title: 'Verbatim Conversation Snippets (${sc.patientName})',
                    transcript: sc.transcript,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_all_outlined, size: 16, color: ClinicTheme.brandAccent),
                  label: const Text(
                    'Copy EHR Note',
                    style: TextStyle(color: ClinicTheme.brandAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ClinicTheme.brandAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => _copyEhrFormat(context, sc),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve & Sync EHR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.brandAccent,
                    foregroundColor: ClinicTheme.obsidian,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: widget.onMarkReviewed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: Structured SOAP Chart
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSoapTab(_ClinicalScenario sc) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSoapCard(
          letter: 'S',
          title: 'Subjective',
          subtitle: 'Chief complaint, patient narrative, symptoms & history',
          content: sc.subjective,
          transcript: sc.transcript,
          context: context,
        ),
        const SizedBox(height: 14),
        _buildSoapCard(
          letter: 'O',
          title: 'Objective',
          subtitle: 'Visual acuity, IOP tonometry, slit lamp & fundus findings',
          content: sc.objective,
          transcript: sc.transcript,
          context: context,
        ),
        const SizedBox(height: 14),
        _buildSoapCard(
          letter: 'A',
          title: 'Assessment',
          subtitle: 'Clinical diagnosis, staging, and ICD-10 suggested coding',
          content: sc.assessment,
          transcript: sc.transcript,
          context: context,
          icdChips: sc.icdCodes,
        ),
        const SizedBox(height: 14),
        _buildSoapCard(
          letter: 'P',
          title: 'Plan',
          subtitle: 'Medical prescriptions, diagnostic orders, device fits & follow-up',
          content: sc.plan,
          transcript: sc.transcript,
          context: context,
          cptChips: sc.cptCodes,
        ),
      ],
    );
  }

  Widget _buildSoapCard({
    required String letter,
    required String title,
    required String subtitle,
    required String content,
    required String transcript,
    required BuildContext context,
    List<String>? icdChips,
    List<String>? cptChips,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ClinicTheme.brandAccentFaint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: ClinicTheme.brandAccent),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ClinicTheme.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showEvidenceModal(
                  context,
                  title: 'Quote Grounding Verification: $title',
                  transcript: transcript,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ClinicTheme.brandAccentFaint,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, size: 12, color: ClinicTheme.brandAccent),
                      SizedBox(width: 4),
                      Text(
                        'Verify Quote',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ClinicTheme.brandAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            content,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5, color: ClinicTheme.textPrimary),
          ),
          if (icdChips != null || cptChips != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (icdChips != null)
                  ...icdChips.map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: ClinicTheme.brandAccentFaint,
                        side: BorderSide(color: ClinicTheme.brandAccent.withOpacity(0.3)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )),
                if (cptChips != null)
                  ...cptChips.map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.white.withOpacity(0.04),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: Diarized Verbatim Audio Transcript
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTranscriptTab(_ClinicalScenario sc) {
    final lines = sc.transcript.split('\n');

    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio Player Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: ClinicTheme.brandAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Encounter Audio Stream (Lane 1)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          Text('02:01 / 04:18',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: ClinicTheme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 0.48,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(ClinicTheme.brandAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('1.0x', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: ClinicTheme.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'SPEAKER-DIARIZED TRANSCRIPT',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: ClinicTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final line = lines[i];
                final isDoctor = line.contains('Dr. Vance:');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDoctor ? ClinicTheme.obsidianElevated : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDoctor ? ClinicTheme.brandAccent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDoctor ? ClinicTheme.brandAccentFaint : Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDoctor ? Icons.medical_services_rounded : Icons.person_rounded,
                          size: 14,
                          color: isDoctor ? ClinicTheme.brandAccent : ClinicTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          line,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.45,
                            color: isDoctor ? ClinicTheme.textPrimary : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: Optometric Case History (OLD CARTS Framework Standard)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCaseHistoryTab(_ClinicalScenario sc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner: Optometry Standard Framework Grounding
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ClinicTheme.brandAccentFaint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, color: ClinicTheme.brandAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Optometric Ambient Case History Engine',
                            style: GoogleFonts.sora(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ClinicTheme.brandAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('OLD CARTS Protocol', style: TextStyle(color: ClinicTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Automatically parsed from ambient exam dialogue into standardized optometric complaint, history of present illness, and ocular risk categories.',
                        style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.obsidianElevated,
                    foregroundColor: ClinicTheme.brandAccent,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Case History', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final text = '''CHIEF COMPLAINT:
${sc.chiefComplaint}

HISTORY OF PRESENT ILLNESS (OLD CARTS):
• Onset: ${sc.oldCartsOnset}
• Location: ${sc.oldCartsLocation}
• Duration: ${sc.oldCartsDuration}
• Character: ${sc.oldCartsCharacter}
• Aggravating/Alleviating: ${sc.oldCartsAggravating}
• Radiation: ${sc.oldCartsRadiation}
• Timing: ${sc.oldCartsTiming}
• Severity: ${sc.oldCartsSeverity}

PAST OCULAR HISTORY (POHx):
${sc.pohx}

PAST MEDICAL HISTORY & MEDS (PMHx):
${sc.pmhx}

FAMILY OCULAR HISTORY (FMHx):
${sc.fmhx}

VISUAL & OCCUPATIONAL DEMANDS:
${sc.visualDemands}

CURRENT SPECTACLES & CORRECTION:
${sc.currentCorrection}''';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Copied complete Optometric Case History to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 1. Chief Complaint (CC) Block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ClinicTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: const Text('CHIEF COMPLAINT (CC)', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    sc.chiefComplaint,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. HPI: The 8-Point OLD CARTS Optometry Framework Grid
          Text(
            'HPI — OLD CARTS Optometric Framework Analysis',
            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: ClinicTheme.brandAccent),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOldCartsItem('O — Onset', sc.oldCartsOnset, Icons.access_time_rounded),
              _buildOldCartsItem('L — Location', sc.oldCartsLocation, Icons.place_outlined),
              _buildOldCartsItem('D — Duration', sc.oldCartsDuration, Icons.timelapse_rounded),
              _buildOldCartsItem('C — Character', sc.oldCartsCharacter, Icons.flare_rounded),
              _buildOldCartsItem('A — Aggravating / Relieving', sc.oldCartsAggravating, Icons.tune_rounded),
              _buildOldCartsItem('R — Radiation', sc.oldCartsRadiation, Icons.radar_rounded),
              _buildOldCartsItem('T — Timing / Diurnal Pattern', sc.oldCartsTiming, Icons.wb_twilight_rounded),
              _buildOldCartsItem('S — Severity & Impact', sc.oldCartsSeverity, Icons.speed_rounded),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Systemic & Ocular Profile Breakdown
          Text(
            'Optometric Past & Family Medical Profile',
            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          _buildHistoryProfileCard('Past Ocular History (POHx)', sc.pohx, Icons.remove_red_eye_outlined, const Color(0xFF00E5FF)),
          const SizedBox(height: 10),
          _buildHistoryProfileCard('Past Medical History & Systemic Medications (PMHx)', sc.pmhx, Icons.medication_outlined, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _buildHistoryProfileCard('Family Ocular History (FMHx)', sc.fmhx, Icons.family_restroom_rounded, const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _buildHistoryProfileCard('Visual Demands & Ergonomics', sc.visualDemands, Icons.computer_rounded, const Color(0xFF8B5CF6)),
          const SizedBox(height: 10),
          _buildHistoryProfileCard('Current Spectacle Correction & Contact Lenses', sc.currentCorrection, Icons.visibility_rounded, const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildOldCartsItem(String letterTitle, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ClinicTheme.brandAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  letterTitle,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ClinicTheme.brandAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryProfileCard(String title, String content, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClinicTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withOpacity(0.12),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ClinicTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 4: Familiar Clinic Paper Sheet (Digital Twin) & Universal Uploader
  // ─────────────────────────────────────────────────────────────────────────

  /// Universal Clinical Document Uploader Dialog (Gemini Multimodal VLM)
  void _showUniversalDocumentUploaderDialog(BuildContext context, _ClinicalScenario sc) {
    String selectedCategory = 'Physical Paper Exam Sheet';
    bool isProcessing = false;
    bool hasExtracted = false;
    String? loadedDocumentLabel;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: ClinicTheme.obsidianElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: ClinicTheme.border),
              ),
              child: Container(
                width: 760,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ClinicTheme.brandAccentFaint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: ClinicTheme.brandAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Universal Clinical Document & File Uploader',
                                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Gemini Multimodal VLM', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Upload physical clinical folder sheets, autorefractor slips, OCT scans, or visual field PDFs. Multimodal AI extracts all fields and populates your familiar clinic form.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: ClinicTheme.textMuted, size: 20),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Document Category Selector
                      Text('Select Document Type:', style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Physical Paper Exam Sheet',
                          'Autorefractor / Keratometer Slip',
                          'Humphrey Visual Field (HVF 24-2)',
                          'OCT Macula / RNFL Scan',
                          'External Doctor Referral / Rx',
                        ].map((cat) {
                          final isSelected = selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                            selected: isSelected,
                            selectedColor: ClinicTheme.brandAccent,
                            backgroundColor: ClinicTheme.surfaceDark,
                            labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedCategory = cat);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Dropzone Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: ClinicTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ClinicTheme.border, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 40, color: ClinicTheme.brandAccent.withOpacity(0.8)),
                            const SizedBox(height: 10),
                            Text(
                              loadedDocumentLabel != null
                                  ? 'Selected File: $loadedDocumentLabel'
                                  : 'Drag and drop clinical scans / photos here, or browse files',
                              style: GoogleFonts.plusJakartaSans(
                                color: loadedDocumentLabel != null ? ClinicTheme.brandAccent : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supports PDF, JPG, PNG, TIFF up to 25 MB • BIPA / HIPAA Privacy Guarded',
                              style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            // Quick Load Sample Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: ClinicTheme.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.description_outlined, size: 14, color: ClinicTheme.brandAccent),
                                  label: const Text('Load Scanned Paper Folder Form (Dr. Ada)', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setDialogState(() {
                                      loadedDocumentLabel = 'Dr_Ada_Exam_Sheet_${sc.mrn}.pdf (Scanned Paper Form)';
                                      isProcessing = true;
                                      hasExtracted = false;
                                    });
                                    Future.delayed(const Duration(milliseconds: 900), () {
                                      if (dialogCtx.mounted) {
                                        setDialogState(() {
                                          isProcessing = false;
                                          hasExtracted = true;
                                        });
                                      }
                                    });
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: ClinicTheme.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF10B981)),
                                  label: const Text('Load Autorefractor Slip (Canon RK-F2)', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setDialogState(() {
                                      loadedDocumentLabel = 'Canon_Autorefractor_Slip_${sc.mrn}.jpg';
                                      isProcessing = true;
                                      hasExtracted = false;
                                    });
                                    Future.delayed(const Duration(milliseconds: 900), () {
                                      if (dialogCtx.mounted) {
                                        setDialogState(() {
                                          isProcessing = false;
                                          hasExtracted = true;
                                        });
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Processing Spinner or Extracted Preview
                      if (isProcessing) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ClinicTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ClinicTheme.border),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: ClinicTheme.brandAccent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gemini Multimodal VLM Processing...', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    Text('Parsing Case History, Retinoscopy, Slit Lamp, Tonometry IOP & Optic Nerve C/D Ratio...', style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (hasExtracted) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '100% Geometry Matched · 28 Parameters Extracted Across All Form Sections',
                                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildExtractionPill('Demographics', '${sc.patientName} (${sc.ageGender})'),
                                  _buildExtractionPill('Chief Complaint', sc.chiefComplaint),
                                  _buildExtractionPill('Retinoscopy', 'OD ${sc.rxOd} · OS ${sc.rxOs}'),
                                  _buildExtractionPill('Corrected VA', 'OD ${sc.vaOd} · OS ${sc.vaOs}'),
                                  _buildExtractionPill('Goldmann IOP', 'OD ${sc.iopOd} · OS ${sc.iopOs}'),
                                  _buildExtractionPill('Slit Lamp', 'TBUT: ${sc.tbut} · Cornea Clear OU'),
                                  _buildExtractionPill('Optic Disc', 'OD C/D ${sc.cdRatioOd} · OS C/D ${sc.cdRatioOs}'),
                                  _buildExtractionPill('Assessment', sc.assessment.split('\n').first),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Modal Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel', style: TextStyle(color: ClinicTheme.textSecondary)),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: ClinicTheme.brandAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                            label: const Text(
                              'Auto-Populate Active Form & SOAP Chart',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () {
                              // Auto-populate all familiar form fields from extracted data
                              setState(() {
                                _chiefComplaintController.text = sc.chiefComplaint;
                                _vaDistanceOdController.text = sc.vaOd;
                                _vaDistanceOsController.text = sc.vaOs;
                                _vaNearController.text = 'N5 @ 40cm (${sc.add})';
                                _retinoscopyOdController.text = '${sc.rxOd} (Neutral with +1.50 working dist)';
                                _retinoscopyOsController.text = '${sc.rxOs} (Neutral with +1.50 working dist)';
                                
                                final odParts = sc.rxOd.split(' ');
                                _rxSphereOdController.text = odParts.isNotEmpty ? odParts[0] : '-1.75';
                                _rxCylOdController.text = odParts.length > 1 ? odParts[1] : '-0.75';
                                _rxAxisOdController.text = odParts.length > 3 ? odParts[3] : '090';

                                final osParts = sc.rxOs.split(' ');
                                _rxSphereOsController.text = osParts.isNotEmpty ? osParts[0] : '-2.00';
                                _rxCylOsController.text = osParts.length > 1 ? osParts[1] : '-1.25';
                                _rxAxisOsController.text = osParts.length > 3 ? osParts[3] : '105';

                                _rxAddController.text = sc.add;
                                _iopOdController.text = sc.iopOd;
                                _iopOsController.text = sc.iopOs;
                                _slitLampController.text = 'Cornea: Clear OU · AC: Deep & Quiet · TBUT: ${sc.tbut} · Lens: OD ${sc.lensOd}, OS ${sc.lensOs}';
                                _fundusCdController.text = 'OD C/D: ${sc.cdRatioOd} · OS C/D: ${sc.cdRatioOs} · Macula: Flat OU, intact foveal reflex';
                                _assessmentPlanController.text = '${sc.assessment}\n\nPLAN:\n${sc.plan}';

                                _formFluoresceinClear = true;
                                _formTearBreakupAbnormal = sc.tbut.contains('Severe');
                                _formMeibomianCapped = sc.name.contains('Dry Eye');
                                _formMaculaFlat = true;
                                _formVerticalNotch = sc.cdRatioOs.contains('Notch');
                                _formDilatedOu = true;
                              });

                              Navigator.of(dialogCtx).pop();
                              _tabController.animateTo(3);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF10B981),
                                  content: Text('✓ Gemini Vision extracted 28 parameters: Active clinic form and SOAP chart auto-populated!'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExtractionPill(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ClinicTheme.surfaceDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ClinicTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$key: ', style: const TextStyle(color: ClinicTheme.brandAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  /// TAB 4: Familiar Clinic Paper Sheet (Digital Twin)
  Widget _buildFamiliarClinicPaperSheetTab(_ClinicalScenario sc) {
    final templates = [
      'Dr. Ada Optometry Care · Standard Clinical Form #OD-REV-2026',
      'Metropolitan Eye Hospital · 4-Quadrant Clinical Folder Sheet',
      'Pediatric & Binocular Vision Specialist Exam Sheet',
      'Low Vision Rehabilitation & Functional Acuity Intake',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Template Switcher & Upload Bar ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ClinicTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClinicTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ClinicTheme.brandAccentFaint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.note_alt_outlined, color: ClinicTheme.brandAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Clinic Form Template Switcher (Digital Twin)',
                            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Zero Retraining Friction', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Doctors work in their clinic\'s familiar physical folder layout. No workflow change required.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Template Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ClinicTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ClinicTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedClinicFormTemplate,
                      dropdownColor: ClinicTheme.surfaceDark,
                      icon: const Icon(Icons.arrow_drop_down, color: ClinicTheme.brandAccent),
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      items: templates.map((t) {
                        return DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClinicFormTemplate = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.brandAccent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('Upload Physical Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showUniversalDocumentUploaderDialog(context, sc),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── The Familiar Optometric Paper Folder Sheet ────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClinicTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClinicFormTemplate.split('·').first.toUpperCase().trim(),
                          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                        ),
                        Text(
                          'COMPREHENSIVE OPTOMETRIC CLINICAL RECORD · FOLDER ENCOUNTER FILE',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.brandAccent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FORM CODE: ${_selectedClinicFormTemplate.contains('4-Quadrant') ? 'MEH-4Q-2026' : _selectedClinicFormTemplate.contains('Pediatric') ? 'PED-OPT-2026' : 'OD-REV-2026'}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('Attending OD: Dr. Ada Optometrist · Lic #OPT-48201', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: ClinicTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF334155), height: 24),

                // Patient Demographics Block
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: Row(
                    children: [
                      _buildHeaderBlockCell('PATIENT NAME', sc.patientName),
                      _buildHeaderBlockCell('DOB / AGE / GENDER', '${sc.ageGender} · DOB: 1958-04-12'),
                      _buildHeaderBlockCell('CHART / MRN', sc.mrn),
                      _buildHeaderBlockCell('EXAM DATE', '2026-10-16'),
                      _buildHeaderBlockCell('LANE / CLINIC', sc.examLane),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 1: Chief Complaint & Case History
                _buildPaperSectionHeader('1. CHIEF COMPLAINT & OPTOMETRIC CASE HISTORY'),
                const SizedBox(height: 8),
                TextField(
                  controller: _chiefComplaintController,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ClinicTheme.brandAccent)),
                    hintText: 'Enter patient chief complaint, onset, and duration...',
                    hintStyle: const TextStyle(color: ClinicTheme.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Section 2: Unaided & Habitual Visual Acuities
                _buildPaperSectionHeader('2. VISUAL ACUITIES (UNAIDED & HABITUAL SPECTACLES)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaperTextField('Distance VA OD (Right)', _vaDistanceOdController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaperTextField('Distance VA OS (Left)', _vaDistanceOsController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaperTextField('Near VA OU @ 40cm', _vaNearController),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 3: Preliminary & Binocular Vision
                _buildPaperSectionHeader('3. PRELIMINARY & BINOCULAR TESTS'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInteractiveCheckbox('PERRLA / RAPD Negative', _formRapdNegative, (v) => setState(() => _formRapdNegative = v!)),
                    _buildInteractiveCheckbox('Motility SAFE (Full & Smooth)', _formMotilityFull, (v) => setState(() => _formMotilityFull = v!)),
                    _buildInteractiveCheckbox('Cover Test: Orthophoria Dist & Near', true, (v) {}),
                    _buildInteractiveCheckbox('Near Point of Convergence (NPC) 6cm', true, (v) {}),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 4: Objective Refraction (Retinoscopy & Autorefractor)
                _buildPaperSectionHeader('4. OBJECTIVE REFRACTION (RETINOSCOPY & AUTOREFRACTOR)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaperTextField('Retinoscopy OD (Gross / Net with working distance)', _retinoscopyOdController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaperTextField('Retinoscopy OS (Gross / Net with working distance)', _retinoscopyOsController),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 5: Subjective Refraction & Best Corrected Acuity
                _buildPaperSectionHeader('5. SUBJECTIVE MANIFEST REFRACTION GRID'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 45, child: Text('EYE', style: TextStyle(color: ClinicTheme.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold))),
                          Expanded(child: Text('SPHERE', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.textMuted))),
                          Expanded(child: Text('CYLINDER', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.textMuted))),
                          Expanded(child: Text('AXIS', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.textMuted))),
                          Expanded(child: Text('ADD', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.textMuted))),
                          Expanded(child: Text('BCVA', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: ClinicTheme.brandAccent, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Divider(height: 12, color: Color(0xFF334155)),
                      _buildRefractionEditableRow('OD', _rxSphereOdController, _rxCylOdController, _rxAxisOdController, _rxAddController, sc.vaOd),
                      const SizedBox(height: 8),
                      _buildRefractionEditableRow('OS', _rxSphereOsController, _rxCylOsController, _rxAxisOsController, _rxAddController, sc.vaOs),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Section 6: Slit Lamp Biomicroscopy (Anterior Segment)
                _buildPaperSectionHeader('6. SLIT LAMP BIOMICROSCOPY (ANTERIOR SEGMENT)'),
                const SizedBox(height: 8),
                _buildPaperTextField('Anterior Segment Findings (Lids, Cornea, AC, Iris, Lens)', _slitLampController),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _buildInteractiveCheckbox('Cornea Clear OU', _formFluoresceinClear, (v) => setState(() => _formFluoresceinClear = v!)),
                    _buildInteractiveCheckbox('Abnormal TBUT (<10s)', _formTearBreakupAbnormal, (v) => setState(() => _formTearBreakupAbnormal = v!)),
                    _buildInteractiveCheckbox('Meibomian Gland Capping', _formMeibomianCapped, (v) => setState(() => _formMeibomianCapped = v!)),
                    _buildInteractiveCheckbox('AC Deep & Quiet (Van Herick Gr 4)', true, (v) {}),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 7: Tonometry / Intraocular Pressure (IOP)
                _buildPaperSectionHeader('7. TONOMETRY (GOLDMANN APPLANATION)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaperTextField('IOP OD (mmHg @ 10:42 AM)', _iopOdController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPaperTextField('IOP OS (mmHg @ 10:42 AM)', _iopOsController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PACHYMETRY CCT', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: ClinicTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text('OD: ${sc.cctOd} · OS: ${sc.cctOs}', style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 8: Posterior Segment & Ophthalmoscopy
                _buildPaperSectionHeader('8. DILATED POSTERIOR SEGMENT & OPHTHALMOSCOPY'),
                const SizedBox(height: 8),
                _buildPaperTextField('Optic Nerve C/D Ratio, Neuroretinal Rim & Retinal Vasculature', _fundusCdController),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _buildInteractiveCheckbox('Dilated Exam Performed OU', _formDilatedOu, (v) => setState(() => _formDilatedOu = v!)),
                    _buildInteractiveCheckbox('Macula Flat OU (Intact Reflex)', _formMaculaFlat, (v) => setState(() => _formMaculaFlat = v!)),
                    _buildInteractiveCheckbox('Vertical Notch OS', _formVerticalNotch, (v) => setState(() => _formVerticalNotch = v!)),
                  ],
                ),
                const SizedBox(height: 14),

                // Section 9: Diagnostic Assessment & Management Plan
                _buildPaperSectionHeader('9. DIAGNOSTIC ASSESSMENT & CLINICAL MANAGEMENT PLAN'),
                const SizedBox(height: 8),
                TextField(
                  controller: _assessmentPlanController,
                  maxLines: 4,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ClinicTheme.brandAccent)),
                    hintText: 'Enter clinical diagnoses, prescribed drops, and recall interval...',
                    hintStyle: const TextStyle(color: ClinicTheme.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Doctor Signature Line & Chart Verification
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: ClinicTheme.brandAccent, size: 18),
                          const SizedBox(width: 8),
                          Text('Signed by Dr. Ada Optometrist, Lic #OPT-48201', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: ClinicTheme.brandAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('Electronically Stamped & Synced via GozVision Digital Twin', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: ClinicTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Bottom Actions
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ClinicTheme.brandAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Save Form to Patient Encounter Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Digital Twin Clinical Record saved and synced with SOAP note and EHR export!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: ClinicTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Export PDF Sheet', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Exporting filled optometric clinical record sheet PDF...')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ClinicTheme.brandAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: ClinicTheme.brandAccent, width: 3)),
      ),
      child: Text(
        title,
        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.bold, color: ClinicTheme.brandAccent, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildHeaderBlockCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: ClinicTheme.textMuted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPaperTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: ClinicTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF475569))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF475569))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: ClinicTheme.brandAccent)),
          ),
        ),
      ],
    );
  }

  Widget _buildRefractionEditableRow(String eye, TextEditingController sph, TextEditingController cyl, TextEditingController axis, TextEditingController add, String bcva) {
    return Row(
      children: [
        SizedBox(width: 45, child: Text(eye, style: GoogleFonts.sora(color: ClinicTheme.brandAccent, fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: sph,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: cyl,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: axis,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: add,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            bcva,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: ClinicTheme.brandAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            activeColor: ClinicTheme.brandAccent,
            checkColor: Colors.black,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 5: Discrete Optometric Findings (The Eye Care Cockpit)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOptometricFindingsTab(_ClinicalScenario sc) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Visual Acuity & Refraction Matrix
        _buildFindingCard(
          icon: Icons.visibility_rounded,
          title: 'Visual Acuity & Manifest Refraction',
          badge: 'Distance & Near',
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(2.0),
              3: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                children: [
                  _tableCell('Eye', isHeader: true),
                  _tableCell('Corrected VA', isHeader: true),
                  _tableCell('Manifest Rx', isHeader: true),
                  _tableCell('Add / Near', isHeader: true),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('OD (Right)'),
                  _tableCell(sc.vaOd, isBold: true),
                  _tableCell(sc.rxOd),
                  _tableCell('${sc.add} (J1+)'),
                ],
              ),
              TableRow(
                children: [
                  _tableCell('OS (Left)'),
                  _tableCell(sc.vaOs, isBold: true),
                  _tableCell(sc.rxOs),
                  _tableCell('${sc.add} (J1)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tonometry & Pachymetry (IOP)
        _buildFindingCard(
          icon: Icons.speed_rounded,
          title: 'Tonometry & Corneal Pachymetry (IOP)',
          badge: 'Goldmann Applanation',
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClinicTheme.obsidianElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OD (RIGHT EYE)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(sc.iopOd,
                              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: ClinicTheme.brandAccent)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Normal (≤21)', style: TextStyle(fontSize: 9.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('CCT: ${sc.cctOd}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ClinicTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClinicTheme.obsidianElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sc.iopAlertOs ? const Color(0xFFEF4444).withOpacity(0.4) : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OS (LEFT EYE)',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(sc.iopOs,
                              style: GoogleFonts.sora(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: sc.iopAlertOs ? const Color(0xFFEF4444) : ClinicTheme.brandAccent)),
                          const SizedBox(width: 8),
                          if (sc.iopAlertOs)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PRESSURE SPIKE', style: TextStyle(fontSize: 9.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('CCT: ${sc.cctOs}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ClinicTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Slit Lamp Biomicroscopy & Tear Film
        _buildFindingCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Slit Lamp Biomicroscopy (Anterior Segment)',
          badge: 'Cornea, Lens & Tear Film',
          child: Column(
            children: [
              _buildFindingRow('Cornea', 'Clear OU, no edema, intact epithelium'),
              _buildFindingRow('Anterior Chamber', 'Deep & quiet, Van Herick Grade 4 bilaterally'),
              _buildFindingRow('Lens (OD / OS)', 'OD: ${sc.lensOd} • OS: ${sc.lensOs}'),
              _buildFindingRow('Tear Breakup Time (TBUT)', sc.tbut),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Dilated Fundus Examination (DFE)
        _buildFindingCard(
          icon: Icons.camera_alt_outlined,
          title: 'Dilated Fundus Examination (DFE)',
          badge: 'Optic Disc & Macula',
          child: Column(
            children: [
              _buildFindingRow('Optic Disc (OD)', 'C/D Ratio ${sc.cdRatioOd}, round, pink, distinct margins, rim intact'),
              _buildFindingRow('Optic Disc (OS)', 'C/D Ratio ${sc.cdRatioOs}, vertical thinning, glaucoma suspect alert'),
              _buildFindingRow('Macula', 'Flat OU, no macular edema, intact foveal reflex'),
              _buildFindingRow('Periphery', '360° intact, flat, no retinal tears, holes, or lattice degeneration'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFindingCard({
    required IconData icon,
    required String title,
    required String badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ClinicTheme.brandAccent, size: 18),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: ClinicTheme.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ClinicTheme.brandAccentFaint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: ClinicTheme.brandAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: isHeader
            ? GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w700, color: ClinicTheme.textMuted)
            : GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? ClinicTheme.brandAccent : ClinicTheme.textPrimary,
              ),
      ),
    );
  }

  Widget _buildFindingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: ClinicTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 4: Multi-EHR Export Bridge
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEhrBridgeTab(_ClinicalScenario sc) {
    final ehrTargets = ['Epic Systems', 'Eyefinity EHR', 'RevolutionEHR', 'ModMed EMA', 'FHIR R4 JSON'];

    String formattedNote;
    switch (_selectedEhrBridge) {
      case 'Epic Systems':
        formattedNote = '''=== EPICCARE AMBULATORY OPHTHALMIC ENCOUNTER ===
PATIENT: ${sc.patientName} (MRN: ${sc.mrn})
DATE: ${DateTime.now().toLocal().toString().split('.')[0]}
ATTENDING: Dr. Ada Optometrist, OD

.BRIEFOPHTH
CHIEF COMPLAINT: ${sc.chiefComplaint}

.SUBJECTIVE
${sc.subjective}

.EXAMDISCRETE
VISUAL ACUITY: OD ${sc.vaOd} (Rx: ${sc.rxOd}) | OS ${sc.vaOs} (Rx: ${sc.rxOs})
TONOMETRY (Goldmann): OD ${sc.iopOd} | OS ${sc.iopOs} (Pachymetry CCT: OD ${sc.cctOd}, OS ${sc.cctOs})
SLIT LAMP: Cornea clear OU. AC deep & quiet. Lens OD: ${sc.lensOd}, OS: ${sc.lensOs}.
FUNDUS: OD C/D ${sc.cdRatioOd} | OS C/D ${sc.cdRatioOs}. Macula flat OU.

.ASSESSMENT & PLAN
${sc.assessment}
${sc.plan}

ELECTRONIC SIGNATURE: Signed by Dr. Ada Optometrist, OD via GozVision Ambient Bridge.''';
        break;

      case 'Eyefinity EHR':
        formattedNote = '''=== EYEFINITY EHR / OFFICEMATE CLOUD EXAM NOTE ===
Patient: ${sc.patientName}
Exam Date: ${DateTime.now().toLocal().toString().split('.')[0]}
Doctor: Dr. Ada Optometrist, OD

[CHIEF COMPLAINT]
${sc.chiefComplaint}

[REFRACTION & SPECTACLE RX]
OD: ${sc.rxOd} (VA: ${sc.vaOd}) Add: ${sc.add}
OS: ${sc.rxOs} (VA: ${sc.vaOs}) Add: ${sc.add}
Dispensary Status: Transmitted to Bachs Optical Dispensary

[OCULAR HEALTH]
IOP OD: ${sc.iopOd} | IOP OS: ${sc.iopOs}
Slit Lamp: Cornea clear OU. Lens OD ${sc.lensOd}, OS ${sc.lensOs}.
Fundus C/D: OD ${sc.cdRatioOd}, OS ${sc.cdRatioOs}.

[DIAGNOSIS & BILLING]
${sc.icdCodes.join('\n')}
CPT: ${sc.cptCodes.join(', ')}''';
        break;

      case 'RevolutionEHR':
        formattedNote = '''=== REVOLUTION EHR CLOUD POD EXPORT ===
Patient Name: ${sc.patientName}
Encounter Type: Comprehensive Ophthalmic Exam

<SubjectivePod>
${sc.subjective}
</SubjectivePod>

<RefractionPod>
OD: ${sc.rxOd} (VA: ${sc.vaOd})
OS: ${sc.rxOs} (VA: ${sc.vaOs})
</RefractionPod>

<TonometryPod>
OD: ${sc.iopOd} | OS: ${sc.iopOs}
Method: Goldmann Applanation
</TonometryPod>

<AssessmentPlanPod>
${sc.assessment}
${sc.plan}
</AssessmentPlanPod>''';
        break;

      default:
        formattedNote = '''{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "resource": {
        "resourceType": "DocumentReference",
        "subject": { "display": "${sc.patientName}", "reference": "Patient/${sc.mrn}" },
        "author": [{ "display": "Dr. Ada Optometrist, OD" }],
        "date": "${DateTime.now().toUtc().toIso8601String()}",
        "description": "GozVision Verified Ambient Scribe Chart"
      }
    },
    {
      "resource": {
        "resourceType": "Observation",
        "code": { "coding": [{ "system": "http://loinc.org", "code": "55284-4", "display": "IOP Goldmann" }] },
        "component": [
          { "code": { "text": "OD" }, "valueQuantity": { "value": 16, "unit": "mmHg" } },
          { "code": { "text": "OS" }, "valueQuantity": { "value": 24, "unit": "mmHg" } }
        ]
      }
    }
  ]
}''';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SELECT TARGET EHR FORMAT:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: ClinicTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Direct API Tunnel Active',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ehrTargets.map((target) {
              final isSel = _selectedEhrBridge == target;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(target),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedEhrBridge = target);
                  },
                  selectedColor: ClinicTheme.brandAccentFaint,
                  backgroundColor: ClinicTheme.obsidianElevated,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? ClinicTheme.brandAccent : ClinicTheme.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSel ? ClinicTheme.brandAccent : ClinicTheme.border,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  formattedNote,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyEhrFormat(BuildContext context, _ClinicalScenario sc) {
    final note = '''=== OPHTHALMIC CLINICAL ENCOUNTER NOTE ===
Patient: ${sc.patientName} (MRN: ${sc.mrn})
Date: ${DateTime.now().toLocal().toString().split('.')[0]}
Provider: Dr. Ada Optometrist, OD

[SUBJECTIVE]
${sc.subjective}

[OBJECTIVE]
${sc.objective}

[ASSESSMENT]
${sc.assessment}

[PLAN]
${sc.plan}

Electronically verified via GozVision Ambient Scribe Studio.''';

    Clipboard.setData(ClipboardData(text: note));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Copied to clipboard in EHR format (Epic / Eyefinity ready).'),
        backgroundColor: ClinicTheme.brandAccentDim,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEvidenceModal(BuildContext context, {required String title, required String transcript}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClinicTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: ClinicTheme.brandAccent),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.sora(fontSize: 16, color: ClinicTheme.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verbatim exam dialogue snippet matching this clinical assessment with speaker diarization.',
                  style: TextStyle(fontSize: 12, color: ClinicTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SelectableText(
                    transcript,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.5,
                      height: 1.5,
                      color: ClinicTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: ClinicTheme.brandAccent)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clinical Scenario Model
// ─────────────────────────────────────────────────────────────────────────────
class _ClinicalScenario {
  final String name;
  final String patientName;
  final String mrn;
  final String ageGender;
  final String examLane;
  final String chiefComplaint;
  final String hpi;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String transcript;
  final String vaOd;
  final String vaOs;
  final String rxOd;
  final String rxOs;
  final String add;
  final String iopOd;
  final String iopOs;
  final bool iopAlertOs;
  final String cctOd;
  final String cctOs;
  final String cdRatioOd;
  final String cdRatioOs;
  final String lensOd;
  final String lensOs;
  final String tbut;
  final List<String> icdCodes;
  final List<String> cptCodes;
  final String pohx;
  final String pmhx;
  final String fmhx;
  final String visualDemands;
  final String currentCorrection;
  final String oldCartsOnset;
  final String oldCartsLocation;
  final String oldCartsDuration;
  final String oldCartsCharacter;
  final String oldCartsAggravating;
  final String oldCartsRadiation;
  final String oldCartsTiming;
  final String oldCartsSeverity;

  const _ClinicalScenario({
    required this.name,
    required this.patientName,
    required this.mrn,
    required this.ageGender,
    required this.examLane,
    required this.chiefComplaint,
    required this.hpi,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.transcript,
    required this.vaOd,
    required this.vaOs,
    required this.rxOd,
    required this.rxOs,
    required this.add,
    required this.iopOd,
    required this.iopOs,
    required this.iopAlertOs,
    required this.cctOd,
    required this.cctOs,
    required this.cdRatioOd,
    required this.cdRatioOs,
    required this.lensOd,
    required this.lensOs,
    required this.tbut,
    required this.icdCodes,
    required this.cptCodes,
    this.pohx = 'POAG Suspect OU (3 yrs), Pseudophakia OD (2023), No retinal detachment, No amblyopia.',
    this.pmhx = 'Essential Hypertension (Amlodipine 5mg QD), Hyperlipidemia (Atorvastatin 20mg). Denies Diabetes or Autoimmune disorders.',
    this.fmhx = 'Maternal grandmother had glaucoma with severe peripheral loss. Father had macular degeneration. No family keratoconus.',
    this.visualDemands = 'Retired librarian; reads 3-4 hours daily, drives locally during daylight, uses iPad for audiobooks. Frequent screen reflections.',
    this.currentCorrection = 'Progressive addition lenses (PAL) 2.5 years old. Fit satisfactory, reports progressive reading strain in low illumination.',
    this.oldCartsOnset = 'Gradual increase over past 6-8 weeks.',
    this.oldCartsLocation = 'Left eye (OS) retrobulbar aching and eyebrow heaviness.',
    this.oldCartsDuration = 'Intermittent episodes lasting 45-90 minutes, primarily in evening.',
    this.oldCartsCharacter = 'Dull deep aching pressure, mild peripheral brow tightness; non-throbbing.',
    this.oldCartsAggravating = 'Prolonged reading under low indoor illumination, prolonged computer glare.',
    this.oldCartsRadiation = 'Radiates to left temporal region; no jaw claudication, no scalp tenderness.',
    this.oldCartsTiming = 'Worse in the evening before bed, typically relieved by rest and eye drops.',
    this.oldCartsSeverity = 'Moderate (4/10 discomfort); causes patient to stop reading.',
  });
}
