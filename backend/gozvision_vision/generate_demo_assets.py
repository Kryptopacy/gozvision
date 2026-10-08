"""GozVision Demo Asset Generator: OpenCV 5 Computer Vision Showcase.

Generates clinical-grade split-screen visual comparisons and triptych infographics
demonstrating GozVision's real-time ophthalmic computer vision pipelines for:
1. AMD (Age-Related Macular Degeneration): Contrast enhancement & curb/stair edge detection.
2. Cataract & Photophobia: Specular glare suppression & contrast recovery.
3. Reading Assistance: Morphological text block localization for low-vision patients.

Saves high-resolution assets to `docs/assets/` for Devpost and hackathon presentations.
"""

from pathlib import Path
import cv2
import numpy as np
from gozvision_vision.cv_pipeline import LowVisionEnhancer, VisionEnhancementConfig

OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "docs" / "assets"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Colors in BGR
COLOR_DARK_BG = (24, 24, 27)       # #18181b slate/dark
COLOR_TEXT_WHITE = (245, 245, 245)
COLOR_TEXT_MUTED = (160, 160, 175)
COLOR_BRAND_GREEN = (60, 215, 120)  # GozVision Malachite Emerald
COLOR_WARN_RED = (80, 80, 235)      # Soft coral / warning red
COLOR_DIVIDER = (45, 45, 55)


def add_header_banner(
    image: np.ndarray,
    title: str,
    subtitle: str,
    left_label: str,
    right_label: str,
) -> np.ndarray:
    """Wraps a side-by-side split screen in a clinical branded header and label frame."""
    h, w, c = image.shape
    banner_height = 90
    footer_height = 40
    canvas = np.full((h + banner_height + footer_height, w, 3), COLOR_DARK_BG, dtype=np.uint8)

    # 1. Header Bar
    cv2.putText(canvas, title, (25, 42), cv2.FONT_HERSHEY_DUPLEX, 0.95, COLOR_TEXT_WHITE, 2, cv2.LINE_AA)
    cv2.putText(canvas, subtitle, (25, 72), cv2.FONT_HERSHEY_SIMPLEX, 0.55, COLOR_TEXT_MUTED, 1, cv2.LINE_AA)
    cv2.putText(
        canvas,
        "GozVision | OpenCV 5 AI",
        (w - 300, 42),
        cv2.FONT_HERSHEY_DUPLEX,
        0.75,
        COLOR_BRAND_GREEN,
        1,
        cv2.LINE_AA,
    )

    # 2. Place comparison images
    canvas[banner_height : banner_height + h, 0:w] = image

    # 3. Side-by-side floating badge pills
    mid_x = w // 2

    # Left Pill (Input / Baseline)
    cv2.rectangle(canvas, (25, banner_height + 15), (mid_x - 30, banner_height + 55), (15, 15, 20), -1)
    cv2.rectangle(canvas, (25, banner_height + 15), (mid_x - 30, banner_height + 55), COLOR_WARN_RED, 1)
    cv2.putText(
        canvas,
        left_label,
        (40, banner_height + 42),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.58,
        (200, 200, 240),
        1,
        cv2.LINE_AA,
    )

    # Right Pill (GozVision Enhanced)
    cv2.rectangle(canvas, (mid_x + 25, banner_height + 15), (w - 30, banner_height + 55), (15, 25, 20), -1)
    cv2.rectangle(canvas, (mid_x + 25, banner_height + 15), (w - 30, banner_height + 55), COLOR_BRAND_GREEN, 1)
    cv2.putText(
        canvas,
        right_label,
        (mid_x + 40, banner_height + 42),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.58,
        COLOR_BRAND_GREEN,
        1,
        cv2.LINE_AA,
    )

    # Center Divider
    cv2.line(canvas, (mid_x, banner_height), (mid_x, banner_height + h), COLOR_BRAND_GREEN, 2)

    # 4. Footer
    cv2.putText(
        canvas,
        "Low-Latency Real-Time Pipeline: Tested with OpenCV 5 + NumPy | Amazon ECS & CloudFront Live Ingress",
        (25, banner_height + h + 26),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.48,
        COLOR_TEXT_MUTED,
        1,
        cv2.LINE_AA,
    )

    return canvas


