"""Build contact sheets of the evaluation images for visual ground-truth labeling."""
import glob
import math
import os
import sys

import cv2
import numpy as np

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dataset", "raw")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dataset")


def sheet(paths, out_path, cols=4, cell=320):
    rows = math.ceil(len(paths) / cols)
    canvas = np.full((rows * cell, cols * cell, 3), 255, np.uint8)
    for i, p in enumerate(paths):
        img = cv2.imread(p)
        if img is None:
            continue
        h, w = img.shape[:2]
        s = cell / max(h, w)
        img = cv2.resize(img, (int(w * s), int(h * s)))
        r, c = divmod(i, cols)
        y = r * cell + (cell - img.shape[0]) // 2
        x = c * cell + (cell - img.shape[1]) // 2
        canvas[y:y + img.shape[0], x:x + img.shape[1]] = img
        cv2.rectangle(canvas, (c * cell, r * cell), ((c + 1) * cell - 1, (r + 1) * cell - 1), (0, 0, 200), 2)
        label = os.path.basename(p).replace(".jpg", "")
        cv2.putText(canvas, label, (c * cell + 5, r * cell + 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 220), 2)
    cv2.imwrite(out_path, canvas)
    print(f"wrote {out_path} ({len(paths)} images, {cols}x{rows})")


if __name__ == "__main__":
    pattern = sys.argv[1] if len(sys.argv) > 1 else "commons_*.jpg"
    out = sys.argv[2] if len(sys.argv) > 2 else "contact_sheet.jpg"
    paths = sorted(glob.glob(os.path.join(RAW, pattern)))
    per = 12
    for k in range(0, len(paths), per):
        chunk = paths[k:k + per]
        name = out.replace(".jpg", f"_{k // per}.jpg")
        sheet(chunk, os.path.join(OUT, name))
