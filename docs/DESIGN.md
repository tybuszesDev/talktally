# Design principles

TalkTally helps people get into focus. The interface stays quiet, so that the user's work stands out, not the app.

There are no mockups yet. Screens are built in the simplest form that follows these principles, reviewed from screenshots in pull requests, and refined in the post-MVP polish milestone.

## Principles

1. **Calm.** Black and white, generous whitespace, light weight. Nothing on the screen competes for attention.
2. **Content first.** Hierarchy comes from typography and spacing, not from colour, boxes or decoration.
3. **One primary action per screen.** On mobile the main screen has one obvious action: the microphone.
4. **Quiet feedback.** Status is shown with short text and small icons. No confetti, streaks, badges, gamification or attention-seeking animation. The only counter is the number of operations waiting for review.
5. **Professional.** No illustrations, emoji, gradients, glass effects or stock imagery.

## Visual language

**Colour**

| Token | Value | Use |
|---|---|---|
| `background` | `#FFFFFF` | page background |
| `surface` | `#FAFAFA` | subtle grouping (cards, table headers) |
| `border` | `#E5E5E5` | hairline separators (1 px), used instead of shadows |
| `text` | `#0A0A0A` | primary text, primary buttons |
| `text-muted` | `#6B6B6B` | secondary text (contrast about 5.3:1 on white) |
| `danger` | `#B42318` | the only colour: errors and destructive confirmations |

States such as "pending review" or "archived" use font weight, outline or an icon, not colour.

**Typography**

- Web: Inter. iOS: the system font (SF Pro). Android later: the system font (Roboto).
- Scale: 12, 14, 16, 20, 24, 32. Weights: 400, 500, 600.
- Tabular figures for quantities and metrics, so numbers line up in tables.

**Shape, space, motion**

- 4 px spacing grid. Corner radius 6 px.
- Icons: Lucide, 1.5 px stroke, monochrome.
- Motion only when it explains a change (≤ 200 ms). Respect the system "reduce motion" setting.

**Theme**

- The MVP ships the light theme. All colours are tokens, so a dark theme (an inverted monochrome palette) can be added in the polish milestone.
- Tokens live in `packages/design-tokens` and feed both the web Tailwind configuration and the mobile styles.

## Components

- Web: shadcn/ui with its neutral theme, restyled to the tokens above.
- Mobile: a small set of own components that use the same tokens. No mobile UI kit.

## Writing

- Short, neutral sentences in sentence case. No exclamation marks.
- Numbers always with units: "4 bags", "3 m²".
- Error messages say what happened and what the user can do next.

## Accessibility

- WCAG 2.2 AA contrast.
- Touch targets at least 44 × 44 pt.
- iOS Dynamic Type is supported.
- Visible keyboard focus on the web.

## Review checklist for UI pull requests

- Screenshots (web and mobile, small and large screen) are attached.
- No new colours outside the tokens.
- One primary action per screen.
- Accessibility labels and `testID`s are present.
