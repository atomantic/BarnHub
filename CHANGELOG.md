# Changelog

## 1.6.2

### New Features
- **Report a Bug** — send a bug report from Settings with app, device, sync status, and recent error details attached automatically (no personal data), so support can help faster.

### Bug Fixes
- **Edit vet records** — tap any vet record on a horse's page to change or delete it. Farrier and dentist visits can now be edited and deleted the same way. Previously these records could only be added.
- **iCloud sync on Mac** — the Mac app can now receive push updates from iCloud, so changes made on iPhone appear without relaunching.
- **iCloud sync on iPhone** — enabled background updates so changes from other devices arrive while the app isn't open.

## 1.6.0

### New Features
- **Mac App** — BarnHub is now available on macOS with a dashboard home screen, responsive layouts, and a hierarchical sidebar that reveals horse, client, and schedule sub-pages for quick navigation.
- **iPad Dashboard** — summary widgets on the home screen give iPad users an at-a-glance view of their barn.
- **Feed Planning** — build reusable feed plans per horse with inline product creation, a wider layout, and a cleaner sheet-based entry flow.
- **Horse Documents & Gender** — attach documents to individual horses and record gender on the horse profile.
- **Equine Dentist Tracking** — schedule and log equine dentist visits alongside vet and farrier appointments.
- **Full Localization** — complete translation coverage across all 9 supported languages with reactive in-app language switching (no restart).

### Improvements
- Day / Week / Month calendar toggle on the Schedule page.
- Light-mode and responsive layouts tuned for macOS across client, horse, and home views.
- Consistent empty-state centering on macOS and iPad.

### Bug Fixes
- Fixed duplicated value rendering in form number fields.
- Fixed feed entry sheet not rendering on macOS.
- Fixed sidebar sub-item highlighting and widened the macOS sidebar to fit longer labels.
- Removed an unnecessary restart prompt when switching languages.

## 1.3.0

### New Features
- **Document Storage** (Pro) — upload PDF contracts, photograph signed agreements with your camera, or pick photos from your library and attach them to any client's profile. Browse, share, and delete documents from the new Documents section on each client page.

### Code Quality
- Extracted generic model lookup helper across all edit views
- Single-pass report data aggregation replaces 7 scattered computed properties
- Added accessibility labels to decorative images across 6 views

## 1.2.0

### New Features
- **Push Notifications** — get notified when reminders, vet appointments, and farrier visits are due. Morning summary at 7 AM shows overdue tasks and today's schedule. Notifications are automatically scheduled when you create or edit reminders and appointments.
- **Contract Templates** (Pro) — generate professional boarding agreements, liability waivers, and care agreements as shareable PDFs directly from a client's profile. Includes client info, horse details, terms and conditions, and signature blocks.

### Improvements
- **Better Accessibility** — income/expense transactions now show direction arrows alongside colors, supply stock badges show distinct "Out" vs "Low" labels with warning icons for color-blind users
- **Dynamic Type Support** — reports empty state uses semantic fonts that scale with your accessibility settings
- **Smoother Saves** — improved save-and-dismiss behavior across all edit screens with proper cancellation handling

### Bug Fixes
- Fixed toast notification auto-dismiss that could interfere with view cancellation
- Fixed potential crash from force-unwrapped URL constants
- Unified vet and farrier schedule row layouts for consistent appearance
