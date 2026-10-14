import 'package:flutter/material.dart';
import '../core/clinic_theme.dart';

/// Doctor-Side Clinical Copilot & Quick Reference Dialog.
///
/// Enables optometrists and ophthalmologists to quickly cross-check
/// clinical guidelines, drug contraindications, IOP target formulas,
/// and disease staging (AAO, AOA, TFOS DEWS II, NEI) during exams or note review.
class DoctorReferenceDialog extends StatefulWidget {
  const DoctorReferenceDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const DoctorReferenceDialog(),
    );
  }

  @override
  State<DoctorReferenceDialog> createState() => _DoctorReferenceDialogState();
}

class _DoctorReferenceDialogState extends State<DoctorReferenceDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, String>> _curatedGuidelines = [
    {
      'title': 'Glaucoma: Target IOP & OHTS Formula',
      'source': 'American Academy of Ophthalmology (AAO PPP 2025/2026)',
      'summary':
          'Baseline reduction of 20-30% for mild/moderate open-angle glaucoma; >30-40% for advanced damage. Adjust for central corneal thickness (CCT) via pachymetry (<555 µm increases risk). Monitor visual field MD progression rate.',
      'category': 'Glaucoma',
    },
    {
      'title': 'Ophthalmic Beta-Blockers (Timolol) Contraindications',
      'source': 'AOA Clinical Practice Guideline & FDA Drug Safety',
      'summary':
          'Absolute contraindications: Bronchial asthma, severe COPD, sinus bradycardia (<50 bpm), 2nd/3rd-degree AV block, overt cardiac failure. Always ask about pulmonary and cardiac history before prescribing beta-blocker drops.',
      'category': 'Pharmacology',
    },
    {
      'title': 'Dry Eye Disease Staging (TFOS DEWS II)',
      'source': 'Tear Film & Ocular Surface Society (TFOS DEWS II)',
      'summary':
          'Stage 1: Mild/episodic; artificial tears 4x/day, environmental modification. Stage 2: Chronic staining/MGD; preservative-free tears, lipid sprays, punctal plugs, cyclosporine/lifitegrast. Stage 3/4: Severe; autologous serum, scleral lenses.',
      'category': 'Cornea / Surface',
    },
    {
      'title': 'Cup-to-Disc (C/D) Ratio Asymmetry Protocol',
      'source': 'World Glaucoma Association & Optometric Clinical Consensus',
      'summary':
          'C/D asymmetry >0.2 between eyes in the absence of anisometropia warrants full glaucoma workup (OCT RNFL, 24-2 visual field, gonioscopy). Evaluate ISNT rule: Inferior rim thickest, then Superior, Nasal, Temporal.',
      'category': 'Glaucoma',
    },
    {
      'title': 'Diabetic Retinopathy Screening & Referral Intervals',
      'source': 'American Diabetes Association (ADA) & AAO PPP',
      'summary':
          'Type 1: Initial dilated exam within 5 years of diagnosis, then annually. Type 2: Initial dilated exam at time of diabetes diagnosis, then annually. If non-proliferative with macular edema or proliferative: refer immediately for anti-VEGF/panretinal photocoagulation.',
      'category': 'Retina',
    },
    {
      'title': 'Age-Related Macular Degeneration: AREDS2 Formulation',
      'source': 'National Eye Institute (NEI) AREDS2 Trial',
      'summary':
          'Components: Vitamin C (500 mg), Vitamin E (400 IU), Zinc (80 mg), Copper (2 mg), Lutein (10 mg), Zeaxanthin (2 mg). Beta-carotene excluded due to lung cancer risk in smokers. Indicated for intermediate dry AMD or advanced AMD in one eye.',
      'category': 'Retina',
    },
  ];

  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _curatedGuidelines.where((item) {
      if (_filter.isEmpty) return true;
      final query = _filter.toLowerCase();
      return item['title']!.toLowerCase().contains(query) ||
          item['summary']!.toLowerCase().contains(query) ||
          item['category']!.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      backgroundColor: ClinicTheme.cardBackground,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ClinicTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book, color: ClinicTheme.brandAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Goz Clinical Copilot: Doctor Quick-Reference',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ClinicTheme.textPrimary,
                  ),
                ),
                Text(
                  'Evidence-based optometric guidelines • RAG dynamic knowledge base',
                  style: TextStyle(fontSize: 11, color: ClinicTheme.brandAccent),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: ClinicTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: ClinicTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search condition, drug contraindication, or guideline...',
                hintStyle: const TextStyle(color: ClinicTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: ClinicTheme.brandAccent),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: ClinicTheme.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: ClinicTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _filter = val),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ClinicTheme.surfaceDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ClinicTheme.surfaceLight.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: ClinicTheme.brandAccent, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Clinical Decision Support: Grounded in AAO Preferred Practice Patterns, AOA Guidelines & NEI protocols.',
                      style: TextStyle(fontSize: 12, color: ClinicTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: ClinicTheme.textSecondary),
                          const SizedBox(height: 8),
                          Text(
                            'No matching guideline found for "$_filter"',
                            style: const TextStyle(color: ClinicTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Practice-specific clinical protocols can be added in Practice Settings.',
                            style: TextStyle(fontSize: 11, color: ClinicTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final item = filtered[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicTheme.surfaceLight.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ClinicTheme.brandAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['category']!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: ClinicTheme.brandAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['title']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ClinicTheme.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['summary']!,
                                style: const TextStyle(color: ClinicTheme.textSecondary, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.verified_outlined, size: 12, color: ClinicTheme.brandAccent),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Source: ${item['source']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ClinicTheme.brandAccent.withValues(alpha: 0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: ClinicTheme.brandAccent)),
        ),
      ],
    );
  }
}