def synthesize_stair_curb_scene(width: int = 640, height: int = 480) -> np.ndarray:
    """Generates a realistic low-contrast concrete staircase / curb scene."""
    img = np.zeros((height, width, 3), dtype=np.uint8)

    # Soft ambient concrete gray gradient
    for y in range(height):
        val = int(120 + 35 * (y / height))
        img[y, :] = (val, val + 2, val + 4)

    # Draw low-contrast staircase steps
    steps = 4
    step_h = height // (steps + 1)
    for i in range(1, steps + 1):
        y_pos = i * step_h
        # Step surface
        cv2.rectangle(img, (0, y_pos), (width, height), (135 + i * 5, 137 + i * 5, 140 + i * 5), -1)
        # Subtle, low-contrast shadow edge (hard for AMD patients to see)
        cv2.line(img, (0, y_pos), (width, y_pos), (110, 112, 114), 2)
        # Add subtle concrete texture grain
        noise = np.random.normal(0, 4, (step_h, width, 3)).astype(np.int16)
        slice_y = img[y_pos - step_h : y_pos]
        if slice_y.shape[0] == step_h:
            img[y_pos - step_h : y_pos] = np.clip(slice_y.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    # Add a crosswalk line & small ground obstacle (trip hazard)
    cv2.rectangle(img, (width // 2 - 40, height - 80), (width // 2 + 40, height - 40), (145, 148, 150), -1)
    cv2.rectangle(img, (width // 2 - 40, height - 80), (width // 2 + 40, height - 40), (105, 107, 108), 1)

    return img


def synthesize_glare_hallway_scene(width: int = 640, height: int = 480) -> np.ndarray:
    """Generates an indoor hospital corridor washed out by blinding specular window glare."""
    img = np.zeros((height, width, 3), dtype=np.uint8)

    # Corridor walls perspective
    cv2.fillPoly(img, [np.array([[0, 0], [width // 3, height // 3], [width // 3, height * 2 // 3], [0, height]])], (110, 115, 120))
    cv2.fillPoly(img, [np.array([[width, 0], [width * 2 // 3, height // 3], [width * 2 // 3, height * 2 // 3], [width, height]])], (90, 95, 100))
    cv2.fillPoly(img, [np.array([[width // 3, height * 2 // 3], [width * 2 // 3, height * 2 // 3], [width, height], [0, height]])], (70, 75, 80))
    cv2.fillPoly(img, [np.array([[0, 0], [width, 0], [width * 2 // 3, height // 3], [width // 3, height // 3]])], (140, 145, 150))

    # Center exit doorway with medical sign
    door_left = width // 3 + 40
    door_right = width * 2 // 3 - 40
    door_top = height // 3 + 20
    door_bottom = height * 2 // 3
    cv2.rectangle(img, (door_left, door_top), (door_right, door_bottom), (150, 155, 160), -1)

    # Blinding specular glare washed over the center right (sunlight reflection / overexposure)
    center_glare = (width // 2 + 30, height // 2 - 20)
    for radius in range(160, 10, -10):
        intensity = int(255 - (radius / 160.0) * 80)
        cv2.circle(img, center_glare, radius, (intensity, intensity, intensity), -1)

    return img


def synthesize_prescription_scene(width: int = 640, height: int = 480) -> np.ndarray:
    """Generates a high-detail prescription pill bottle label scene."""
    img = np.full((height, width, 3), (220, 222, 225), dtype=np.uint8)

    # Bottle container background
    bottle_rect = (width // 6, 40, width * 2 // 3, height - 80)
    cv2.rectangle(img, (bottle_rect[0], bottle_rect[1]), (bottle_rect[0] + bottle_rect[2], bottle_rect[1] + bottle_rect[3]), (250, 250, 250), -1)
    cv2.rectangle(img, (bottle_rect[0], bottle_rect[1]), (bottle_rect[0] + bottle_rect[2], bottle_rect[1] + bottle_rect[3]), (180, 180, 185), 3)

    # Blue Rx Pharmacy Header banner
    cv2.rectangle(img, (bottle_rect[0] + 10, 50), (bottle_rect[0] + bottle_rect[2] - 10, 110), (180, 80, 40), -1)
    cv2.putText(img, "GOZVISION METROPOLITAN EYE CLINIC", (bottle_rect[0] + 25, 88), cv2.FONT_HERSHEY_DUPLEX, 0.62, (255, 255, 255), 1, cv2.LINE_AA)

    # Prescription lines
    lines = [
        "Rx #4928190-A   Date: 2026-10-08",
        "Patient: ELEANOR VANCE (Age: 71)",
        "TIMOLOL MALEATE OPHTHALMIC 0.5%",
        "Instill 1 drop into Left Eye (OS) BID",
        "WARNING: For Ophthalmic Use Only",
        "Refills remaining: 2  |  Dr. O. Adegoke",
    ]

    curr_y = 150
    for line in lines:
        font_scale = 0.55 if "TIMOLOL" not in line else 0.65
        thickness = 1 if "TIMOLOL" not in line else 2
        color = (20, 20, 20) if "WARNING" not in line else (0, 0, 180)
        cv2.putText(img, line, (bottle_rect[0] + 25, curr_y), cv2.FONT_HERSHEY_SIMPLEX, font_scale, color, thickness, cv2.LINE_AA)
        curr_y += 38

    # Small barcode at bottom
    for bx in range(bottle_rect[0] + 30, bottle_rect[0] + 280, 6):
        cv2.line(img, (bx, curr_y + 10), (bx, curr_y + 55), (10, 10, 10), np.random.choice([2, 4]))

    return img


def generate_all_assets():
    enhancer = LowVisionEnhancer(
        VisionEnhancementConfig(
            clahe_clip_limit=3.5,
            edge_enhancement_weight=0.55,
            glare_threshold=225,
            glare_suppression_factor=0.55,
        )
    )

    # -------------------------------------------------------------------------
    # 1. Contrast & Step Edge Enhancement (Macular Degeneration Simulation)
    # -------------------------------------------------------------------------
    stair_scene = synthesize_stair_curb_scene()
    enhanced_stairs, _ = enhancer.process_frame(stair_scene, mode="enhanced_contrast")
    split_stairs = np.hstack([stair_scene, enhanced_stairs])
    banner_stairs = add_header_banner(
        split_stairs,
        "ACCESSIBILITY PIPELINE 01: ADAPTIVE CONTRAST & EDGE SALIENCE",
        "Clinical Goal: Distinguish low-contrast steps, curbs & trip hazards for patients with Macular Degeneration (AMD).",
        "PATIENT VIEW (AMD Loss of Contrast)",
        "GOZVISION OPENCV 5 ENHANCED (CLAHE + Salient Cues)",
    )
    p1 = OUTPUT_DIR / "demo_contrast_split_screen.png"
    cv2.imwrite(str(p1), banner_stairs)
    print(f"[OK] Generated: {p1}")

    # -------------------------------------------------------------------------
    # 2. Glare Reduction & Specular Highlight Suppression (Cataract Simulation)
    # -------------------------------------------------------------------------
    glare_scene = synthesize_glare_hallway_scene()
    suppressed_glare, _ = enhancer.process_frame(glare_scene, mode="glare_suppression")
    split_glare = np.hstack([glare_scene, suppressed_glare])
    banner_glare = add_header_banner(
        split_glare,
        "ACCESSIBILITY PIPELINE 02: SPECULAR GLARE & BLOOM ATTENUATION",
        "Clinical Goal: Suppress blinding highlights from reflective floors and windows for Cataract & Photophobia patients.",
        "PATIENT VIEW (Cataract Glare Washout)",
        "GOZVISION OPENCV 5 SUPPRESSION (Specular Attenuation)",
    )
    p2 = OUTPUT_DIR / "demo_glare_split_screen.png"
    cv2.imwrite(str(p2), banner_glare)
    print(f"[OK] Generated: {p2}")

    # -------------------------------------------------------------------------
    # 3. Reading Region Detection (Prescription Medication OCR Routing)
    # -------------------------------------------------------------------------
    rx_scene = synthesize_prescription_scene()
    reading_boxes, metadata = enhancer.process_frame(rx_scene, mode="reading")
    split_reading = np.hstack([rx_scene, reading_boxes])
    banner_reading = add_header_banner(
        split_reading,
        "ACCESSIBILITY PIPELINE 03: MORPHOLOGICAL TEXT BOUNDING EXTRACTION",
        "Clinical Goal: Isolate dosage instructions & Rx labels for low-vision auto-magnification and TTS speech routing.",
        "RAW READING FIELD (Rx Pill Bottle)",
        f"GOZVISION DETECTED ({metadata.get('detected_text_regions', 0)} Active Text Regions)",
    )
    p3 = OUTPUT_DIR / "demo_reading_split_screen.png"
    cv2.imwrite(str(p3), banner_reading)
    print(f"[OK] Generated: {p3}")

    # -------------------------------------------------------------------------
    # 4. Master Triptych Infographic
    # -------------------------------------------------------------------------
    # Scale down each banner slightly to create an ultra-clean 3-row clinical poster
    target_w = 1280
    r1 = cv2.resize(banner_stairs, (target_w, int(banner_stairs.shape[0] * (target_w / banner_stairs.shape[1]))))
    r2 = cv2.resize(banner_glare, (target_w, int(banner_glare.shape[0] * (target_w / banner_glare.shape[1]))))
    r3 = cv2.resize(banner_reading, (target_w, int(banner_reading.shape[0] * (target_w / banner_reading.shape[1]))))

    triptych = np.vstack([r1, r2, r3])
    p4 = OUTPUT_DIR / "gozvision_opencv_triptych.png"
    cv2.imwrite(str(p4), triptych)
    print(f"[OK] Master Triptych Poster Generated: {p4}")


if __name__ == "__main__":
    generate_all_assets()
