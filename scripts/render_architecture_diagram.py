"""Render the GozVision OpenCV 5 + AWS architecture diagram (PNG).

Run:  py -3 scripts/render_architecture_diagram.py
Out:  docs/assets/gozvision_architecture.png
"""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import os

BG = "#0b1220"
PANEL = "#111b2e"
PANEL_EDGE = "#24365a"
TEXT = "#e8eefc"
MUTED = "#93a4c8"
ACCENT = "#4f8dff"   # opencv blue
GREEN = "#2ecf8a"    # COOL / graviton
ORANGE = "#f5a524"   # agentic
VIOLET = "#a78bfa"   # aws
RED = "#ff6b6b"

fig, ax = plt.subplots(figsize=(16, 9), dpi=150)
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(0, 160)
ax.set_ylim(-5, 90)
ax.axis("off")


def box(x, y, w, h, face=PANEL, edge=PANEL_EDGE, lw=1.2, radius=1.6, alpha=1.0):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.0,rounding_size={radius}",
        facecolor=face, edgecolor=edge, linewidth=lw, alpha=alpha, zorder=2,
    )
    ax.add_patch(p)
    return p


def text(x, y, s, size=10, color=TEXT, weight="normal", ha="center", va="center"):
    ax.text(x, y, s, fontsize=size, color=color, fontweight=weight,
            ha=ha, va=va, zorder=4)


def arrow(x1, y1, x2, y2, color=MUTED, lw=1.6, style="-|>", conn="arc3,rad=0.0"):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, color=color,
                        linewidth=lw, mutation_scale=14, zorder=3, connectionstyle=conn)
    ax.add_patch(a)


# ---------- Title ----------
text(80, 86.2, "GozVision  —  System Architecture", size=19, weight="bold")
text(80, 82.6, "OpenCV 5 perception  ·  Cloud-Optimized OpenCV on AWS Graviton  ·  Agentic perception-to-action",
     size=10.5, color=MUTED)

# ---------- Column 1: client surfaces ----------
box(2, 26, 26, 48)
text(15, 70.5, "CLIENT SURFACES", size=9.5, color=MUTED, weight="bold")
text(15, 64.5, "Patient Copilot", size=10.5, weight="bold")
text(15, 61.3, "Flutter PWA (low-vision UI)", size=8.2, color=MUTED)
text(15, 55.5, "Smart Glasses HUD", size=10.5, weight="bold")
text(15, 52.3, "USB camera + IMU telemetry", size=8.2, color=MUTED)
text(15, 46.5, "Goz Clinic Suite", size=10.5, weight="bold")
text(15, 43.3, "FHIR R4 hub, scribe, RTM billing", size=8.2, color=MUTED)
text(15, 36.0, "Video 640x480 @ up to 30 fps", size=8.4, color=ACCENT)
text(15, 32.8, "carries walking-corridor frames", size=8.2, color=MUTED)

# ---------- Column 2: OpenCV 5 pipeline ----------
box(32, 12, 44, 62, edge=ACCENT, lw=1.8)
text(54, 70.6, "OPENCV 5 EDGE PIPELINE", size=9.5, color=ACCENT, weight="bold")
text(54, 67.9, "backend/gozvision_vision", size=7.6, color=MUTED)

box(34.5, 46, 39, 20, face="#0e1930", edge=PANEL_EDGE)
text(54, 62.6, "LOOP A - SYNCHRONOUS DISPLAY", size=8.8, color=ACCENT, weight="bold")
text(54, 58.9, "CIE-LAB adaptive CLAHE (luminance only)", size=8.6)
text(54, 55.9, "Telea fast-marching glare inpainting  cv::inpaint", size=8.6)
text(54, 52.9, "DAVE condition masks from FHIR ICD-10", size=8.6)
text(54, 49.9, "Morphological reading-zone text isolation", size=8.6)

box(34.5, 15, 39, 28, face="#0e1930", edge=PANEL_EDGE)
text(54, 39.6, "LOOP B - ASYNC 3D GEOMETRY", size=8.8, color=ACCENT, weight="bold")
text(54, 35.9, "cv2.dnn ONNX monocular depth disparity", size=8.6)
text(54, 32.9, "StereoSGBM triangulation  Z = fx*B/d", size=8.6)
text(54, 29.9, "RANSAC ground-homography parallax veto", size=8.6)
text(54, 26.9, "Farneback flow scale calibration", size=8.6)
text(54, 23.9, "Vertical disparity gradient  dD/dy  drop test", size=8.6)
text(54, 20.9, "TemporalHazardCoherenceTracker (5-frame)", size=8.6)
text(54, 16.9, "outputs: vertical_drop vs coplanar_clear + cm", size=8.4, color=GREEN)

