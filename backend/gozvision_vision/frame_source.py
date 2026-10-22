"""GozVision Real Frame Source.

Provides real (non-synthetic) image and video input to the GozVision vision and
agentic pipelines, with strict provenance tracking.

Why this module exists
----------------------
The OpenCV AI Competition 2026 requires that the OpenCV 5 workload perform
"substantive image or video analysis". Evaluation and the Agentic Vision Award
require that visual results drive downstream decisions. A pipeline driven only by
`np.full(...)` placeholder frames cannot demonstrate either property, and any
benchmark run against such frames measures the cost of an array allocation
rather than the cost of computer vision.

Every frame returned by this module carries a `FrameProvenance` record stating
exactly where the pixels came from (file path, URI, camera index, or video
frame index) plus a content hash. That record is attached to the agentic trace
so a judge can verify that the visual evidence driving an action was real.

Supported sources
-----------------
- `ImageFileSource`  : still images on disk (JPEG/PNG/...)
- `VideoFileSource`  : frame-by-frame decode of a video container
- `WebcamSource`     : live capture from a local camera index
- `UriSource`        : download a remote image once and cache it locally

Design notes
------------
- Decoding is done with OpenCV (`cv2.VideoCapture`) so the same code path is
  used for stills and video, which keeps the benchmark honest.
- Sources are lazy: a video file is not decoded until the first frame is
  requested, and `WebcamSource` will not open a device until requested.
- Failures raise `FrameSourceError` with an actionable message rather than
  silently degrading to a synthetic frame. Silent fallback to a placeholder is
  exactly the failure mode this module exists to prevent.
"""
from __future__ import annotations

import hashlib
import os
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator, List, Optional, Sequence

import cv2
import numpy as np

__all__ = [
    "FrameProvenance",
    "FrameSourceError",
    "FrameSource",
    "ImageFileSource",
    "VideoFileSource",
    "WebcamSource",
    "UriSource",
    "build_source",
    "iter_dataset",
]


class FrameSourceError(RuntimeError):
    """Raised when a real frame cannot be produced from the requested source."""


@dataclass
class FrameProvenance:
    """Auditable record of where a frame's pixels came from.

    `source_type` is one of: 'image_file', 'video_file', 'webcam', 'uri'.
    `content_sha256` is the SHA-256 of the raw encoded bytes for file/uri
    sources, or of the decoded pixel buffer for live sources. It lets a judge
    confirm the exact frame that produced a given agentic decision.
    """

    source_type: str
    source_ref: str
    frame_index: int = 0
    total_frames: Optional[int] = None
    timestamp_utc: str = ""
    width: int = 0
    height: int = 0
    content_sha256: str = ""
    is_synthetic: bool = False
    extra: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "source_type": self.source_type,
            "source_ref": self.source_ref,
            "frame_index": self.frame_index,
            "total_frames": self.total_frames,
            "timestamp_utc": self.timestamp_utc,
            "width": self.width,
            "height": self.height,
            "content_sha256": self.content_sha256,
            "is_synthetic": self.is_synthetic,
            **({"extra": self.extra} if self.extra else {}),
        }


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_array(arr: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(arr).tobytes()).hexdigest()


def _utc_now() -> str:
    import datetime

    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class FrameSource:
    """Base class for real frame producers.

    Subclasses implement `read()` which returns a single `(frame, provenance)`
    tuple, and `reset()` which rewinds to the beginning of the source.
    """

    source_type: str = "unknown"

    def read(self) -> tuple[np.ndarray, FrameProvenance]:
        raise NotImplementedError

    def reset(self) -> None:
        """Rewind the source to its first frame. Default: no-op."""

    def close(self) -> None:
        """Release any underlying device handles. Default: no-op."""

    def __enter__(self) -> "FrameSource":
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    def __iter__(self) -> Iterator[tuple[np.ndarray, FrameProvenance]]:
        """Iterate all frames from the source."""
        while True:
            try:
                yield self.read()
            except StopIteration:
                return

    def read_many(self, count: int) -> List[tuple[np.ndarray, FrameProvenance]]:
        """Read up to `count` frames. Raises if no frame could be produced."""
        out: List[tuple[np.ndarray, FrameProvenance]] = []
        for _ in range(count):
            try:
                out.append(self.read())
            except StopIteration:
                break
        if not out:
            raise FrameSourceError(
                f"Source {self!r} produced no frames. The requested media may be "
                f"missing, corrupt, or use an unsupported codec."
            )
        return out


