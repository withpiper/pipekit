# {PROJECT_NAME} — Design Direction

**Version:** v0.1.0
**Last Updated:** YYYY-MM-DD
**Audience:** Developers, AI Agents

---

## Purpose

Captures the visual identity and design preferences for this project. This doc is read by development agents (including `/frontend-design`) during execution to ensure consistent, intentional aesthetics across all UI work.

---

## Aesthetic Direction

[Pick one or combine: brutally minimal, maximalist, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, or describe your own.]

**In one sentence:** [e.g., "Clean and professional with warm accents — feels like a well-designed finance tool, not a toy."]

---

## Inspiration

[Links to sites, apps, screenshots, or Figma boards that capture the feel you want. 2-5 references is ideal.]

| Reference | What to take from it |
|-----------|---------------------|
| [link or name] | [what you like about it — layout? color? typography? feel?] |
| [link or name] | [what you like about it] |

---

## Typography

**Display font:** [e.g., "Something geometric and modern" or a specific font]
**Body font:** [e.g., "Clean sans-serif, high readability" or a specific font]
**Avoid:** [e.g., "Inter, Roboto, Arial — too generic"]

---

## Color & Theme

**Primary palette:** [describe or provide hex values]
**Accent color(s):** [describe or provide hex values]
**Theme preference:** [Light / Dark / Both / System-adaptive]
**Avoid:** [e.g., "Purple gradients on white — too AI-generic"]

---

## Motion & Animation

**Level:** [None / Subtle / Moderate / Expressive]
**Where it matters most:** [e.g., "Page transitions and data loading states"]
**Avoid:** [e.g., "Gratuitous bounce effects"]

---

## Layout & Composition

[Any preferences on layout patterns: sidebar nav, top nav, dashboard grids, card-based, etc.]

---

## Existing Brand Assets

[List any logos, icons, color tokens, or design system components that already exist.]

---

## Anti-Patterns

[Things you explicitly don't want. Examples:]
- Generic dashboard templates
- Cookie-cutter card layouts
- Overused component library defaults without customization

**Known AI defaults to actively avoid** (current frontier models tend to produce these without explicit counter-direction):
- Warm cream/off-white backgrounds (~`#F4F1EA`)
- Serif display fonts like Georgia, Fraunces, Playfair
- Italic word-accents on marketing copy
- Terracotta/amber accent colors
- Space Grotesk typography
- Purple gradients on white or dark backgrounds
- Inter / Roboto / system font stacks
- Predictable hero-feature-cta layouts without character

If your aesthetic leans into any of these, say so explicitly above — otherwise the build agents will default to them.

---

## Build-Time Variation Protocol

When implementing new UI, development agents should **propose 4 distinct visual directions tailored to this brief** before building, each as: `bg hex / accent hex / typeface — one-line rationale`. User picks one, then the agent implements only that direction. This breaks the model's tendency to converge on default aesthetics across generations.

Skip this protocol only when the direction is already locked (e.g., established brand system, existing component library).

---

## Notes

[Any other context — target devices, accessibility requirements, dark mode priority, etc.]