# ---------- Column 3: COOL + Agent ----------
box(80, 40, 36, 34, edge=GREEN, lw=1.8)
text(98, 70.6, "COOL ON AWS GRAVITON", size=9.5, color=GREEN, weight="bold")
text(98, 67.9, "Cloud-Optimized OpenCV Library", size=7.6, color=MUTED)
text(98, 64.2, "AWS Graviton3 / ARM64  c7g-class", size=9.2, weight="bold")
text(98, 61.0, "Universal Intrinsics 2.0 vectorization", size=8.6)
text(98, 58.0, "ECS Fargate ARM64 task (linux/arm64)", size=8.6)
text(98, 55.0, "OpenCV 5.0.0 DNN_BACKEND_OPENCV", size=8.6)
text(98, 52.0, "measured per-mode FPS + $/1M frames", size=8.6)
text(98, 48.6, "benchmark_cool_graviton.py", size=8.4, color=GREEN)
text(98, 45.8, "compare_benchmarks.py  (measured only)", size=8.4, color=GREEN)
text(98, 42.8, "dev amd64 + Graviton hybrid evidence", size=8.2, color=MUTED)

box(80, 2, 36, 34, edge=ORANGE, lw=1.8)
text(98, 32.5, "AGENTIC VISION ORCHESTRATOR", size=9.5, color=ORANGE, weight="bold")
text(98, 28.6, "perception -> plan -> act -> escalate", size=9.0, weight="bold")
text(98, 25.3, "hazard > 10cm  ->  voice + haptic warning", size=8.6)
text(98, 22.3, "stumble IMU  ->  emergency SOS dispatch", size=8.6)
text(98, 19.3, "OCR med label  ->  EHR conflict guardrail", size=8.6)
text(98, 16.3, "visual metrics  ->  camera parameter tuning", size=8.6)
text(98, 12.6, "MCP server exposes cv tools  (streamable-http)", size=8.4, color=ORANGE)
text(98, 9.6, "10 s cancel window + human sign-off", size=8.2, color=MUTED)

# ---------- Column 4: AWS ----------
box(120, 18, 38, 56, edge=VIOLET, lw=1.8)
text(139, 70.5, "AWS FOUNDATION", size=9.5, color=VIOLET, weight="bold")
rows = [
    ("CloudFront TLS 1.3 edge", "d7icpdzxenshi.cloudfront.net"),
    ("ECS Fargate cluster (ARM64)", "gozvision-graviton task"),
    ("Amplify Hosting", "patient + clinic Flutter web"),
    ("CloudFormation IaC", "infra/gozvision-stack.yaml"),
    ("IAM least-privilege roles", "ecs execution role"),
]
y = 65.0
for name, sub in rows:
    text(139, y, name, size=9.2, weight="bold")
    text(139, y - 3.0, sub, size=8.0, color=MUTED)
    y -= 9.0
text(139, 21.5, "multi-tenant data: Supabase Postgres + RLS", size=8.2, color=MUTED)

# ---------- Arrows ----------
arrow(28.5, 50, 31.5, 50, color=ACCENT, lw=2.0)
text(30, 52.2, "video", size=7.5, color=MUTED)
arrow(76.5, 57, 79.5, 57, color=GREEN, lw=2.0)
arrow(76.5, 26, 79.5, 26, color=ORANGE, lw=2.0)
arrow(116.5, 57, 119.5, 57, color=VIOLET, lw=2.0)
arrow(116.5, 26, 119.5, 26, color=VIOLET, lw=2.0)
arrow(88, 39.5, 88, 36.5, color=RED, lw=1.8)
text(97, 38.1, "hazard telemetry", size=7.2, color=MUTED)

# ---------- Footer ----------
text(80, -2.2, "Evaluation evidence: backend/evaluation  ·  69 real frames, 0 synthetic  ·  failure cases documented in docs/EVALUATION_REPORT.md",
     size=8.6, color=MUTED)

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "assets")
out_path = os.path.abspath(os.path.join(out_dir, "gozvision_architecture.png"))
fig.savefig(out_path, facecolor=BG, bbox_inches="tight")
print(f"Saved {out_path}")
