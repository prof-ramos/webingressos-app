---
version: alpha
name: Campus Ledger
description: >
  A light, single-hue institutional-green system for a university
  event-operations product — a marketing site whose hero contains a live
  financial/ops dashboard preview, aimed at student organizations and
  event producers who need to be taken seriously about other people's
  money.
colors:
  primary: "#0e6340"
  primary-strong: "#0a4d32"
  primary-container: "#eaf5ef"
  accent: "#2f9e68"
  accent-soft: "#d3eadf"
  accent-softest: "#a9d6c0"
  on-primary: "#ffffff"
  on-primary-container: "#0e6340"
  surface: "#f9fafc"
  surface-container: "#ffffff"
  surface-container-muted: "#f1f6f5"
  outline: "#e9ecf1"
  outline-variant: "#d6dbe4"
  on-surface: "#1b2740"
  on-surface-variant: "#5e6677"
  on-surface-faint: "#8a92a3"
  error: "#c8394f"
  on-error: "#ffffff"
typography:
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 3.1rem
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: -0.028em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.875rem
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: -0.025em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.5rem
    fontWeight: 800
    lineHeight: 1.3
    letterSpacing: -0.02em
  title:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: 700
    lineHeight: 1.4
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: 400
    lineHeight: 1.625
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.625
  label:
    fontFamily: Plus Jakarta Sans
    fontSize: 1rem
    fontWeight: 700
    lineHeight: 1
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.875rem
    fontWeight: 600
    lineHeight: 1.3
  eyebrow:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.75rem
    fontWeight: 700
    lineHeight: 1
    letterSpacing: 0.16em
  caption:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.6875rem
    fontWeight: 600
    lineHeight: 1.3
rounded:
  control: 0.625rem
  tile: 0.875rem
  card: 1.25rem
  panel: 1.75rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  2xl: 56px
  gutter: 20px
motion:
  hover: 200ms
  panel-open: 220ms
  panel-close: 200ms
  easing: ease-out
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: 56px
    padding: 24px
  button-primary-hover:
    backgroundColor: "{colors.primary-strong}"
  button-secondary:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.primary}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: 56px
    padding: 24px
  button-compact:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.control}"
    height: 44px
    padding: 20px
  card:
    backgroundColor: "{colors.surface-container}"
    rounded: "{rounded.card}"
    padding: 24px
  card-hover:
    backgroundColor: "{colors.surface-container}"
  panel:
    backgroundColor: "{colors.surface-container-muted}"
    rounded: "{rounded.panel}"
    padding: 56px
  panel-inverse:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.panel}"
    padding: 40px
  input:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.control}"
    height: 48px
    padding: 16px
  icon-chip:
    backgroundColor: "{colors.primary-container}"
    textColor: "{colors.primary-strong}"
    rounded: "{rounded.full}"
    size: 36px
  checkbox:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.primary}"
    rounded: 6px
    size: 20px
---

## Overview

Picture a bank's back-office operations console that got assigned to redesign a flyer for a university costume party — and took the job completely seriously. That tension is the whole system: financial-grade restraint (revenue tiles, settlement figures, progress bars, a "98% valid" check-in stat) rendered in a single confident green, sitting on an almost-white canvas, aimed at 20-year-olds who run their fraternity's or athletic club's event budget and need to trust the thing with real money.

The product's own brief states the target feeling as "energetic without a nightclub aesthetic — trustworthy first." That rules out almost everything a consumer-facing events brand reaches for by default: no neon, no glow, no gradient mesh, no glassmorphism, no confetti color. The only color that gets to be loud is the single institutional green, and even that green is closer to a passport stamp or a ledger stripe than a highlighter. Everything else is white paper, hairline rule, and graphite-navy ink.

The UI reads as calm and slightly formal at rest — cards are flat, bordered, barely elevated — and becomes only _slightly_ more alive on interaction: a card lifts two pixels and gains a soft shadow on hover, a button darkens by one step, nothing bounces or springs. The energy the brief asks for lives in the copy's directness and the confident scale of the headline type, not in motion or saturation.