class ImageFileSource(FrameSource):
    """A single still image on disk, read through OpenCV's imread."""

    source_type = "image_file"

    def __init__(self, path: str | os.PathLike):
        self.path = Path(path)
        if not self.path.exists():
            raise FrameSourceError(f"Image file not found: {self.path}")
        self._raw = self.path.read_bytes()
        self._sha = _sha256_bytes(self._raw)
        self._frame: Optional[np.ndarray] = None
        self._index = 0

    def _load(self) -> np.ndarray:
        if self._frame is None:
            frame = cv2.imread(str(self.path), cv2.IMREAD_COLOR)
            if frame is None:
                raise FrameSourceError(
                    f"OpenCV could not decode image: {self.path}. "
                    f"The file may be corrupt or not a supported image format."
                )
            self._frame = frame
        return self._frame

    def read(self) -> tuple[np.ndarray, FrameProvenance]:
        frame = self._load()
        h, w = frame.shape[:2]
        prov = FrameProvenance(
            source_type=self.source_type,
            source_ref=str(self.path),
            frame_index=self._index,
            total_frames=1,
            timestamp_utc=_utc_now(),
            width=w,
            height=h,
            content_sha256=self._sha,
            is_synthetic=False,
            extra={"decoder": "cv2.imread", "format": self.path.suffix.lstrip(".")},
        )
        self._index += 1
        return frame.copy(), prov

    def reset(self) -> None:
        self._index = 0


class VideoFileSource(FrameSource):
    """Frame-by-frame decode of a real video file via `cv2.VideoCapture`."""

    source_type = "video_file"

    def __init__(self, path: str | os.PathLike, max_frames: Optional[int] = None):
        self.path = Path(path)
        if not self.path.exists():
            raise FrameSourceError(f"Video file not found: {self.path}")
        self.max_frames = max_frames
        self._cap: Optional[cv2.VideoCapture] = None
        self._index = 0
        self._total: Optional[int] = None
        self._sha = _sha256_bytes(self.path.read_bytes())

    def _open(self) -> cv2.VideoCapture:
        if self._cap is None:
            cap = cv2.VideoCapture(str(self.path))
            if not cap.isOpened():
                raise FrameSourceError(
                    f"OpenCV could not open video: {self.path}. The codec may be "
                    f"unsupported by the local OpenCV build (e.g. H.265/HEVC)."
                )
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            self._total = total if total > 0 else None
            self._cap = cap
        return self._cap

    def read(self) -> tuple[np.ndarray, FrameProvenance]:
        cap = self._open()
        ok, frame = cap.read()
        if not ok or frame is None:
            self.close()
            raise StopIteration(f"End of video: {self.path}")
        h, w = frame.shape[:2]
        prov = FrameProvenance(
            source_type=self.source_type,
            source_ref=str(self.path),
            frame_index=self._index,
            total_frames=self._total,
            timestamp_utc=_utc_now(),
            width=w,
            height=h,
            content_sha256=_sha256_array(frame),
            is_synthetic=False,
            extra={
                "decoder": "cv2.VideoCapture",
                "fps": round(cap.get(cv2.CAP_PROP_FPS), 3),
                "container": self.path.suffix.lstrip("."),
            },
        )
        self._index += 1
        return frame, prov

    def reset(self) -> None:
        self.close()
        self._index = 0

    def close(self) -> None:
        if self._cap is not None:
            self._cap.release()
            self._cap = None


class WebcamSource(FrameSource):
    """Live capture from a local camera index."""

    source_type = "webcam"

    def __init__(self, index: int = 0, width: Optional[int] = None, height: Optional[int] = None):
        self.index = index
        self.width = width
        self.height = height
        self._cap: Optional[cv2.VideoCapture] = None
        self._index = 0

    def _open(self) -> cv2.VideoCapture:
        if self._cap is None:
            cap = cv2.VideoCapture(self.index)
            if not cap.isOpened():
                raise FrameSourceError(
                    f"Could not open camera index {self.index}. No camera is attached "
                    f"or the device is in use by another application."
                )
            if self.width:
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
            if self.height:
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
            self._cap = cap
        return self._cap

    def read(self) -> tuple[np.ndarray, FrameProvenance]:
        cap = self._open()
        ok, frame = cap.read()
        if not ok or frame is None:
            raise FrameSourceError(
                f"Camera {self.index} returned no frame. The device may have been "
                f"disconnected."
            )
        h, w = frame.shape[:2]
        prov = FrameProvenance(
            source_type=self.source_type,
            source_ref=f"camera://{self.index}",
            frame_index=self._index,
            total_frames=None,
            timestamp_utc=_utc_now(),
            width=w,
            height=h,
            content_sha256=_sha256_array(frame),
            is_synthetic=False,
            extra={"decoder": "cv2.VideoCapture(live)"},
        )
        self._index += 1
        return frame, prov

    def reset(self) -> None:
        self._index = 0

    def close(self) -> None:
        if self._cap is not None:
            self._cap.release()
            self._cap = None


