# Bride Buddy Front-end UI Kit

A luxury botanical-tech interface for the Bride Buddy AI wedding planning assistant. This package contains fully responsive, accessible HTML, CSS, and JavaScript assets that mirror the product vision: Art Nouveau elegance infused with intelligent systems.

## File Structure

```
public/
  css/
    components.css      # Reusable UI tokens, buttons, cards, badges, utilities
    styles.css          # Global layout, page styles, responsive rules
  images/
    logo.svg            # Bride Buddy logotype
  js/
    api.js              # Placeholder API helpers demonstrating integration points
    auth.js             # Form helpers for validation and loading states
    main.js             # Global interactivity (sidebar, chat UI, copy buttons, etc.)
  pages/
    index.html             # Landing page
    signup.html            # Account creation
    login.html             # Returning user authentication
    dashboard.html         # Owner/Partner planning hub
    chat.html              # AI conversational workspace
    bestie-dashboard.html  # Private surprise planning command center
    invite.html            # Role-based invite generation
    accept-invite.html     # Invitee onboarding and permissions
    team.html              # Team roster management
    settings.html          # Account and wedding configuration
    pricing-modal.html     # Standalone modal markup for pricing plans
```

## Working With the UI

Each page includes references to the shared component and layout styles as well as the `main.js` helper script. The CSS makes heavy use of custom properties (CSS variables) so you can adjust colors or spacing from a central location. Cards employ a frosted glass technique with a warm champagne glow that stands out against the twilight gradient.

### Connecting to APIs

The JavaScript files are intentionally light and framework-agnostic. Replace the placeholder functions in `public/js/api.js` with fetch calls to your production endpoints. Use the helper functions in `auth.js` to wire up form validation, server-side error handling, and loading states when integrating with authentication services.

To attach real data:

1. Import your API helper inside the relevant page script block.
2. Call the function during `DOMContentLoaded` and render results into the provided markup (each section includes semantic classes ready for data binding).
3. Update button handlers in `main.js` if you add new interactions.

### Color Palette Reference

- Deep Twilight: `#1A0B2E`
- Midnight Plum: `#4A1942`
- Sunset Ember: `#8B4513`
- Champagne Glow: `#C9A961`
- Amber Depth: `#B8933D`
- Luminous Cream: `#FFF9E6`
- Soft Cream: `#F5E6D3`

### Component Usage Guide

- **Buttons**: Apply `.btn` plus a modifier class (`.btn-primary`, `.btn-secondary`, `.btn-outline`, `.btn-text`). Icons can be inserted using inline SVG or emoji.
- **Cards**: Wrap content with `.card` to obtain the frosted glass aesthetic, shadow, and hover lift effect.
- **Badges**: Use `.badge` or `.badge.gold` / `.badge.burgundy` for accent labels.
- **Inputs**: Place form controls inside `.input-group`. Add `.error` to inputs to trigger the burgundy state and append `.error-message` for helper text.
- **Toggle Switches**: Apply `.toggle` to a label that contains a checkbox input. The CSS handles the pill-and-knob visuals.
- **Layouts**: `.dashboard-layout` handles sidebar + main content responsiveness, while `.chat-layout` manages the conversation list and message pane.
- **Modals**: Wrap modal markup with `.modal-overlay` and `.modal-card` to receive the blur backdrop and entrance animation.

### Accessibility

- Semantic HTML tags (`header`, `main`, `nav`, `section`, `button`) are used across pages.
- Focus styles are enabled for keyboard navigation on interactive elements.
- Color contrast meets WCAG AA standards using the provided palette.
- ARIA labels are applied where necessary (e.g., for navigation toggles, menus, and status banners).

### Extending the System

- Add new background variations by duplicating the SVGs under `public/images/` and updating `body` classes in your pages.
- For stateful single-page apps, the layout CSS can be reused within frameworks like React or Next.js by converting HTML sections into components.
- Connect the invite flow to your backend by binding the generated link box to real data and hooking `data-copy` buttons to your clipboard utilities.

## Getting Started

No build step is required. You can start the included local preview server, which maps friendly routes like `/dashboard` to the corresponding HTML files under `public/pages/`:

```bash
npm run preview
```

The server defaults to `http://localhost:4173` and serves every asset from the `public/` directory. If you prefer another tool, you can still host the folder with any static server (e.g., `npx serve public`). Either option allows you to explore each page and verify responsiveness across breakpoints. Adjust the CSS variables to align with bespoke wedding palettes or client preferences without rewriting the component library.