## Colors

A monochromatic system: one green hue carries every interactive and brand moment, and a desaturated blue-gray ink scale carries every word. There is no secondary or tertiary hue — introducing one would immediately read as "consumer event app" rather than "financial infrastructure."

- **Primary ({colors.primary}):** A deep, slightly blue-leaning forest green — closer to a passport cover or a bank vault door than to anything botanical. It is the only saturated color in the system and appears exclusively on the single most important action in any given view: the primary CTA, the deep-green closing band, filled icon roundels.
- **Primary Strong ({colors.primary-strong}):** The hover/pressed state of primary. It does not lighten on interaction — a common consumer-app tell — it _deepens_, the way a wet ink stamp reads darker than a dry one. This is a deliberate signal of gravity, not liveliness.
- **Primary Container ({colors.primary-container}):** A near-white green wash used only as a quiet background — icon roundels on light surfaces, checklist bullet backdrops, the large "Programa Piloto" band. It should never be mistaken for a second brand color; it is primary diluted almost to nothing.
- **Accent ({colors.accent}):** A mid-toned, slightly more saturated green reserved for data — chart bars, sparkline strokes, checkmarks, progress fills. This is the "the numbers are good" color. It never appears on static UI chrome, only on things that represent a live metric.
- **Surface ({colors.surface}):** Not pure white — a barely-there cool off-white, the visual equivalent of uncoated paper stock rather than a glossy screen. This is the page canvas everything else floats on.
- **Surface Container ({colors.surface-container}):** True white, reserved for anything that needs to read as a discrete object sitting _on_ the canvas — cards, the header bar, form fields, the dashboard panel.
- **Surface Container Muted ({colors.surface-container-muted}):** A pale green-gray, one step warmer than pure white, used for exactly one purpose: the large "we're selecting our first partners" band. It signals "this section is a distinct offer," not decoration.
- **Outline ({colors.outline}):** A hairline neutral gray used for every card and input border in the system. Borders here are informational, not decorative — thin enough to feel like a rule on a ledger page, never a heavy stroke.
- **On Surface ({colors.on-surface}):** A near-black navy — not true black — used for every headline and every important number. It has just enough blue in it to feel considered rather than default.
- **On Surface Variant ({colors.on-surface-variant}):** A cooler mid-gray for all body copy and secondary text. It is dim enough to clearly subordinate itself to headlines, never competing for attention.
- **On Surface Faint ({colors.on-surface-faint}):** The quietest text color in the system — chart axis labels, placeholder text, micro-captions inside the dashboard preview. If a reader has to squint, that's correct; this text is ambient, not addressed to them directly.
- **Error ({colors.error}):** A single desaturated red-pink for form validation only. It never appears anywhere else in the system — no error-colored badges, no destructive-red accents in illustrations.

## Typography

One family carries the entire system: a geometric-humanist grotesque with a double-story lowercase "a" and rounded terminals — friendly enough to not feel like enterprise software, but set at weights and tracking tight enough to still feel like it's handling money. There is no second display face and no monospace anywhere; numeral-heavy content (currency, percentages, dashboard stats) is set in the same family at a heavier weight rather than switching to tabular figures in a different face.

