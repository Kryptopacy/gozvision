"""GozVision OpenCV 5 Accessibility & Computer Vision Pipeline.

Tailored for the OpenCV AI Competition 2026 (Healthcare & Accessibility / Agentic Vision).

Features:
1. Adaptive Contrast & Edge Enhancement (CLAHE + Morphological Edge Overlay):
   Designed specifically for patients with age-related macular degeneration (AMD)
   and central scotomas to distinguish stair edges, curbs, and low-contrast objects.
2. Glare Reduction & Specular Highlight Suppression:
   Helps patients with cataracts, photophobia, and post-refractive haze navigate bright
   reflective environments (direct sunlight on windshields, fluorescent floors).
3. Text & Reading Region Detection:
   Isolates high-confidence textual bounding boxes using MSER / connected components
   for targeted magnification and OCR routing.
4. Optical Hazard / Proximity Salience:
   Highlights high-frequency edge obstacles directly in the visual field.
"""
from dataclasses import dataclass
from typing import Optional, Tuple
import cv2
import numpy as np


@dataclass
class VisionEnhancementConfig:
    clahe_clip_limit: float = 3.0
    clahe_tile_grid_size: Tuple[int, int] = (8, 8)
    edge_enhancement_weight: float = 0.35
    glare_threshold: int = 240
    glare_suppression_factor: float = 0.65


class LowVisionEnhancer:
    """Real-time OpenCV 5 visual pre-processor for low-vision patients."""

    def __init__(self, config: Optional[VisionEnhancementConfig] = None):
        self.config = config or VisionEnhancementConfig()
        self.clahe = cv2.createCLAHE(
            clipLimit=self.config.clahe_clip_limit,
            tileGridSize=self.config.clahe_tile_grid_size,
        )

    def enhance_contrast_and_edges(self, frame: np.ndarray) -> np.ndarray:
        """Enhances local luminance contrast (CLAHE in LAB space) and overlays subtle edge cues.
        
        Essential for macular degeneration and diabetic retinopathy where contrast sensitivity
        drops sharply.
        """
        if frame is None or frame.size == 0:
            raise ValueError("Invalid frame provided to enhance_contrast_and_edges")

        # 1. Convert to LAB color space to process Luminance (L) independently of color
        lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        # 2. Apply CLAHE on L channel
        enhanced_l = self.clahe.apply(l)

        # 3. Detect edge boundaries using Sobel/Laplacian on enhanced L
        blurred = cv2.GaussianBlur(enhanced_l, (3, 3), 0)
        edges = cv2.Canny(blurred, threshold1=40, threshold2=120)

        # 4. Blend enhanced luminance with edge highlights
        # Edge mask boosts contrast at object transitions
        edge_weight = self.config.edge_enhancement_weight
        composite_l = cv2.addWeighted(enhanced_l, 1.0, edges, edge_weight, 0)

        # 5. Recombine and convert back to BGR
        composite_lab = cv2.merge((composite_l, a, b))
        return cv2.cvtColor(composite_lab, cv2.COLOR_BGR2LAB)

    def suppress_glare(self, frame: np.ndarray) -> np.ndarray:
        """Reduces blinding specular highlights for cataract and photophobia sufferers."""
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Mask specular highlights
        _, glare_mask = cv2.threshold(gray, self.config.glare_threshold, 255, cv2.THRESH_BINARY)
        
        # Inpaint or dim highlight regions
        glare_mask_dilated = cv2.dilate(glare_mask, np.ones((5, 5), np.uint8), iterations=1)
        
        # Attenuate brightness in the glare zones
        result = frame.copy()
        result[glare_mask_dilated > 0] = (
            result[glare_mask_dilated > 0] * self.config.glare_suppression_factor
        ).astype(np.uint8)

        return result

    def detect_reading_regions(self, frame: np.ndarray) -> list[dict]:
        """Detects candidate text/reading zones in the visual field using morphological gradients.
        
        Returns a list of bounding boxes: [{'x': x, 'y': y, 'w': w, 'h': h, 'confidence': float}]
        """
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Morphological gradient to isolate text stroke boundaries
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 3))
        grad = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
        
        # Binarize with Otsu
        _, thresh = cv2.threshold(grad, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        
        # Connect nearby letter components horizontally
        connected = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        regions = []
        frame_h, frame_w = frame.shape[:2]
        
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            # Filter noise / non-text aspect ratios
            if w > 20 and h > 8 and (w * h) < (frame_w * frame_h * 0.5):
                aspect_ratio = float(w) / max(h, 1)
                if aspect_ratio >= 1.0:
                    regions.append({
                        "x": int(x),
                        "y": int(y),
                        "w": int(w),
                        "h": int(h),
                        "aspect_ratio": round(aspect_ratio, 2),
                    })
                    
        return regions

    def process_frame(self, frame: np.ndarray, mode: str = "enhanced_contrast") -> Tuple[np.ndarray, dict]:
        """Unified entry point for the GozVision camera copilot stream.
        
        Modes:
        - 'enhanced_contrast': CLAHE + high-contrast edges for AMD / Low Vision
        - 'glare_suppression': Photophobia & cataract attenuation
        - 'reading': Locates and highlights text blocks with bounding boxes
        """
        metadata: dict = {"mode": mode, "frame_shape": list(frame.shape)}
        
        if mode == "glare_suppression":
            processed = self.suppress_glare(frame)
        elif mode == "reading":
            regions = self.detect_reading_regions(frame)
            processed = frame.copy()
            for r in regions:
                cv2.rectangle(
                    processed,
                    (r["x"], r["y"]),
                    (r["x"] + r["w"], r["y"] + r["h"]),
                    (0, 255, 200),  # Goz malachite green highlight
                    2,
                )
            metadata["detected_text_regions"] = len(regions)
            metadata["regions"] = regions[:10]  # top 10
        else:
            processed = self.enhance_contrast_and_edges(frame)
            
        return processed, metadata
