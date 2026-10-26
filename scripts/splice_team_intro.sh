#!/usr/bin/env bash
# Splice a team intro clip ahead of the GozVision demo video.
#
# Usage:
#   bash scripts/splice_team_intro.sh <intro_clip.mov|mp4|webm> [out.mp4]
#
# The intro is normalized to the demo's format (1920x1080 30fps H.264 + AAC)
# and concatenated; the output defaults to gozvision_opencv_demo_final.mp4.
# Portrait sources get a blurred-fill background instead of black bars.
set -euo pipefail

INTRO="${1:?usage: splice_team_intro.sh <intro_clip> [out.mp4]}"
DEMO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && (pwd -W 2>/dev/null || pwd))/gozvision_opencv_demo.mp4"
OUT="${2:-$(dirname "$INTRO")/gozvision_opencv_demo_final.mp4}"
TMPDIR_T="$(mktemp -d)"
# Native ffmpeg.exe cannot read MSYS /tmp paths; convert to a Windows path.
command -v cygpath >/dev/null 2>&1 && TMPDIR_T="$(cygpath -m "$TMPDIR_T")"

ffmpeg -y -v error -i "$INTRO" -filter_complex "
  [0:v]split=2[bg][fg];
  [bg]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,boxblur=20:5[bgb];
  [fg]scale=-2:1080[fgs];
  [bgb][fgs]overlay=(W-w)/2:(H-h)/2,fps=30,format=yuv420p[v]" \
  -map "[v]" -map 0:a? -c:v libx264 -preset fast -crf 18 \
  -c:a aac -ar 48000 -ac 2 "$TMPDIR_T/intro.mp4"

ffmpeg -y -v error -i "$DEMO" \
  -vf "fps=30,format=yuv420p" -c:v libx264 -preset fast -crf 18 \
  -c:a aac -ar 48000 -ac 2 "$TMPDIR_T/demo.mp4"

printf "file '%s'\nfile '%s'\n" "$TMPDIR_T/intro.mp4" "$TMPDIR_T/demo.mp4" > "$TMPDIR_T/list.txt"

ffmpeg -y -v error -f concat -safe 0 -i "$TMPDIR_T/list.txt" -c copy "$OUT"

# One continuity pass: if a brief audio gap appears at the join, re-encode audio
if ! ffmpeg -v error -i "$OUT" -f null - 2>/dev/null; then
  ffmpeg -y -v error -i "$OUT" -c:v copy -c:a aac -ar 48000 -ac 2 "${OUT%.mp4}_fixed.mp4"
  mv "${OUT%.mp4}_fixed.mp4" "$OUT"
fi

echo "Final video: $OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s)"
rm -rf "$TMPDIR_T"
