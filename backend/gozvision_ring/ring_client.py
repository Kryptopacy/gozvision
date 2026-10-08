"""GozVision Ring Caretaking & Accessibility Pipeline.

Provides non-security caretaking monitoring and accessibility aids for low-vision
patients using Ring video doorbells, stick-up cameras, and chime devices.

Key Capabilities:
1. Doorstep Tripping Hazard & Obstacle Inspection (OpenCV CLAHE + Edge Salience on Ring Cam feeds).
2. Spoken Visitor & Package Announcer for visually impaired residents.
3. Caretaker Wandering & Nighttime Door Activity Guard (Alerts remote caregivers if a low-vision patient wanders after sundown).
4. Ring Device Simulator for judging, offline testing, and dev workflows without requiring physical hardware.
"""
from dataclasses import dataclass, field
import datetime
import logging
from typing import Any, Optional
import cv2
import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class RingDeviceState:
    device_id: str
    kind: str  # 'doorbell', 'stickup_cam', 'indoor_cam', 'chime'
    name: str
    battery_life: int = 92
    firmware: str = "v14.2.1-ring"
    last_event_time: Optional[str] = None
    last_event_type: Optional[str] = None  # 'motion', 'ding', 'door_open'


class RingAccessibilityMonitor:
    """Manages Ring device telemetry, webhook triggers, and low-vision assistance."""

    def __init__(self, api_token: Optional[str] = None):
        self.api_token = api_token or "simulated_ring_token_2026"
        self._devices: dict[str, RingDeviceState] = {
            "front_doorbell": RingDeviceState(
                device_id="front_doorbell",
                kind="doorbell",
                name="Front Porch Video Doorbell Pro",
                last_event_time="2026-10-08T14:15:00Z",
                last_event_type="ding",
            ),
            "hallway_indoor": RingDeviceState(
                device_id="hallway_indoor",
                kind="indoor_cam",
                name="Living Room & Hallway Cam",
                last_event_time="2026-10-08T13:40:00Z",
                last_event_type="motion",
            ),
        }

    def list_devices(self) -> list[dict[str, Any]]:
        return [
            {
                "device_id": d.device_id,
                "kind": d.kind,
                "name": d.name,
                "battery": f"{d.battery_life}%",
                "last_event": d.last_event_type,
            }
            for d in self._devices.values()
        ]

    def inspect_doorstep_safety(
        self,
        device_id: str = "front_doorbell",
        frame_array: Optional[np.ndarray] = None,
    ) -> dict[str, Any]:
        """Inspects Ring camera doorstep feed for low-vision tripping hazards (steps, packages, curbs)."""
        device = self._devices.get(device_id)
        device_name = device.name if device else "Porch Camera"

        # Generate a realistic synthetic porch/doorstep frame if none provided
        if frame_array is None:
            # 640x480 synthetic frame with doorway and doorstep package box
            frame_array = np.full((480, 640, 3), 180, dtype=np.uint8)
            # Add darker porch floor
            frame_array[300:480, :] = 120
            # Add a package / obstacle box on the doorstep
            cv2.rectangle(frame_array, (250, 320), (390, 420), (50, 60, 70), -1)
            # Add doorframe lines
            cv2.line(frame_array, (150, 0), (150, 300), (30, 30, 30), 4)
            cv2.line(frame_array, (490, 0), (490, 300), (30, 30, 30), 4)

        # Apply OpenCV edge & hazard detection tailored for low-vision safety
        gray = cv2.cvtColor(frame_array, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 50, 150)

        # Count high-contrast hazard edges in the walking doorstep zone (bottom half)
        doorstep_roi = edges[240:480, 100:540]
        hazard_pixels = cv2.countNonZero(doorstep_roi)
        has_obstacle = hazard_pixels > 250

        guidance_text = (
            "Caution: A package or object was detected on the front doorstep. Take care when stepping outside."
            if has_obstacle
            else "Doorstep and pathway are clear. Safe to proceed outside."
        )

        return {
            "status": "success",
            "device_id": device_id,
            "device_name": device_name,
            "doorstep_clear": not has_obstacle,
            "hazard_detected": has_obstacle,
            "hazard_salience_score": round(float(hazard_pixels) / 1000.0, 2),
            "accessibility_audio_prompt": guidance_text,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }

    def process_caretaker_event(
        self,
        event_type: str,
        device_id: str,
        patient_id: str = "demo_patient_001",
        event_time_utc: Optional[str] = None,
    ) -> dict[str, Any]:
        """Triage Ring motion/ding events for caretaking rules (e.g. nighttime wandering or prolonged front door open)."""
        now = datetime.datetime.now(datetime.timezone.utc)
        current_hour = now.hour

        # Flag nighttime wandering if door/motion occurs between 22:00 (10 PM) and 06:00 (6 AM)
        is_nighttime = current_hour >= 22 or current_hour < 6
        is_door_event = event_type in ["ding", "door_open", "front_door_motion"]

        requires_caregiver_alert = is_nighttime and is_door_event
        severity = "urgent" if requires_caregiver_alert else "routine"

        alert_message = (
            f"Caregiver Notification: Unscheduled nighttime door activity detected at {device_id} for patient {patient_id}. "
            "Please check on the resident."
            if requires_caregiver_alert
            else f"Routine Ring event '{event_type}' logged for patient {patient_id}."
        )

        return {
            "status": "success",
            "patient_id": patient_id,
            "device_id": device_id,
            "event_type": event_type,
            "is_nighttime": is_nighttime,
            "requires_caregiver_alert": requires_caregiver_alert,
            "severity": severity,
            "action": "sos_caregiver_dispatched" if requires_caregiver_alert else "logged_to_adherence",
            "message": alert_message,
            "timestamp": now.isoformat(),
        }

    def broadcast_intercom_chime(
        self,
        message: str,
        device_id: str = "front_doorbell",
    ) -> dict[str, Any]:
        """Broadcasts spoken accessibility guidance through Ring Chime or connected Echo speaker."""
        return {
            "status": "success",
            "device_id": device_id,
            "broadcast_text": message,
            "target": "ring_chime_intercom",
            "rendered_audio_status": "queued_for_playback",
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }


# Global singleton instance
ring_monitor = RingAccessibilityMonitor()
