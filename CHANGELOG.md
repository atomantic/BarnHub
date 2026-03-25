# Changelog

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
