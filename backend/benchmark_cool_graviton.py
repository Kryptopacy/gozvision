"""Measured performance & cost benchmark for the GozVision OpenCV 5 pipeline.

This script measures whatever machine it runs on and reports exactly that:
latency (ms), P95 (ms), throughput (FPS), which depth backend actually executed
(OpenCV 5 DNN ONNX vs. geometric fallback), and reference cloud economics
derived by applying AWS on-demand hourly rates to the measured throughput.

It contains NO cross-architecture comparison table. To compare Graviton (ARM64)
against x86, run this script on both instance types and merge the two JSON
files with ``python compare_benchmarks.py c7g_results.json c6i_results.json``.
Only measured numbers from real runs are ever emitted.

Usage:
    python benchmark_cool_graviton.py [--frames 100] [--resolution 640x480]
                                      [--label my_environment_name]
"""
import argparse
import json
import os
import platform
import sys
import time
from typing import Dict, Any, List
import cv2
import numpy as np

# Ensure root backend is in sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gozvision_vision.cool_pipeline import CoolGravitonPipeline


def generate_synthetic_stream(count: int, width: int = 640, height: int = 480) -> List[np.ndarray]:
    """Generates realistic synthetic video frames with varying contrast, glare, and text."""
    frames = []
    for i in range(count):
        img = np.full((height, width, 3), 160 + (i % 30), dtype=np.uint8)
        # Low-contrast floor with simulated curb / step
        img[int(height * 0.6):, :] = 110 + (i % 20)
        # Specular bright spot (glare)
        cx = int(width * 0.5 + 40 * np.sin(i / 10.0))
        cy = int(height * 0.3)
        cv2.circle(img, (cx, cy), 35, (255, 255, 255), -1)
        # Text label (medication box / clinic signage)
        cv2.putText(
            img,
            f"GOZVISION OPTICAL ACCESSIBILITY #{i:03d}",
            (40, 100),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 255, 255),
            2,
        )
        frames.append(img)
    return frames


def detect_simd_support() -> Dict[str, bool]:
    """Interrogate the OpenCV runtime for actual hardware SIMD support."""
def detect_simd_support() -> Dict[str, Any]:
    """Read the OpenCV build's SIMD baseline and dispatched code paths."""
    info = cv2.getBuildInformation()
    baseline, dispatched = "", ""
    for line in info.splitlines():
        stripped = line.strip()
        if stripped.startswith("Baseline:"):
            baseline = stripped.replace("Baseline:", "").strip()
        elif stripped.startswith("Dispatched code generation:"):
            dispatched = stripped.replace("Dispatched code generation:", "").strip()
    return {"opencv_baseline": baseline, "opencv_dispatched_code": dispatched}


def run_benchmark_suite(num_frames: int, res: tuple, label: str) -> Dict[str, Any]:
    w, h = res
    frames = generate_synthetic_stream(num_frames, width=w, height=h)
    pipeline = CoolGravitonPipeline()
    estimator = pipeline.enhancer.spatial_estimator

    simd = detect_simd_support()
    depth_backend = "opencv_dnn_onnx" if estimator.use_onnx else "geometric_fallback"

    results = {
        "measurement_environment": {
            "label": label,
            "host_os": platform.platform(),
            "cpu": platform.processor() or "unknown",
            "python_version": platform.python_version(),
            "opencv_version": cv2.__version__,
            "opencv_dnn_backend": "DNN_BACKEND_OPENCV",
            "architecture": pipeline.profile.architecture,
            "is_aws_graviton_arm": pipeline.profile.is_arm,
            "simd_detected": simd,
            "active_worker_threads": cv2.getNumThreads(),
            "depth_backend_used": depth_backend,
            "depth_model": estimator.model_name if estimator.use_onnx else None,
            "aws_instance_reference": {
                "instance_type": pipeline.profile.instance_type,
                "hourly_rate_usd": pipeline.profile.hourly_rate_usd,
                "note": (
                    "Reference on-demand hourly rate for the detected architecture, "
                    "applied to measured throughput for cost-per-million-frames only. "
                    "This run was executed on the machine named above."
                ),
            },
        },
        "benchmarks": {},
    }

    print("=" * 82)
    print("  GozVision: OpenCV 5 Pipeline Measured Benchmark")
    print("=" * 82)
    print(f"  Label                 : {label}")
    print(f"  Host                  : {platform.platform()}")
    print(f"  CPU                   : {platform.processor() or 'unknown'}")
    print(f"  Architecture          : {pipeline.profile.architecture}")
    print(f"  OpenCV Version        : {cv2.__version__}")
    print(f"  SIMD baseline         : {simd['opencv_baseline']}")
    print(f"  SIMD dispatched code  : {simd['opencv_dispatched_code']}")
    print(f"  Depth backend in use  : {depth_backend}"
          + (f" ({estimator.model_name})" if estimator.use_onnx else " (no ONNX model found)"))
    print(f"  Worker threads        : {cv2.getNumThreads()}")
    print(f"  Frame Resolution      : {w}x{h} ({num_frames} frames per mode)")
    print("-" * 82)

    modes = ["enhanced_contrast", "glare_suppression", "reading", "spatial_depth"]
    for mode in modes:
        # Warm-up pass (JIT/codepath warm) so steady-state numbers are measured
        pipeline.process_frame(frames[0], mode=mode)
        _, bench = pipeline.process_batch(frames, mode=mode)
        results["benchmarks"][mode] = {
            "resolution": f"{w}x{h}",
            "batch_size": bench.batch_size,
            "avg_latency_ms": bench.avg_latency_ms,
            "p95_latency_ms": bench.p95_latency_ms,
            "throughput_fps": bench.throughput_fps,
            "cost_per_million_frames_usd": bench.cost_per_million_frames_usd,
        }
        print(
            f"  Mode: {mode:<20} | Latency: {bench.avg_latency_ms:8.2f} ms | "
            f"P95: {bench.p95_latency_ms:8.2f} ms | FPS: {bench.throughput_fps:7.2f} | "
            f"Cost/1M: ${bench.cost_per_million_frames_usd:.4f}"
        )

    print("-" * 82)
    print("  Single-environment results only. For a measured Graviton-vs-x86")
    print("  comparison run this script on both instance types and merge with:")
    print("  python compare_benchmarks.py <graviton.json> <x86.json>")
    print("=" * 82)

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GozVision OpenCV 5 measured benchmark")
    parser.add_argument("--frames", type=int, default=60, help="Number of benchmark frames per mode")
    parser.add_argument("--resolution", default="640x480", help="Resolution WxH (e.g. 640x480, 1280x720)")
    parser.add_argument("--label", default=None, help="Environment label stored in the results (e.g. aws_c7g_xlarge)")
    parser.add_argument("--save-json", default="benchmark_results.json", help="Path to write JSON results")
    args = parser.parse_args()

    if args.label is None:
        args.label = "aws_graviton" if os.environ.get("AWS_EXECUTION_ENV") else f"local_{platform.system().lower()}"

    w_str, h_str = args.resolution.lower().split("x")
    data = run_benchmark_suite(num_frames=args.frames, res=(int(w_str), int(h_str)), label=args.label)

    if args.save_json:
        out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), args.save_json)
        with open(out_path, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Results saved to: {out_path}")
