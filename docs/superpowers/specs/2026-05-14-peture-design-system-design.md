# Peture Design System Design

Date: 2026-05-14
Branch: `djy-ui`

## Goal

Peture is a one-stop pet care platform that combines practical pet management tools with a small set of playful, innovative experiences. The app should feel unified across pages while preserving the product's personality.

Brand keywords:

- Healing
- Reliable
- Lively
- Restrained

This design covers the MVP surface on `djy-ui`: home, auth, pet profile/passport, diary, image generation, clicker training, expense, medical records, profile/settings, and related account pages.

## Chosen Direction

Use **Warm Utility Hub** as the main app direction.

The home page should present Peture as a clear, reliable function hub with gentle emotional warmth. It keeps the current five MVP entry points:

- Pet expense
- Pet passport
- First-person diary
- Dog clicker
- AI image lab

The root login screen keeps its existing dark cosmic mood as a brand ritual, but it should be refined to match Peture's typography, buttons, accessibility, and motion restraint. After login, the main app uses the warm utility hub system.

## Visual Language

### Color

The app should move away from unrelated high-saturation gradients scattered across pages. Use a warm, low-saturation palette:

- Background: warm ivory / milk white
- Surface: clean white with subtle warm tint
- Primary: muted coral-peach
- Support: soft mint green
- Technology accent: restrained violet-blue
- Text: deep warm charcoal, not pure black
- Risk: clear red with calm supporting surfaces

Feature-specific colors are allowed only as local accents. AI image, diary, and clicker can keep a more playful identity, but they should still use shared spacing, cards, type, buttons, and inputs.

### Typography

Use a consistent Flutter text scale:

- Large title for page-level identity
- Title for sections and cards
- Body for readable content
- Label for metadata and controls
- Caption for secondary hints

Avoid mixing page-specific font personalities such as isolated serif/Lato combinations unless the whole system adopts them. Keep Chinese text legible and calm.

### Shape And Elevation

Use rounded but controlled shapes:

- Small controls: 12-14
- Cards and panels: 18-22
- Feature tiles: 22-24
- Bottom navigation / large pills: 28+

Use shadows sparingly. Prefer soft elevation and subtle borders over heavy glass effects. Glass/blur can remain in the bottom navigation and selected decorative places, but not as the default for every card.

### Motion

Motion should be lively but not noisy:

- Press feedback on cards and buttons
- Short transitions, usually 150-300ms
- Existing spring bottom navigation can stay, but its color and intensity should be restrained
- Ambient orbs should be slower and softer
- Avoid decorative animation that competes with tasks

## Flutter Architecture

Create a dedicated design system directory:

`lib/shared/design_system/`

Recommended files:

- `peture_tokens.dart`: colors, spacing, radii, shadows, motion durations
- `peture_theme.dart`: app `ThemeData`
- `peture_text_styles.dart`: app text roles
- `peture_gradients.dart`: brand and feature gradients
- `components/`: reusable widgets

Keep `lib/shared/utils/ui_helpers.dart` as a compatibility layer during migration. It may forward to the new tokens so existing pages are not rewritten all at once.

## First Components

Build these primitives first:

- `PeturePageScaffold`: unified background, safe area behavior, optional app bar, bottom padding
- `PetureCard`: standard, emphasized, and danger card variants
- `PetureFeatureTile`: home feature entry card
- `PeturePrimaryButton`
- `PetureSecondaryButton`
- `PetureDangerButton`
- `PetureTextField` or a shared input decoration helper
- `PetureSectionHeader`
- `PetureEmptyState`
- `PetureAlertPanel`: risk and sensitive-action panel

Use Material 3 where possible and keep native Flutter controls recognizable.

## Page Scope

### P0 Must Change

- Global theme and base design tokens/components
- Home page as the Warm Utility Hub sample
- Root login page: keep dark cosmic style, refine brand/control/accessibility alignment
- Email login and email registration
- Account security
- Change password
- Account deactivation

### P1 Change If Visibly Split

- AI image lab: keep creative energy, reduce isolated purple/pink neon dominance
- Medical records: keep reliable professional tone, migrate away from isolated local theme
- Profile and pet profile flows: align cards, avatars, lists, and forms
- Expense home: align background, cards, chart containers, and controls
- Dog clicker: preserve the skeuomorphic device, align surrounding page and panels
- Diary pages: keep warmth, align inputs, selectors, generation state, and share surfaces

### P2 Light Touch

- Library and deeper detail/result pages that do not dominate the main path
- Older shared widgets unless directly used by P0/P1 work

## Auth Notes

The root login page is intentionally allowed to differ from the main app surface. It should feel like a night-sky brand entry, not a separate product:

- Keep the dark cosmic backdrop
- Refine logo, supporting copy, and login option cards
- Use design-system buttons and text roles
- Reduce overwhelming animation where needed
- Preserve existing auth routing and password-change handoff behavior

Email login/register should align strongly with the final system because they are task-heavy trust surfaces.

Phone login is currently unavailable. Do not add SMS capability. If touched, make its unavailable state clear and visually consistent.

## Non-Goals

- Do not add new features.
- Do not change authentication logic.
- Do not change Supabase function contracts.
- Do not rewrite every page in one sweep.
- Do not remove feature-specific personality where it serves the product.

## Verification

Before completion:

- Run Flutter analysis.
- Run focused Flutter tests if available.
- Manually inspect the app in simulator or browser if feasible.
- Check mobile safe areas and bottom navigation overlap.
- Check text contrast and tap target sizes.
- Confirm no MVP function entry was removed or renamed in behavior.

Success means the main path no longer feels like multiple unrelated apps: home, auth, settings/security, and the five MVP entry points should share the same visual grammar while keeping Peture's gentle personality.
