import os
import time
from pathlib import Path

import cv2
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright

BASE_URL = os.environ.get("GOZ_BASE_URL", "http://localhost:8085").rstrip("/")
REPORTS_DIR = Path(__file__).resolve().parent.parent / "playwright_reports"
REPORTS_DIR.mkdir(exist_ok=True)

results = []


def record(name, passed, details=""):
    status = "PASS" if passed else "FAIL"
    results.append({"name": name, "status": status, "details": details})
    symbol = "✓" if passed else "✗"
    print(f"[{symbol}] {name}: {status} - {details}", flush=True)


def screenshot_changed(before_path, after_path, minimum_mean_delta=3.0):
    before = cv2.imread(str(before_path))
    after = cv2.imread(str(after_path))
    if before is None or after is None or before.shape != after.shape:
        return False, 0.0
    delta = float(cv2.absdiff(before, after).mean())
    return delta >= minimum_mean_delta, delta


def wait_until(predicate, timeout_seconds, interval=0.25):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(interval)
    return False


def test_marketing_website(page):
    print("\n=== 1. PUBLIC WEBSITE ===", flush=True)
    page.goto(BASE_URL, wait_until="networkidle")

    title = page.title()
    record("Website title", "GozVision" in title, repr(title))

    favicon = page.locator('link[rel="icon"]').first
    href = favicon.get_attribute("href") if favicon.count() else ""
    record("Favicon", "favicon" in href, f"href={href!r}")

    nav_logo = page.locator("img.brand-logo-img, img[src*='gozvision_lens']").first
    record("Navbar logo", nav_logo.count() == 1 and nav_logo.is_visible(), "visible branded mark")

    controls = page.locator(
        "button:has-text('Cataract'), button:has-text('Glaucoma'), "
        "button:has-text('Walking & Obstacles'), [data-sim], .sim-tab"
    )
    if controls.count():
        controls.first.click()
        record("Vision simulator interaction", True, f"clicked one of {controls.count()} controls")
    else:
        record("Vision simulator interaction", False, "no simulator control found")

    ctas = page.locator(
        "a:has-text('Book Practice Audit'), button:has-text('Audit'), "
        "a:has-text('Demo'), a:has-text('Clinic Suite')"
    )
    record("Conversion CTAs", ctas.count() > 0, f"count={ctas.count()}")

    desktop = REPORTS_DIR / "01_website_desktop_full.png"
    page.screenshot(path=str(desktop), full_page=True)
    record("Desktop render", desktop.exists(), str(desktop))

    page.set_viewport_size({"width": 390, "height": 844})
    page.reload(wait_until="networkidle")
    mobile = REPORTS_DIR / "02_website_mobile_viewport.png"
    page.screenshot(path=str(mobile), full_page=True)
    record("Mobile render", mobile.exists(), str(mobile))
    page.set_viewport_size({"width": 1440, "height": 900})


def test_clinic_suite(page):
    print("\n=== 2. CLINIC SUITE ===", flush=True)
    auth_statuses = []

    def capture_auth(response):
        if "/auth/v1/token" in response.url:
            auth_statuses.append(response.status)

    page.on("response", capture_auth)
    page.goto(f"{BASE_URL}/clinic/", wait_until="networkidle")
    try:
        page.wait_for_selector("flutter-view, flt-glass-pane, canvas", timeout=30000)
        record("Clinic engine mount", True, "Flutter CanvasKit mounted")
    except PlaywrightTimeoutError as error:
        record("Clinic engine mount", False, str(error))
        page.remove_listener("response", capture_auth)
        return

    time.sleep(3)
    before = REPORTS_DIR / "03_clinic_login_screen.png"
    page.screenshot(path=str(before))

    # CanvasKit controls are not in the browser DOM until assistive semantics
    # is activated. Coordinates are anchored to the fixed 1440x900 audit
    # viewport; outcomes below are proved by auth response + visual transition.
    page.mouse.click(720, 596)  # Fill Demo Credentials
    time.sleep(1)
    page.mouse.click(720, 515)  # Sign in to Practice

    auth_ok = wait_until(lambda: any(200 <= status < 300 for status in auth_statuses), 20)
    time.sleep(5)
    after = REPORTS_DIR / "04_clinic_shell_live.png"
    page.screenshot(path=str(after))
    changed, delta = screenshot_changed(before, after, minimum_mean_delta=8.0)

    record("Clinic demo authentication", auth_ok, f"token statuses={auth_statuses or 'none'}")
    record("Clinic dashboard transition", auth_ok and changed, f"mean pixel delta={delta:.2f}; {after}")
    page.remove_listener("response", capture_auth)


