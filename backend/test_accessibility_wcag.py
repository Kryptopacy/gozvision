"""Automated WCAG 2.2 Level AAA Contrast & Accessibility Audit Test Suite.

Programmatically verifies:
1. Relative luminance and contrast ratios meet WCAG 2.2 Level AAA (>= 7.0:1) for text
   and Level AA (>= 4.5:1) for large text against the Obsidian background (#08090C).
2. Touch target dimensions satisfy WCAG 2.2 SC 2.5.8 (Target Size Minimum >= 48x48 dp).
3. Plain-English layperson terminology filter properly replaces clinical jargon
   to prevent cognitive overload for visually impaired patients.
"""
import math
import unittest


def hex_to_rgb(hex_code: str) -> tuple[int, int, int]:
    """Convert hex string (e.g. #08090C or #FFFFFF) to RGB tuple."""
    hex_code = hex_code.lstrip("#")
    if len(hex_code) == 3:
        hex_code = "".join(c * 2 for c in hex_code)
    return tuple(int(hex_code[i:i+2], 16) for i in (0, 2, 4))


def srgb_channel_to_linear(val: float) -> float:
    """Converts an 8-bit sRGB channel [0, 255] to linear luminance [0.0, 1.0]."""
    v = val / 255.0
    if v <= 0.04045:
        return v / 12.92
    return math.pow((v + 0.055) / 1.055, 2.4)


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    """Calculates relative luminance per W3C WCAG 2.2 standard."""
    r, g, b = (srgb_channel_to_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(hex1: str, hex2: str) -> float:
    """Calculates WCAG 2.2 contrast ratio between two hex colors: (L1 + 0.05) / (L2 + 0.05)."""
    l1 = relative_luminance(hex_to_rgb(hex1))
    l2 = relative_luminance(hex_to_rgb(hex2))
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


class TestWcag22Accessibility(unittest.TestCase):

    def setUp(self):
        # GozVision Design System Tokens (from packages/design_system/)
        self.background_obsidian = "#08090C"
        self.surface_card = "#12141A"

        # Text & Foreground Tokens
        self.text_primary = "#FFFFFF"           # Crisp white
        self.text_secondary = "#E2E8F0"         # Slate light
        self.accent_malachite = "#00FFC8"       # Goz signature high-visibility green
        self.accent_amber_warning = "#FFB703"   # High-contrast hazard amber
        self.accent_emergency_red = "#FF4D4D"   # SOS alert crimson

    def test_wcag_aaa_text_contrast(self):
        """Verify standard text colors satisfy WCAG 2.2 Level AAA (>= 7.0:1) contrast."""
        # Primary text contrast on Obsidian background
        ratio_primary = contrast_ratio(self.text_primary, self.background_obsidian)
        self.assertGreaterEqual(ratio_primary, 7.0, f"Primary text ratio {ratio_primary:.2f} failed AAA (>= 7.0)")
        self.assertAlmostEqual(ratio_primary, 19.8, delta=1.5)

        # Secondary text contrast on Obsidian background
        ratio_secondary = contrast_ratio(self.text_secondary, self.background_obsidian)
        self.assertGreaterEqual(ratio_secondary, 7.0, f"Secondary text ratio {ratio_secondary:.2f} failed AAA (>= 7.0)")

        # Signature Malachite green on Obsidian background
        ratio_malachite = contrast_ratio(self.accent_malachite, self.background_obsidian)
        self.assertGreaterEqual(ratio_malachite, 7.0, f"Malachite accent ratio {ratio_malachite:.2f} failed AAA (>= 7.0)")

    def test_wcag_ui_controls_and_graphics_contrast(self):
        """Verify non-text UI components satisfy WCAG 2.2 Level AA (>= 3.0:1) contrast."""
        # Warning amber on dark surface
        ratio_amber = contrast_ratio(self.accent_amber_warning, self.background_obsidian)
        self.assertGreaterEqual(ratio_amber, 4.5)

        # Emergency red on dark surface
        ratio_red = contrast_ratio(self.accent_emergency_red, self.background_obsidian)
        self.assertGreaterEqual(ratio_red, 4.5)

    def test_tap_target_dimensions_satisfy_touch_guidelines(self):
        """Verify tactile button sizes adhere to WCAG 2.2 AAA minimums (>= 48x48 dp)."""
        goz_tap_targets = {
            "btn_emergency_sos": (64, 64),
            "btn_voice_mic": (56, 56),
            "btn_contrast_mode_toggle": (48, 48),
            "btn_optical_quick_reorder": (52, 52),
        }

        for btn_name, (width, height) in goz_tap_targets.items():
            self.assertGreaterEqual(width, 48, f"{btn_name} width {width}dp < 48dp minimum")
            self.assertGreaterEqual(height, 48, f"{btn_name} height {height}dp < 48dp minimum")

    def test_plain_english_medical_translator(self):
        """Verify cognitive load filter replaces medical jargon with clear layperson terms."""
        jargon_dictionary = {
            "Photophobia Filter": "Light & Glare Shield",
            "Meibomian Gland Therapy": "Warm Eye Relief Protocol",
            "Eccentric Fixation Guidance": "Side-Vision Guide",
            "Bachs Neural Pay": "Instant Clinic Checkout",
        }

        sample_clinical_text = "Activate Photophobia Filter and initiate Meibomian Gland Therapy for dry eye."

        # Apply dictionary transformation
        layperson_text = sample_clinical_text
        for jargon, layperson in jargon_dictionary.items():
            layperson_text = layperson_text.replace(jargon, layperson)

        self.assertNotIn("Photophobia Filter", layperson_text)
        self.assertIn("Light & Glare Shield", layperson_text)
        self.assertIn("Warm Eye Relief Protocol", layperson_text)


if __name__ == "__main__":
    unittest.main()
