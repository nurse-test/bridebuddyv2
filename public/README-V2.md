# 🎨 Bride Buddy V2 - Complete Design Package

## Circuit Board Aesthetic with Bridal Elegance

This is the complete, production-ready frontend design for Bride Buddy with your new circuit board aesthetic, electricity animations, and lazy Susan loading.

---

## 📦 What's Included

### ✅ Complete Design System
**File: `styles-v2.css`**

**Color Palette:**
- Background Gradient: Navy (#3C009D) → Purple (#7911C4) → Peach (#FF9F72)
- Main Colors (75% opacity boxes): Ivory (#FFFBF6), Light Blue (#9C76C6), Lavender (#E1B8FF), Light Peach (#FFE8DE)
- Accent: Gold (#D4AF37)

**Features:**
- ⚡ Electricity pulse animation (every 10 seconds across circuit background)
- 🔄 Lazy Susan loading animation with wedding icons + circuit nodes
- 📱 Mobile-first responsive design
- 🎭 Semi-transparent boxes with backdrop blur
- 🌈 Different background styles for different page types

---

## 🎨 Design Breakdown by Page Type

### 1. **Gradient Background Pages**
**Used for:** Login, Onboarding, Checkout, Bestie Chat

**Styling:**
- Saturated gradient background with circuit pattern (bg-gradient.png)
- Electricity pulse effect every 10 seconds
- Semi-transparent colored boxes (ivory, light blue, lavender, light peach)
- White text for labels and headings
- Gold accent buttons

**Files:**
- `welcome-v2.html` - Landing page with two boxes
- `onboarding-v2.html` - 8-slide onboarding with lazy Susan loading
- `subscribe-v2.html` - Pricing tiers
- `login-v2.html` - User login
- `bestie-v2.html` - Bestie planning chat

---

### 2. **Bridal/Ivory Background Pages**
**Used for:** Main Dashboard/Chat, Invites, Notifications

**Styling:**
- Ivory background with subtle circuit pattern (bg-bridal.png) at 10-20% opacity
- Clean, elegant aesthetic
- Navy text for readability
- Gold accents on buttons and highlights
- Light colored chat bubbles

**Files:**
- `dashboard-v2.html` - Main wedding planning chat
- `invite-v2.html` - Invite collaborators
- `notifications-v2.html` - Pending approvals

---

## 📄 All HTML Pages

### Core Pages (7 total):

1. **welcome-v2.html** - Landing page
   - Gradient background
   - Two ivory boxes: "Start Your Wedding" and "Returning"
   
2. **onboarding-v2.html** - 8-slide onboarding
   - Slide 1: Email & Password (Ivory box)
   - Slide 2: Name (Light Blue box)
   - Slide 3: About Us (Lavender box)
   - Slide 4: Engagement Date (Light Peach box)
   - Slide 5: Planning Status (Ivory box with buttons)
   - Slide 6: Planning Checklist (Light Blue box with checkboxes)
   - Slide 7/8: Lazy Susan loading animation

3. **subscribe-v2.html** - Pricing tiers
   - VIP: $12.99/month or $99 one-time
   - VIP + Bestie: $19.99/month or $149 one-time
   
4. **login-v2.html** - User login
   - Gradient background with ivory box
   
5. **dashboard-v2.html** - Main chat interface
   - Ivory/bridal background
   - Chat bubbles (user: gold, assistant: light purple)
   - Menu with navigation
   - Trial badge

6. **bestie-v2.html** - Bestie planning chat
   - Gradient background
   - Separate chat interface for pre-wedding event planning
   - Feature-gated (only if bestie_addon_enabled = true)

7. **invite-v2.html** - Invite collaborators
   - Bridal background
   - Form to send invites
   - List of pending invites and current members

8. **notifications-v2.html** - Pending approvals
   - Bridal background
   - List of co-planner update requests
   - View chat modal for context
   - Approve/reject actions

---

## 🖼️ Image Assets

**Background Images:**
- `bg-gradient.png` - Saturated gradient with circuit pattern
- `bg-bridal.png` - Ivory background with subtle circuit pattern

**Wedding Icons (for Lazy Susan):**
- `icon-champagne.png` - Champagne glasses
- `icon-rings.png` - Wedding rings
- `icon-cake.png` - Wedding cake
- `icon-hearts.png` - Hearts

**How They're Used:**
- Lazy Susan rotates all 4 icons around a circle
- Circuit nodes pulse with gold glow between icons
- Creates beautiful loading animation

---

## ⚡ Special Animations

### 1. Electricity Pulse
- Runs every 10 seconds
- White shimmer sweeps across circuit background
- Subtle and elegant effect
- Defined in `@keyframes electricityPulse`

### 2. Lazy Susan Loading
- 4 wedding icons rotate in a circle
- 4 circuit nodes pulse with gold glow
- 8-second rotation cycle
- Appears during onboarding loading screens

### 3. Slide Animations
- `slide-in-right` - Boxes slide in from right
- `slide-in-left` - Boxes slide in from left
- `fade-in` - Smooth fade in effect
- Used for page transitions

---

## 🎯 Box Styles (75% Opacity)

All boxes use semi-transparent colors with backdrop blur:

```css
.box-ivory        /* White/ivory - most common */
.box-light-blue   /* Purple-blue tint */
.box-lavender     /* Light purple */
.box-light-peach  /* Peachy/pink tint */
```

**Modifiers:**
- `.box-clickable` - Adds hover effect and cursor
- `.box-sm` - Smaller padding variant

---

## 📱 Mobile-First Design

**Breakpoints:**
- Mobile: 320px - 767px (primary focus)
- Tablet/Desktop: 768px+ (enhanced layout)

**Key Mobile Features:**
- Touch-friendly button sizes (min 48px)
- Readable font sizes (16px base)
- Optimized tap targets
- Smooth scrolling
- Fixed chat header/footer

---

## 🎨 Typography

**Fonts:**
- Logo: 'Great Vibes' (cursive, elegant)
- Headings: 'Cormorant Garamond' (serif, classic)
- Body/UI: 'Montserrat' (sans-serif, modern)

**Usage:**
- Logo: Gold color, 2.5rem
- Headings: Navy or White (depending on background)
- Body: Navy (bridal pages) or White (gradient pages)

---

## 🔧 Technical Details

### CSS Classes Reference

**Backgrounds:**
- `.bg-gradient` - Saturated gradient with circuit pattern
- `.bg-bridal` - Ivory with subtle circuit pattern

**Containers:**
- `.screen` - Full-height centered container
- `.container` - Max-width content wrapper
- `.screen-centered` - Vertically centered content

**Buttons:**
- `.btn-primary` - Gold button
- `.btn-secondary` - White button
- `.btn-ghost` - Transparent with border
- `.btn-full` - Full width
- `.btn-lg` - Large size

**Forms:**
- `.form-group` - Form field wrapper
- `.form-label` - Field label
- `.form-input` - Text input/textarea/select
- `.form-error` - Error message

**Chat:**
- `.chat-container` - Main chat wrapper
- `.chat-header` - Fixed header
- `.chat-messages` - Scrollable messages area
- `.chat-message` - Individual message
- `.chat-bubble` - Message bubble
- `.chat-input-container` - Fixed input area

**Progress:**
- `.progress-dots` - Progress indicator
- `.progress-dot` - Individual dot
- `.progress-dot.active` - Active/completed dot

**Navigation:**
- `.nav-arrows` - Navigation button container
- `.nav-arrow` - Circular navigation button

---

## 📋 Deployment Checklist

### Before Deploying:

1. **Upload all images to `/public` folder:**
   - bg-gradient.png
   - bg-bridal.png
   - icon-champagne.png
   - icon-rings.png
   - icon-cake.png
   - icon-hearts.png

2. **Upload HTML files to `/public` folder:**
   - All *-v2.html files

3. **Upload CSS:**
   - styles-v2.css to `/public` folder

4. **Build API routes** (use Claude Code):
   - /api/create-wedding.js
   - /api/chat.js
   - /api/bestie-chat.js
   - /api/create-checkout.js
   - /api/stripe-webhook.js
   - /api/create-invite.js
   - /api/join-wedding.js
   - /api/approve-update.js

5. **Configure Vercel:**
   - Upload vercel.json
   - Set environment variables
   - Deploy!

---

## 🎭 Page Flow Summary

```
welcome-v2.html (gradient)
    ↓
onboarding-v2.html (gradient, 8 slides)
    ↓
[Lazy Susan Loading Animation]
    ↓
subscribe-v2.html (gradient, pricing)
    ↓
dashboard-v2.html (bridal, main chat)
    ├→ invite-v2.html (bridal)
    ├→ notifications-v2.html (bridal)
    ├→ bestie-v2.html (gradient, if addon enabled)
    └→ subscribe-v2.html (upgrade prompt)
```

**Login Flow:**
```
welcome-v2.html
    ↓ (click "Returning")
login-v2.html (gradient)
    ↓
dashboard-v2.html (bridal)
```

---

## 🚀 Ready for Claude Code

This complete package is ready to upload to Claude Code for API route development!

**What Claude Code Needs to Build:**
1. All 8 API routes (backend logic)
2. Supabase RLS policies
3. Stripe integration completion
4. Email sending functionality
5. Trial expiration cron job

**What You Already Have:**
✅ Complete design system
✅ All HTML pages
✅ All animations and interactions
✅ Mobile-first responsive layouts
✅ Beautiful circuit board aesthetic
✅ Lazy Susan loading animation
✅ Electricity pulse effects

---

## 💡 Design Philosophy

**Balance:** Tech-forward circuit aesthetic meets elegant bridal warmth

**User Experience:**
- Gradient pages feel exciting and dynamic (onboarding, checkout, bestie)
- Bridal pages feel calm and focused (main planning, collaboration)
- Clear visual hierarchy with gold accents
- Smooth animations without distraction

**Accessibility:**
- High contrast text
- Touch-friendly targets
- Clear error states
- Readable fonts

---

## 📞 Need Help?

All files are ready to download and deploy. Upload to Claude Code with the comprehensive prompt to build the backend API routes and launch today!

---

**Built with 💕 for couples planning their perfect day!**

---

## 🎉 You're Ready to Ship!

Everything is complete. Download all files, upload to Claude Code, and let's build those API routes! 🚀