def test_patient_copilot(page):
    print("\n=== 3. PATIENT COPILOT ===", flush=True)
    console_messages = []
    sos_statuses = []

    def capture_console(message):
        console_messages.append(message.text)

    def capture_response(response):
        if "/rest/v1/sos_alerts" in response.url:
            sos_statuses.append(response.status)

    page.on("console", capture_console)
    page.on("response", capture_response)
    page.goto(f"{BASE_URL}/patient/", wait_until="networkidle")
    try:
        page.wait_for_selector("flutter-view, flt-glass-pane, canvas", timeout=30000)
        record("Patient engine mount", True, "Flutter CanvasKit mounted")
    except PlaywrightTimeoutError as error:
        record("Patient engine mount", False, str(error))
        page.remove_listener("console", capture_console)
        page.remove_listener("response", capture_response)
        return

    live_ready = wait_until(
        lambda: any("GeminiLive setup complete" in message for message in console_messages),
        45,
    )
    reconnect_failures = [
        message for message in console_messages
        if "Method doesn't allow unregistered callers" in message
    ]
    copilot = REPORTS_DIR / "05_patient_copilot_orb.png"
    page.screenshot(path=str(copilot))
    record(
        "Gemini Live authenticated",
        live_ready and not reconnect_failures,
        "setupComplete observed" if live_ready else "setupComplete not observed",
    )

    # Verify the Doorstep quick action produces a real visual state change.
    before_door = REPORTS_DIR / "06a_patient_before_doorstep.png"
    page.screenshot(path=str(before_door))
    page.mouse.click(896, 648)
    time.sleep(2)
    after_door = REPORTS_DIR / "06_patient_doorstep_action.png"
    page.screenshot(path=str(after_door))
    changed, delta = screenshot_changed(before_door, after_door, minimum_mean_delta=2.0)
    record("Patient Doorstep action", changed, f"mean pixel delta={delta:.2f}; {after_door}")

    # Reset the modal with Escape, then verify the actual SOS write response.
    page.keyboard.press("Escape")
    time.sleep(1)
    page.mouse.click(1248, 648)
    sos_ok = wait_until(lambda: any(200 <= status < 300 for status in sos_statuses), 15)
    emergency = REPORTS_DIR / "07_emergency_clicked.png"
    page.screenshot(path=str(emergency))
    record("Patient Emergency SOS", sos_ok, f"PostgREST statuses={sos_statuses or 'none'}; {emergency}")

    page.remove_listener("console", capture_console)
    page.remove_listener("response", capture_response)


def main():
    print(f"Starting GozVision E2E audit against {BASE_URL}", flush=True)
    page_errors = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()
        page.on("pageerror", lambda error: page_errors.append(str(error)))

        for test in (test_marketing_website, test_clinic_suite, test_patient_copilot):
            try:
                test(page)
            except Exception as error:
                record(f"{test.__name__} execution", False, repr(error))
        browser.close()

    passed = sum(result["status"] == "PASS" for result in results)
    failed = sum(result["status"] == "FAIL" for result in results)
    print("\n=== AUDIT SUMMARY ===", flush=True)
    print(f"Passed: {passed}; Failed: {failed}; Page errors: {len(page_errors)}", flush=True)
    for error in page_errors[:5]:
        print(f"  PageError: {error}", flush=True)
    raise SystemExit(1 if failed or page_errors else 0)


if __name__ == "__main__":
    main()
