# Changelog

## 1.7.1

### Improvements
- The Horses list shows its Show Inactive button only when you have inactive horses, and a toast says what the list now shows when you tap it (#93).

### Bug Fixes
- The iCloud sync icon on Home is easy to see again in iOS light mode (#94).

## 1.7.0

### New Features
- **Big screens and iPhone Duo** — two-column layouts on iPad, iPhone Duo and Mac with lists beside details, sortable Transactions and Supplies tables, and layouts that follow the iPhone Duo's fold (#13, #18–#27).
- **A more native Mac app** — Settings window, File ▸ New, row menus, tooltips, and add/edit forms as sheets.
- **Restore All Data** — restore an All Data export folder from Settings, adding what's missing or deleting everything first (#79, #84, #86, #87).
- **Complete All Data export** — every record type plus photos, documents and invoice PDFs, linked by ID (#55, #72).
- **Deep links** — the `barnhub` URL scheme opens the app from links and notification taps (#80).

### Improvements
- Finished translations for onboarding, paywall and photo strings, plus localized PDF labels, dates and currency (#12, #53, #60, #68).
- Faster screens that fetch only what they show; smaller photos with cached thumbnails (#40, #48).
- Notifications stay under iOS's limit and recurring reminders recur (#38).

### Bug Fixes
- Documents open in Quick Look instead of a blank sheet (#66).
- Invoices open on the Mac (#82).
- Correct invoice totals, date ranges, report periods and Unpaid amounts (#53, #60).
- CSV import and export work across time zones and locales (#44).
- Ask before deleting clients and all data; fixed Mac crashes and the macOS 14 onboarding crash (#27, #43).

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