- **Display ({typography.display}):** The single largest text on the page, used once — the hero headline. It is set extremely tight (`-0.028em` tracking, `1.08` line height), so three short lines of a punchy Portuguese sentence read as one dense, confident block rather than a loose title.
- **Headline Large ({typography.headline-lg}):** Every section title on the page ("Organizar o evento não deveria depender de planilhas…"). Same extra-bold weight as display, same instinct toward tight tracking, but scaled down enough to sit comfortably above a grid of cards without competing with the hero.
- **Headline Medium ({typography.headline-md}):** Sub-page and sub-section titles — a form's own heading, a confirmation page's headline. Same weight and tightness as headline-lg, one step smaller.
- **Title ({typography.title}):** Card and tile titles — a pillar's name, a dashboard stat's headline number. Bold rather than extra-bold; this is where the system starts feeling like data rather than a manifesto.
- **Body Large ({typography.body-lg}):** Sub-headline copy directly under a display or headline-lg — generously leaded (`1.625`) so a two-sentence supporting paragraph never feels cramped against the bold headline above it.
- **Body Medium ({typography.body-md}):** Default paragraph and card-description copy throughout. Same generous leading as body-lg, one step smaller.
- **Label ({typography.label}):** Primary button text. Bold, tight line-height, no letter-spacing — it should read as a single confident word or short phrase, never as a paragraph fragment.
- **Label Small ({typography.label-sm}):** Form field labels, nav links, secondary buttons. Semi-bold rather than bold — present but clearly subordinate to primary labels.
- **Eyebrow ({typography.eyebrow}):** Small kicker text above a section or panel headline ("PROGRAMA PILOTO"). Always set in uppercase with wide tracking (`0.16em`) and always in the accent green — this is the one place tracked-out caps are allowed, and it should never bleed into any other text role.
- **Caption ({typography.caption}):** The smallest text in the system — axis labels and micro-annotations inside the dashboard preview only. It is allowed to be nearly illegible at a glance; its job is texture and plausibility, not communication.

## Layout

Mobile-first with a hard ceiling: content never exceeds a comfortably narrow desktop measure, keeping even the widest six-column grid from sprawling into "dashboard software" territory. Every section shares one consistent side gutter and one consistent vertical rhythm — spacing compresses uniformly from desktop to mobile rather than sections having their own bespoke rhythm.

The page is built from a strict single-column stack on mobile that progressively splits into two- and multi-column grids as width allows: a two-column hero (copy beside a live dashboard preview) collapses to a single stacked column below desktop width; a six-item problem grid steps down through three columns to two as the viewport narrows; a four-item feature grid does the same through two columns. Nothing reflows into an asymmetric or masonry layout — every grid is a strict, evenly-sized grid at every breakpoint.

Interior padding scales with a component's importance: compact controls (inputs, buttons, nav pills) use the smallest padding step, cards use a step up, and the two large "band" panels (the pale program panel and the deep-green closing panel) use the most generous padding in the system, reinforcing that they are the two moments the page most wants to slow down for.

## Elevation & Depth

Depth is almost entirely conveyed through **borders and background-color steps**, not shadow. Every card sits directly on the page canvas with only a 1px hairline outline — the shadow underneath it is so faint (low opacity, tightly clipped) that on a quick glance the card reads as "outlined," not "floating." This is a deliberate choice: heavy drop shadows would read as consumer-app gloss, which is exactly the register this system avoids.

There are exactly three elevation moments, and each is used for exactly one thing:

1. **Card rest state** — a whisper of a shadow plus a hairline border. Used for every problem tile, pillar tile, and audience pill.
2. **Card hover state** — the same whisper of a shadow, slightly more present, paired with the card's outline shifting from neutral gray to a faint green tint and the card lifting two pixels. This is the _only_ elevation change that responds to interaction anywhere in the system.
3. **Panel elevation** — a much larger, softer, more diffused shadow reserved for exactly one element: the dashboard preview floating beside the hero copy. It is allowed to look like a real "object" in a way nothing else on the page is, because it is the one piece of UI standing in for an actual product screenshot.

The deep-green closing band and the pale program-piloto band both sit flush with zero shadow — they're panels of color, not floating cards, and should never pick up a drop shadow no matter how tempting it is to add one for "polish."

## Shapes

Corner radius scales with a container's size, not its importance: the biggest, calmest panels get the roundest corners, and the smallest, densest UI (dashboard mini-tiles) gets the tightest ones. Nothing in the system is sharp-cornered — the softest radius still reads as "considered," never "clinical" — but nothing is fully rounded into a pill either, except literal pills and circular icon chips.