class UriSource(FrameSource):
    """Download a remote image once, cache it, then serve it like a local file.

    Used to pull reference imagery for the evaluation set. The download is
    performed with `urllib` (stdlib) so the module has no extra dependency.
    """

    source_type = "uri"

    def __init__(self, url: str, cache_dir: str | os.PathLike, timeout: int = 60):
        self.url = url
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.timeout = timeout
        self._path: Optional[Path] = None
        self._inner: Optional[ImageFileSource] = None

    def _resolve(self) -> ImageFileSource:
        if self._inner is not None:
            return self._inner
        name = hashlib.sha256(self.url.encode("utf-8")).hexdigest()[:16]
        suffix = os.path.splitext(self.url)[1] or ".jpg"
        dest = self.cache_dir / f"{name}{suffix}"
        if not dest.exists():
            try:
                with urllib.request.urlopen(self.url, timeout=self.timeout) as resp:
                    data = resp.read()
            except Exception as exc:  # noqa: BLE001 - surfaced to caller verbatim
                raise FrameSourceError(f"Failed to download {self.url}: {exc}") from exc
            dest.write_bytes(data)
        self._path = dest
        self._inner = ImageFileSource(dest)
        return self._inner

    def read(self) -> tuple[np.ndarray, FrameProvenance]:
        inner = self._resolve()
        frame, prov = inner.read()
        prov.source_type = self.source_type
        prov.source_ref = self.url
        prov.extra = {**prov.extra, "cached_path": str(self._path)}
        return frame, prov

    def reset(self) -> None:
        if self._inner is not None:
            self._inner.reset()


def build_source(spec: str, cache_dir: str | os.PathLike = "backend/evaluation/dataset/raw") -> FrameSource:
    """Build a frame source from a URI-like spec string.

    Recognised forms:
      - `image:<path>`      still image on disk
      - `video:<path>`      video file on disk
      - `camera:<index>`    live camera (default index 0)
      - `http(s)://...`     remote image, downloaded and cached
      - `<path>`            inferred from the file extension
    """
    if spec.startswith("image:"):
        return ImageFileSource(spec[len("image:"):])
    if spec.startswith("video:"):
        return VideoFileSource(spec[len("video:"):])
    if spec.startswith("camera:"):
        idx = spec[len("camera:"):].strip()
        return WebcamSource(int(idx) if idx else 0)
    if spec.startswith("http://") or spec.startswith("https://"):
        return UriSource(spec, cache_dir)
    p = Path(spec)
    if not p.exists():
        raise FrameSourceError(f"Frame source not found: {spec}")
    if p.suffix.lower() in {".mp4", ".avi", ".mov", ".mkv", ".webm", ".m4v"}:
        return VideoFileSource(p)
    return ImageFileSource(p)


def iter_dataset(specs: Sequence[str], frames_per_source: int = 1) -> Iterator[tuple[np.ndarray, FrameProvenance]]:
    """Yield real frames across a list of source specs.

    Each spec contributes up to `frames_per_source` frames. Sources that fail
    are skipped with a warning rather than aborting the whole run, so a single
    unavailable video does not destroy an evaluation run. Every provenance
    record always marks `is_synthetic` as False.
    """
    import logging

    logger = logging.getLogger(__name__)
    for spec in specs:
        try:
            source = build_source(spec)
        except FrameSourceError as exc:
            logger.warning("Skipping unavailable source %s: %s", spec, exc)
            continue
        try:
            got = 0
            for frame, prov in source:
                yield frame, prov
                got += 1
                if got >= frames_per_source:
                    break
        except (FrameSourceError, StopIteration) as exc:
            logger.warning("Source %s produced no usable frames: %s", spec, exc)
        finally:
            source.close()


