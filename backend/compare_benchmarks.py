"""Merge two measured benchmark JSONs into an honest cross-architecture comparison.

Usage:
    python compare_benchmarks.py <results_a.json> <results_b.json>

Both inputs must come from ``benchmark_cool_graviton.py`` runs on the machines
you are comparing (e.g. a c7g.xlarge Graviton3 run and a c6i.xlarge x86 run).
Every ratio emitted below is computed from the two files' measured numbers.
"""
import json
import sys
from typing import Dict, Any


def load(path: str) -> Dict[str, Any]:
    with open(path) as f:
        data = json.load(f)
    if "benchmarks" not in data or "measurement_environment" not in data:
        raise SystemExit(f"{path} is not a benchmark_cool_graviton.py output file")
    return data


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    a, b = load(sys.argv[1]), load(sys.argv[2])
    env_a, env_b = a["measurement_environment"], b["measurement_environment"]

    print("=" * 84)
    print("  Measured cross-architecture comparison (computed only from the two input files)")
    print("=" * 84)
    print(f"  A: {env_a['label']:<28} arch={env_a['architecture']:<10} opencv={env_a['opencv_version']}")
    print(f"     depth_backend={env_a['depth_backend_used']}  model={env_a['depth_model']}")
    print(f"  B: {env_b['label']:<28} arch={env_b['architecture']:<10} opencv={env_b['opencv_version']}")
    print(f"     depth_backend={env_b['depth_backend_used']}  model={env_b['depth_model']}")
    print("-" * 84)

    if env_a["depth_backend_used"] != env_b["depth_backend_used"]:
        print("  WARNING: the two runs used different depth backends; the spatial_depth")
        print("  comparison below is not measuring the same workload on both sides.")
        print("-" * 84)

    modes = sorted(set(a["benchmarks"]) & set(b["benchmarks"]))
    summary: Dict[str, Dict[str, Any]] = {}
    print(f"  {'mode':<20} {'A FPS':>9} {'B FPS':>9} {'A→B x':>7} {'A ms':>9} {'B ms':>9} {'lat Δ%':>8}")
    for mode in modes:
        ba, bb = a["benchmarks"][mode], b["benchmarks"][mode]
        speedup = bb["throughput_fps"] / ba["throughput_fps"] if ba["throughput_fps"] else float("inf")
        lat_delta = (bb["avg_latency_ms"] - ba["avg_latency_ms"]) / ba["avg_latency_ms"] * 100.0
        summary[mode] = {
            "a_throughput_fps": ba["throughput_fps"],
            "b_throughput_fps": bb["throughput_fps"],
            "throughput_ratio_b_over_a": round(speedup, 4),
            "a_avg_latency_ms": ba["avg_latency_ms"],
            "b_avg_latency_ms": bb["avg_latency_ms"],
            "latency_change_pct_b_vs_a": round(lat_delta, 2),
        }
        print(
            f"  {mode:<20} {ba['throughput_fps']:>9.2f} {bb['throughput_fps']:>9.2f} "
            f"{speedup:>7.2f} {ba['avg_latency_ms']:>9.2f} {bb['avg_latency_ms']:>9.2f} {lat_delta:>7.1f}%"
        )

    # Reference cloud economics: hourly rates applied to each side's measured FPS
    rate_a = env_a["aws_instance_reference"]["hourly_rate_usd"]
    rate_b = env_b["aws_instance_reference"]["hourly_rate_usd"]
    print("-" * 84)
    print(f"  Instance reference: A ${rate_a}/hr, B ${rate_b}/hr")
    for mode in modes:
        ba, bb = a["benchmarks"][mode], b["benchmarks"][mode]
        cost_ratio = (bb["cost_per_million_frames_usd"] / ba["cost_per_million_frames_usd"]) if ba["cost_per_million_frames_usd"] else 0
        print(
            f"  {mode:<20} cost/1M frames: A ${ba['cost_per_million_frames_usd']:.4f}, "
            f"B ${bb['cost_per_million_frames_usd']:.4f} (B/A = {cost_ratio:.2f})"
        )
    print("=" * 84)
    print("  Note: identical resolutions, frame counts, and depth backends are required")
    print("  for a fair comparison. All numbers above are measured, none are projected.")
    print("=" * 84)


if __name__ == "__main__":
    main()
