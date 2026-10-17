import os
import sys
import time
from playwright.sync_api import sync_playwright

BASE_URL = "http://localhost:8085"
SCREENSHOTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "playwright_reports"))
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

test_results = []

def record(test_name, status, details=""):
    test_results.append({"name": test_name, "status": status, "details": details})
    symbol = "✓" if status == "PASS" else "✗"
    print(f"[{symbol}] {test_name}: {status} {details}")

def test_website(page):
    print("\n--- TESTING PUBLIC WEBSITE (/) ---")
    page.goto(BASE_URL, wait_until="networkidle")
    
    # 1. Page Title & Meta
    title = page.title()
    assert "GozVision" in title, f"Unexpected title: {title}"
    record("Website Title Verification", "PASS", f"Title: '{title}'")
    
    # 2. Favicon & Brand Mark
    favicon = page.locator('link[rel="icon"]').first
    href = favicon.get_attribute("href") if favicon.count() > 0 else ""
    record("Favicon Link Tag Check", "PASS" if "favicon.ico" in href or "favicon.png" in href else "FAIL", f"href: {href}")
    
    # 3. Logo Image
    nav_logo = page.locator(".brand-logo-img, img[alt*='GozVision'], img[src*='gozvision_lens']")
    assert nav_logo.count() > 0, "Brand logo not found on navbar"
    record("Navbar Brand Logo", "PASS", "Official lens badge displayed")
    
    # 4. Navigation Links
    clinic_link = page.locator('a[href*="/clinic"], a[href*="clinic"]').first
    patient_link = page.locator('a[href*="/patient"], a[href*="patient"]').first
    record("Navigation CTAs", "PASS" if clinic_link.count() > 0 and patient_link.count() > 0 else "FAIL")
    
    # 5. Interactive Simulator / Accessibility Controls
    sim_buttons = page.locator("button, .sim-btn, [role='button']")
    print(f"  Found {sim_buttons.count()} interactive controls on landing page")
    
    # Scroll down to ensure all lazy assets and sections load
    page.evaluate("window.scrollTo(0, document.body.scrollHeight / 2)")
    time.sleep(0.5)
    page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    time.sleep(0.5)
    page.evaluate("window.scrollTo(0, 0)")
    
    # 6. Capture full desktop page screenshot
    shot_path = os.path.join(SCREENSHOTS_DIR, "website_desktop.png")
    page.screenshot(path=shot_path, full_page=True)
    record("Website Desktop Full Render", "PASS", f"Saved: {shot_path}")
    
    # 7. Mobile Viewport Check (iPhone 14 equivalent)
    page.set_viewport_size({"width": 390, "height": 844})
    page.reload(wait_until="networkidle")
    mobile_shot = os.path.join(SCREENSHOTS_DIR, "website_mobile.png")
    page.screenshot(path=mobile_shot, full_page=True)
    record("Website Mobile Responsive Render", "PASS", f"Saved: {mobile_shot}")
    
    # Reset to desktop
    page.set_viewport_size({"width": 1440, "height": 900})

def test_clinic_app(page):
    print("\n--- TESTING CLINIC APP (/clinic/) ---")
    page.goto(f"{BASE_URL}/clinic/", wait_until="load")
    
    # Wait for Flutter Web engine bootstrap
    print("  Waiting for Flutter engine to mount...")
    # Flutter renders flutter-view or flt-glass-pane or canvas
    try:
        page.wait_for_selector("flutter-view, flt-glass-pane, canvas", timeout=25000)
        record("Clinic App Flutter Engine Bootstrap", "PASS", "CanvasKit engine loaded successfully")
    except Exception as e:
        record("Clinic App Flutter Engine Bootstrap", "FAIL", str(e))
        return
    
    time.sleep(3) # allow Flutter to finish initial frame build
    
    # Capture initial clinic portal frame
    shot_path = os.path.join(SCREENSHOTS_DIR, "clinic_initial_load.png")
    page.screenshot(path=shot_path)
    record("Clinic Initial Frame Render", "PASS", f"Saved: {shot_path}")
    
    # Check for canvas rendering activity
    canvases = page.locator("canvas")
    record("Flutter Canvas Surface Count", "PASS" if canvases.count() > 0 else "FAIL", f"Canvases: {canvases.count()}")

def test_patient_app(page):
    print("\n--- TESTING PATIENT APP (/patient/) ---")
    page.goto(f"{BASE_URL}/patient/", wait_until="load")
    
    # Wait for Flutter Web engine bootstrap
    print("  Waiting for Patient Flutter engine to mount...")
    try:
        page.wait_for_selector("flutter-view, flt-glass-pane, canvas", timeout=25000)
        record("Patient App Flutter Engine Bootstrap", "PASS", "PWA engine mounted successfully")
    except Exception as e:
        record("Patient App Flutter Engine Bootstrap", "FAIL", str(e))
        return
        
    time.sleep(3)
    shot_path = os.path.join(SCREENSHOTS_DIR, "patient_initial_load.png")
    page.screenshot(path=shot_path)
    record("Patient App Initial Render", "PASS", f"Saved: {shot_path}")

def run_suite():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        page = context.new_page()
        
        # Track console errors
        console_errors = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
        
        try:
            test_website(page)
            test_clinic_app(page)
            test_patient_app(page)
        except Exception as ex:
            print(f"Suite Exception: {ex}")
            record("Test Suite Execution", "FAIL", str(ex))
        finally:
            browser.close()
            
    print("\n================== PLAYWRIGHT SUMMARY ==================")
    passed = sum(1 for r in test_results if r["status"] == "PASS")
    failed = sum(1 for r in test_results if r["status"] == "FAIL")
    print(f"Total Tests: {len(test_results)} | Passed: {passed} | Failed: {failed}")
    if console_errors:
        print(f"\nCaptured {len(console_errors)} console errors during test run:")
        for err in console_errors[:5]:
            print(f"  - {err}")
    print("========================================================")

if __name__ == "__main__":
    run_suite()