- **Control** ({rounded.control}): buttons, inputs, select triggers, nav pills. This is the workhorse radius — soft enough to feel approachable, tight enough that a row of controls still reads as a grid, not a cluster of capsules.
- **Tile** ({rounded.tile}): the small stat tiles inside the dashboard preview. Slightly softer than a control, since these are meant to feel like miniature cards rather than input chrome.
- **Card** ({rounded.card}): every content card — problem tiles, pillar tiles, the form container, the FAQ items. The signature radius of the system; if a screenshot of this product had to be identified from silhouette alone, this radius is the tell.
- **Panel** ({rounded.panel}): the two largest single-color band panels. Round enough to feel like a soft object rather than a hard-edged banner ad.
- **Full** ({rounded.full}): perfect circles only — icon roundels, small circular badges. Never used for buttons or cards; a pill-shaped button here would read as "consumer app," which this system is deliberately avoiding.

Line art (the two small illustrations of a ticket stub and an ID badge) is drawn exclusively in thin, uniform, rounded-cap strokes in the primary or accent green at low opacity — never filled, never multi-color, never photographic. It should read as a diagram sketched on the ledger page, not as marketing illustration.

## Components

- **Button — Primary** ({colors.primary} fill, {colors.on-primary} text): the only filled button in the system. One per view, always the single highest-priority action ("Quero participar do piloto"). Darkens on hover; never lightens, never scales, never glows.
- **Button — Secondary** (white fill, {colors.primary} text, {colors.outline}-tinted border): the "second" action on any screen that has two. Same height and radius as primary so a pair of buttons always aligns as a clean row, never mismatched.
- **Button — Compact**: the same primary treatment at a smaller height, used only inside chrome-constrained contexts like the site header, never in page content.
- **Card**: white fill, hairline border, whisper shadow at rest, lift-plus-tint-plus-slightly-stronger-shadow on hover. The universal content container — every repeating grid item in the system is a Card.
- **Panel**: the large pale-green band. Houses a checklist and supporting illustration; always paired with an eyebrow label above its headline.
- **Panel — Inverse**: the large solid-green closing band. White text on green, paired with a white pill-free secondary-style button (white fill, green text) — the one place a "secondary" button appears on a colored background rather than white.
- **Input**: white fill, hairline border, generous internal padding, focus state shown as a colored border plus a soft ring rather than a color fill change. Every text field, select trigger, and textarea in the form shares identical height and radius so a multi-column form row always lines up.
- **Icon Chip**: a small perfect circle in the palest green, holding a single-color outline icon. Used wherever a list item or stat needs a lightweight visual anchor without competing with the surrounding text.
- **Checkbox**: a small square, white at rest, filling solid primary green with a white check mark once ticked — the only checkbox-style control in the system, used exactly once (consent).

## Do's and Don'ts

- **Do** treat green as a scarce resource — if more than one element per view is fully saturated green, something has gone wrong.
- **Do** let hover states be quiet: a two-pixel lift, a one-step color shift, nothing that bounces, scales past 100%, or glows.
- **Do** keep every card's border and shadow proportional to its size — bigger panels get softer, larger shadows; small tiles stay nearly flat.
- **Do** set numbers and money amounts in the same type family as everything else, just heavier — never switch to a monospace or tabular-figures face to signal "this is data."
- **Don't** introduce a second brand hue. No blue, no purple, no orange accent "for variety" — the entire palette is one green plus neutral ink.
- **Don't** use neon, gradient, glow, or glassmorphism anywhere. A shadow with more than a whisper of opacity, or a button with a colored glow underneath it, is an immediate tell that the design has drifted into "nightclub event app" territory, which is explicitly what this system exists to avoid.
- **Don't** round anything into a full pill except literal circular icon chips and badges. A pill-shaped button or card reads as consumer-casual, not institutional.
- **Don't** add motion beyond a 200ms color/position transition. No parallax, no scroll-triggered reveals, no spring physics.
- **Don't** let illustrations become filled, multi-color, or photographic. They stay thin-stroke, single-hue line art at all times.
- **Don't** use pure black or pure white for text and backgrounds — the ink is always a navy-tinted near-black, the canvas always a cool near-white.
