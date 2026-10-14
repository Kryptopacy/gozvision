const fs = require('fs');
const path = require('path');

console.log('==> Deploying GozVision Web Assets across all portals...');

const tempDir = path.resolve(__dirname, 'temp_icons');

const targets = [
  {
    name: 'Marketing Website',
    root: path.resolve(__dirname, '../apps/website'),
    isRoot: true,
  },
  {
    name: 'Clinic Suite (B2B)',
    root: path.resolve(__dirname, '../apps/clinic/web'),
    isRoot: false,
  },
  {
    name: 'Patient Copilot (B2C)',
    root: path.resolve(__dirname, '../apps/patient/web'),
    isRoot: false,
  },
];

targets.forEach(target => {
  console.log(`\nProcessing ${target.name}: ${target.root}`);
  const iconsDir = path.join(target.root, 'icons');
  if (!fs.existsSync(iconsDir)) {
    fs.mkdirSync(iconsDir, { recursive: true });
  }

  // Favicons
  fs.copyFileSync(path.join(tempDir, 'favicon.ico'), path.join(target.root, 'favicon.ico'));
  fs.copyFileSync(path.join(tempDir, 'icon_32.png'), path.join(target.root, 'favicon.png'));
  fs.copyFileSync(path.join(tempDir, 'icon_32.png'), path.join(target.root, 'favicon-32x32.png'));
  fs.copyFileSync(path.join(tempDir, 'icon_16.png'), path.join(target.root, 'favicon-16x16.png'));
  fs.copyFileSync(path.join(tempDir, 'apple_touch_icon.png'), path.join(target.root, 'apple-touch-icon.png'));

  // PWA Icons
  fs.copyFileSync(path.join(tempDir, 'icon_192.png'), path.join(iconsDir, 'Icon-192.png'));
  fs.copyFileSync(path.join(tempDir, 'icon_512.png'), path.join(iconsDir, 'Icon-512.png'));
  fs.copyFileSync(path.join(tempDir, 'icon_maskable_192.png'), path.join(iconsDir, 'Icon-maskable-192.png'));
  fs.copyFileSync(path.join(tempDir, 'icon_maskable_512.png'), path.join(iconsDir, 'Icon-maskable-512.png'));

  // OG Image
  fs.copyFileSync(path.join(tempDir, 'og_image.png'), path.join(target.root, 'og_image.png'));
  if (target.isRoot) {
    const assetsDir = path.join(target.root, 'assets');
    if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });
    fs.copyFileSync(path.join(tempDir, 'og_image.png'), path.join(assetsDir, 'og_image.png'));
    fs.copyFileSync(path.join(tempDir, 'icon_32.png'), path.join(assetsDir, 'favicon.png'));
  }

  console.log(`  ✓ Successfully deployed icons, favicon.ico, and og_image.png to ${target.name}`);
});

// Write apps/website/manifest.json
const websiteManifest = {
  name: "GozVision — Optical Intelligence & AI Copilot Platform",
  short_name: "GozVision",
  start_url: "/",
  scope: "/",
  display: "standalone",
  background_color: "#08090C",
  theme_color: "#08090C",
  description: "Ambient Scribe charting, intelligent scheduling, low-vision referral tracking, and Goz — the voice-first multimodal AI copilot patients take home.",
  orientation: "any",
  icons: [
    {
      src: "/icons/Icon-192.png",
      sizes: "192x192",
      type: "image/png"
    },
    {
      src: "/icons/Icon-512.png",
      sizes: "512x512",
      type: "image/png"
    },
    {
      src: "/icons/Icon-maskable-192.png",
      sizes: "192x192",
      type: "image/png",
      purpose: "maskable"
    },
    {
      src: "/icons/Icon-maskable-512.png",
      sizes: "512x512",
      type: "image/png",
      purpose: "maskable"
    }
  ]
};
fs.writeFileSync(
  path.resolve(__dirname, '../apps/website/manifest.json'),
  JSON.stringify(websiteManifest, null, 4)
);
console.log('✓ Wrote apps/website/manifest.json');

// Write apps/clinic/web/manifest.json
const clinicManifest = {
  name: "GozVision Clinic Suite",
  short_name: "Goz Clinic",
  start_url: "./",
  scope: "./",
  display: "standalone",
  background_color: "#08090C",
  theme_color: "#08090C",
  description: "The practice platform for eye care clinics — Low Vision Hub, Front Desk, Scribe, and Insights.",
  orientation: "any",
  prefer_related_applications: false,
  icons: [
    {
      src: "icons/Icon-192.png",
      sizes: "192x192",
      type: "image/png"
    },
    {
      src: "icons/Icon-512.png",
      sizes: "512x512",
      type: "image/png"
    },
    {
      src: "icons/Icon-maskable-192.png",
      sizes: "192x192",
      type: "image/png",
      purpose: "maskable"
    },
    {
      src: "icons/Icon-maskable-512.png",
      sizes: "512x512",
      type: "image/png",
      purpose: "maskable"
    }
  ]
};
fs.writeFileSync(
  path.resolve(__dirname, '../apps/clinic/web/manifest.json'),
  JSON.stringify(clinicManifest, null, 4)
);
console.log('✓ Wrote apps/clinic/web/manifest.json');

// Write apps/patient/web/manifest.json
const patientManifest = {
  name: "Goz Copilot",
  short_name: "Goz Copilot",
  start_url: "./",
  scope: "./",
  display: "standalone",
  background_color: "#08090C",
  theme_color: "#08090C",
  description: "Goz — The empathetic AI copilot for low-vision patients.",
  orientation: "portrait-primary",
  prefer_related_applications: false,
  icons: [
    {
      src: "icons/Icon-192.png",
      sizes: "192x192",
      type: "image/png"
    },
    {
      src: "icons/Icon-512.png",
      sizes: "512x512",
      type: "image/png"
    },
    {
      src: "icons/Icon-maskable-192.png",
      sizes: "192x192",
      type: "image/png",
      purpose: "maskable"
    },
    {
      src: "icons/Icon-maskable-512.png",
      sizes: "512x512",
      type: "image/png",
      purpose: "maskable"
    }
  ]
};
fs.writeFileSync(
  path.resolve(__dirname, '../apps/patient/web/manifest.json'),
  JSON.stringify(patientManifest, null, 4)
);
console.log('✓ Wrote apps/patient/web/manifest.json');

console.log('\n==> Web Assets Deployment Complete!');
