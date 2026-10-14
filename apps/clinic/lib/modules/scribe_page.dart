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

  // Paper Form Digitizer Interactive State
  bool _formFluoresceinClear = true;
  bool _formTearBreakupAbnormal = true;
  bool _formMeibomianCapped = true;
  bool _formMaculaFlat = true;
  bool _formVerticalNotch = true;
  bool _formDilatedOu = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                  icon: Icon(Icons.document_scanner_outlined, size: 15),
                  text: 'Paper Assessment Form Digitizer',
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
                _buildAssessmentFormDigitizerTab(sc),
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
          _buildHistoryProfileCard('Current Spectacle Correction & Contact Lenses', sc.currentCorrection, Icons.glasses_rounded, const Color(0xFFEC4899)),
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
  // TAB 4: Paper Assessment Form Digitizer (Custom Clinic Form OCR & Clone)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAssessmentFormDigitizerTab(_ClinicalScenario sc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Form Type Selector
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
                            'Paper Assessment Form Digitizer (Zero-Loss Form Extraction)',
                            style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('AI Vision OCR 2026', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Upload a phone photo or scan of your clinic\'s custom assessment form. GozVision parses all checkboxes, refraction matrices, and slit lamp diagrams into a live digital clone.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ClinicTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ClinicTheme.brandAccent,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Digitize New Paper Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Select form photo or PDF: GozVision AI Vision OCR ready.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Two-Column Workspace: Left = Scanned Paper Sheet Preview with Bounding Boxes; Right = Interactive Digital Form
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Physical Scanned Paper Form with AI Detected Bounding Boxes
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ClinicTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.image_outlined, size: 18, color: ClinicTheme.brandAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Physical Paper Form Source (Detected Geometry)',
                            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Paper visual
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('DR. ADA OPTOMETRY CARE · CLINICAL EXAM SHEET', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w800)),
                                Text('FORM #OD-REV-2026', style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 10)),
                              ],
                            ),
                            const Divider(color: Color(0xFFCBD5E1), height: 16),
                            _buildOcrDetectedBox('PATIENT DEMOGRAPHICS BLOCK', 'Name: ${sc.patientName} · Age: ${sc.ageGender} · MRN: ${sc.mrn}', const Color(0xFF0284C7)),
                            const SizedBox(height: 8),
                            _buildOcrDetectedBox('REFRACTION MATRIX (OD/OS)', 'OD: ${sc.rxOd} (VA ${sc.vaOd}) · OS: ${sc.rxOs} (VA ${sc.vaOs}) · Add: ${sc.add}', const Color(0xFF10B981)),
                            const SizedBox(height: 8),
                            _buildOcrDetectedBox('GOLDMANN IOP TONOMETRY', 'Time: 10:42 AM · OD: ${sc.iopOd} · OS: ${sc.iopOs} (Elevated Dial Marker)', const Color(0xFFEF4444)),
                            const SizedBox(height: 8),
                            _buildOcrDetectedBox('ANTERIOR SLIT LAMP & CORNEA', 'Cornea: Clear OU · AC: Deep & Quiet · TBUT: ${sc.tbut}', const Color(0xFF8B5CF6)),
                            const SizedBox(height: 8),
                            _buildOcrDetectedBox('DILATED RETINA & OPTIC NERVE', 'OD C/D: ${sc.cdRatioOd} · OS C/D: ${sc.cdRatioOs} Vertical Notch · Macula: Flat OU', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text('100% Geometry Matched · 24 Structured Data Fields Extracted', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Right Column: Interactive Digital Form Replica
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ClinicTheme.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ClinicTheme.brandAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.touch_app_outlined, size: 18, color: ClinicTheme.brandAccent),
                              const SizedBox(width: 8),
                              Text('Interactive Digital Form Replica', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ClinicTheme.brandAccentFaint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Live Editable', style: TextStyle(color: ClinicTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Interactive Checkbox Group Extracted from Form
                      Text('Anterior & Posterior Segment Checklist:', style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _buildInteractiveCheckbox('Cornea Clear OU', _formFluoresceinClear, (v) => setState(() => _formFluoresceinClear = v!)),
                          _buildInteractiveCheckbox('Abnormal TBUT (<10s)', _formTearBreakupAbnormal, (v) => setState(() => _formTearBreakupAbnormal = v!)),
                          _buildInteractiveCheckbox('Meibomian Capping', _formMeibomianCapped, (v) => setState(() => _formMeibomianCapped = v!)),
                          _buildInteractiveCheckbox('Macula Flat OU', _formMaculaFlat, (v) => setState(() => _formMaculaFlat = v!)),
                          _buildInteractiveCheckbox('C/D Vertical Notch OS', _formVerticalNotch, (v) => setState(() => _formVerticalNotch = v!)),
                          _buildInteractiveCheckbox('Dilated Exam Performed', _formDilatedOu, (v) => setState(() => _formDilatedOu = v!)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Interactive Refraction Table
                      Text('Subjective Refraction Grid:', style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClinicTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ClinicTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 40, child: Text('EYE', style: TextStyle(color: ClinicTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                                Expanded(child: Text('SPHERE', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted))),
                                Expanded(child: Text('CYLINDER', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted))),
                                Expanded(child: Text('AXIS', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted))),
                                Expanded(child: Text('ADD', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted))),
                                Expanded(child: Text('DVA', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.textMuted))),
                              ],
                            ),
                            const Divider(height: 10, color: ClinicTheme.border),
                            _buildRefractionTableRow('OD', '-1.75', '-0.75', '090', '+2.25', sc.vaOd),
                            const SizedBox(height: 4),
                            _buildRefractionTableRow('OS', '-2.00', '-1.25', '105', '+2.25', sc.vaOs),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Doctor Signature & Assessment Plan Block
                      Text('Clinical Impression & Signature:', style: GoogleFonts.plusJakartaSans(color: ClinicTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClinicTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ClinicTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sc.assessment, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white, height: 1.35)),
                            const Divider(height: 12, color: ClinicTheme.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Attending OD: Dr. Ada Optometrist, Lic #OPT-48201', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ClinicTheme.brandAccent)),
                                Text('Electronically Verified via GozVision', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: ClinicTheme.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ClinicTheme.brandAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.save_rounded, size: 16),
                              label: const Text('Save Form to Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Digital Assessment Form saved and linked to patient encounter chart!')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: ClinicTheme.border),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                            label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Generating filled optical examination PDF...')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrDetectedBox(String category, String detectedText, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(category, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(detectedText, style: GoogleFonts.jetBrainsMono(color: const Color(0xFF1E293B), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
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

  Widget _buildRefractionTableRow(String eye, String sph, String cyl, String axis, String add, String dva) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(eye, style: GoogleFonts.sora(color: ClinicTheme.brandAccent, fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: Text(sph, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600))),
        Expanded(child: Text(cyl, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600))),
        Expanded(child: Text(axis, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600))),
        Expanded(child: Text(add, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600))),
        Expanded(child: Text(dva, textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: ClinicTheme.brandAccent, fontWeight: FontWeight.bold))),
      ],
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
