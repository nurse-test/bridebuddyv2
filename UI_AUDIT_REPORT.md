# UI Files Audit Report

**Date**: 2025-10-25
**Branch**: `claude/audit-html-files-011CUTHue1LiSg93gdkjM8Gh`

---

## Executive Summary

Found **13 HTML files** with **CRITICAL duplications across 3 different design systems**. Multiple files serve the same purpose but use different styling approaches, creating confusion and maintenance overhead.

### Critical Issues Found:
- ❌ **3 dashboard files** (dashboard.html vs dashboard-v2.html vs dashboard-luxury.html)
- ❌ **3 design systems** running in parallel (Tailwind, styles-v2, styles-luxury)
- ❌ **2 landing pages** (welcome-v2.html vs index-luxury.html)
- ❌ **2 signup flows** (onboarding-v2.html vs signup-luxury.html)
- ❌ **No login-luxury.html** to match signup-luxury.html
- ⚠️ **dashboard.html is 1,195 lines** (3x larger than dashboard-v2.html)

---

## File Inventory

### Total: 13 HTML Files (~4,854 lines)

| File | Lines | Size | Purpose | Design System |
|------|-------|------|---------|---------------|
| `dashboard.html` | 1,195 | 41K | Dashboard (OLD) | Tailwind + Inline CSS |
| `dashboard-v2.html` | 258 | 11K | Dashboard (CURRENT) | styles-v2.css |
| `dashboard-luxury.html` | 639 | 28K | Dashboard (NEW) | styles-luxury.css |
| `welcome-v2.html` | 37 | 1.2K | Landing page | styles-v2.css |
| `index-luxury.html` | 215 | 11K | Landing page (NEW) | styles-luxury.css |
| `login-v2.html` | 86 | 3.7K | Login form | styles-v2.css |
| `signup-luxury.html` | 391 | 17K | Signup form (NEW) | styles-luxury.css |
| `onboarding-v2.html` | 439 | 19K | Multi-step signup | styles-v2.css |
| `bestie-v2.html` | 261 | - | Bestie chat mode | styles-v2.css |
| `invite-v2.html` | 427 | - | Create invite | styles-v2.css |
| `accept-invite.html` | 465 | - | Accept invite | styles-v2.css |
| `notifications-v2.html` | 280 | - | Notifications page | styles-v2.css |
| `subscribe-v2.html` | 161 | - | Subscription modal | styles-v2.css |

---

## Critical Issue #1: Triple Dashboard Files

### The Problem
**THREE separate dashboard implementations** exist:

| File | Lines | Design System | Features | Status |
|------|-------|---------------|----------|--------|
| `dashboard.html` | 1,195 | Tailwind + Custom CSS | Full featured, bloated | ❌ Legacy |
| `dashboard-v2.html` | 258 | styles-v2.css | Chat interface only | ✅ Current |
| `dashboard-luxury.html` | 639 | styles-luxury.css | Full dashboard + stats | ✅ New Design |

### Design System Comparison

**dashboard.html** (Legacy):
```html
<!-- Uses Tailwind CDN + Inline styles -->
<script src="https://cdn.tailwindcss.com"></script>
<style>
    :root {
        --midnight-navy: #0A1628;
        --electric-blue: #00D4FF;
        --warm-gold: #D4AF37;
        /* Custom glassmorphism variables */
    }
</style>
```
- 1,195 lines (HUGE)
- Custom color palette (midnight navy, electric blue, warm gold)
- Glassmorphism design
- Complete dashboard with stats, activity, tasks
- **Problem**: Abandoned design system, inconsistent with rest of app

**dashboard-v2.html** (Current):
```html
<link rel="stylesheet" href="/css/styles-v2.css">
```
- 258 lines (compact)
- Uses shared styles-v2.css
- Color palette: Navy, gold, bridal pastels
- Chat interface focused
- Refactored with `/js/shared.js`
- **Problem**: Chat-only, missing dashboard features

**dashboard-luxury.html** (New):
```html
<link rel="stylesheet" href="/css/styles-luxury.css">
<link rel="stylesheet" href="/css/components-luxury.css">
```
- 639 lines (comprehensive)
- Luxury botanical-tech design system
- Color palette: Navy, burgundy, rust, champagne gold, cream
- Full dashboard + stats + activity feed + team members
- Frosted glass cards with backdrop-filter
- **Advantage**: Most complete, best design

### Code Duplication

All three dashboards implement:
- ✅ Wedding data loading
- ✅ User authentication check
- ✅ Trial badge display
- ✅ Navigation menu
- ✅ Chat integration

**Estimated duplication**: ~400 lines across 3 files

### Recommendation

**Consolidate to ONE dashboard**:

✅ **Keep**: `dashboard-luxury.html`
- Most complete feature set
- Best design system (luxury botanical-tech)
- Full responsive layout
- Integrates with shared.js

❌ **Delete**: `dashboard.html` (legacy, Tailwind, abandoned design)
❌ **Delete**: `dashboard-v2.html` (can be migrated to luxury)

**OR** keep dashboard-v2.html for chat and rename dashboard-luxury.html to `home-luxury.html` or `overview-luxury.html`

---

## Critical Issue #2: Dual Landing Pages

### The Problem
**TWO landing pages** with same purpose:

| File | Lines | Design System | Features |
|------|-------|---------------|----------|
| `welcome-v2.html` | 37 | styles-v2.css | Simple (2 buttons) |
| `index-luxury.html` | 215 | styles-luxury.css | Rich (hero, features, footer) |

### Comparison

**welcome-v2.html**:
```html
<!-- Minimal landing -->
<h1>Bride Buddy</h1>
<div onclick="startWedding()">Start Your Wedding</div>
<div onclick="returningUser()">Returning</div>
```
- 37 lines
- 2 buttons only
- Links to: onboarding-v2.html, login-v2.html

**index-luxury.html**:
```html
<!-- Rich landing page -->
<h1>Bride BUDDY</h1>
<h2>Your AI Wedding Planning Assistant</h2>
<p>Plan collaboratively with your partner, family, and friends...</p>
<!-- Feature badges -->
<!-- Info cards grid -->
<!-- Footer -->
```
- 215 lines
- Hero section
- Feature badges (AI Chat, Collaborative Planning, Private Bestie Mode)
- 3 feature cards
- Full footer
- Links to: onboarding-v2.html, login-v2.html

### Recommendation

✅ **Keep**: `index-luxury.html` (comprehensive, better UX)
❌ **Delete**: `welcome-v2.html` (minimal, redundant)

**Update all links**: Change references from `welcome-v2.html` to `index-luxury.html`

---

## Critical Issue #3: Dual Signup Flows

### The Problem
**TWO different signup approaches**:

| File | Lines | Approach | Design System |
|------|-------|----------|---------------|
| `onboarding-v2.html` | 439 | Multi-step (7 slides) | styles-v2.css |
| `signup-luxury.html` | 391 | Single-page form | styles-luxury.css |

### Comparison

**onboarding-v2.html** (Multi-step):
```javascript
// 7-slide wizard
// Slide 1: Email & Password
// Slide 2: Full Name
// Slide 3: Partner 1 Name
// Slide 4: Partner 2 Name
// Slide 5: Wedding Date
// Slide 6: Ceremony Location
// Slide 7: Budget & Guest Count
```
- 439 lines
- Progressive disclosure (one field at a time)
- Progress dots indicator
- Creates wedding profile during onboarding
- **Advantage**: Better UX for first-time users

**signup-luxury.html** (Single-page):
```javascript
// All fields on one page
// - Full Name
// - Email
// - Password
// - Confirm Password
// - Terms checkbox
// Redirects to onboarding-v2.html after signup
```
- 391 lines
- Single form
- Only creates user account
- Redirects to onboarding-v2.html for wedding setup
- **Advantage**: Simpler, luxury design

### Flow Conflict

**Current flow**:
1. `index-luxury.html` → "Start Your Wedding" → `onboarding-v2.html`
2. `index-luxury.html` → "Returning" → `login-v2.html`
3. `signup-luxury.html` → creates account → `onboarding-v2.html`

**Problem**:
- `signup-luxury.html` is orphaned (nothing links to it!)
- `onboarding-v2.html` handles BOTH signup AND onboarding

### Recommendation

**Option A: Separate Signup from Onboarding**

1. ✅ **Keep**: `signup-luxury.html` (account creation only)
2. ✅ **Keep**: `onboarding-v2.html` (BUT rename to `wedding-setup-v2.html`)
3. **Update flow**:
   - `index-luxury.html` → "Start" → `signup-luxury.html` → `wedding-setup-v2.html`
   - New users: signup first, then wedding details
4. **Convert onboarding-v2.html**: Remove slides 1-2 (email/password), keep slides 3-7

**Option B: Keep Multi-step Onboarding**

1. ✅ **Keep**: `onboarding-v2.html` (all-in-one signup + onboarding)
2. ❌ **Delete**: `signup-luxury.html` (redundant)
3. **Problem**: Design system mismatch (onboarding uses styles-v2, landing uses luxury)

**Recommended**: **Option A** - Separate concerns, maintain luxury design system

---

## Critical Issue #4: Missing Login Page for Luxury System

### The Problem

| Purpose | v2 File | Luxury File | Status |
|---------|---------|-------------|--------|
| Landing | `welcome-v2.html` | `index-luxury.html` | ✅ Exists |
| Signup | `onboarding-v2.html` | `signup-luxury.html` | ✅ Exists |
| Login | `login-v2.html` | ❌ **MISSING** | ⚠️ Gap |
| Dashboard | `dashboard-v2.html` | `dashboard-luxury.html` | ✅ Exists |

### Current Login

**login-v2.html**:
```html
<link rel="stylesheet" href="/css/styles-v2.css">
<!-- Simple login form -->
<form id="loginForm">
  <input type="email" id="email">
  <input type="password" id="password">
  <button>Sign In</button>
</form>
```
- 86 lines
- Uses styles-v2.css (not luxury)
- Links back to `welcome-v2.html` (not index-luxury.html)

### Flow Inconsistency

**User journey with luxury system**:
1. `index-luxury.html` (luxury design) ✅
2. Click "Returning" → `login-v2.html` (v2 design) ❌ **INCONSISTENT**
3. After login → `dashboard-v2.html` (v2 design) ❌ **INCONSISTENT**

**Should be**:
1. `index-luxury.html` (luxury)
2. Click "Returning" → `login-luxury.html` (luxury) ✅
3. After login → `dashboard-luxury.html` (luxury) ✅

### Recommendation

**Create `login-luxury.html`**:
- Copy structure from `signup-luxury.html`
- Simplify to email + password only
- Redirect to `dashboard-luxury.html` after login
- Update `index-luxury.html` to link to `login-luxury.html`

---

## Critical Issue #5: Three Design Systems Running in Parallel

### The Problem

**Three separate CSS systems** coexist:

| Design System | Files | Color Palette | Status |
|---------------|-------|---------------|--------|
| **Tailwind + Inline** | 1 file | Midnight navy, electric blue, warm gold | ❌ Abandoned |
| **styles-v2.css** | 9 files | Navy, gold, bridal pastels | ✅ Current |
| **styles-luxury.css** | 3 files | Navy, burgundy, rust, champagne gold | ✅ New |

### Files by Design System

**Tailwind + Inline CSS (1 file)**:
- `dashboard.html` (1,195 lines)

**styles-v2.css (9 files)**:
- `welcome-v2.html`
- `login-v2.html`
- `onboarding-v2.html`
- `dashboard-v2.html`
- `bestie-v2.html`
- `invite-v2.html`
- `accept-invite.html`
- `notifications-v2.html`
- `subscribe-v2.html`

**styles-luxury.css (3 files)**:
- `index-luxury.html`
- `signup-luxury.html`
- `dashboard-luxury.html`

### Visual Inconsistency

Users experience **3 different visual styles** depending on which page they're on:

**Example user journey**:
1. Visit `index-luxury.html` → See luxury botanical-tech (burgundy, rust, gold)
2. Click "Start Your Wedding" → `onboarding-v2.html` → See v2 design (bridal pastels, gold)
3. Complete onboarding → `dashboard-v2.html` → See v2 design
4. Click profile dropdown → Open `notifications-v2.html` → See v2 design
5. Navigate to old bookmark → `dashboard.html` → See Tailwind design (electric blue!)

❌ **No consistency** across user journey

### Recommendation

**Standardize on ONE design system**:

**Option A: Migrate Everything to Luxury** (RECOMMENDED)

✅ **Advantages**:
- Best visual design (luxury botanical-tech)
- Most modern (frosted glass, backdrop-filter)
- Complete component library
- Comprehensive documentation (LUXURY_UI_README.md)

**Migration plan**:
1. ✅ **Keep as-is**: index-luxury.html, signup-luxury.html, dashboard-luxury.html
2. **Create**: login-luxury.html
3. **Convert**: onboarding-v2.html → onboarding-luxury.html (use luxury components)
4. **Convert**: bestie-v2.html → bestie-luxury.html
5. **Convert**: invite-v2.html → invite-luxury.html
6. **Convert**: notifications-v2.html → notifications-luxury.html
7. **Convert**: subscribe-v2.html → subscribe-luxury.html
8. **Convert**: accept-invite.html → accept-invite-luxury.html
9. ❌ **Delete**: dashboard.html (old Tailwind version)
10. ❌ **Delete**: All -v2 files after conversion

**Option B: Keep v2 for Now**

✅ **Advantages**:
- Less immediate work
- v2 is functional and deployed

❌ **Disadvantages**:
- Design inconsistency remains
- Two codebases to maintain
- Confusing for developers

---

## File-by-File Analysis

### 1. dashboard.html (1,195 lines) ❌ **DELETE**

**Purpose**: Full dashboard with stats, chat, tasks
**Design**: Tailwind + Inline CSS (midnight navy, electric blue)
**Status**: Legacy, abandoned design system

**Why Delete**:
- Uses abandoned design system (Tailwind inline)
- 1,195 lines is excessive (3x larger than dashboard-v2)
- Not using shared.js (duplicate code)
- Inconsistent with rest of app

**Replacement**: dashboard-luxury.html (has all features)

---

### 2. dashboard-v2.html (258 lines) ⚠️ **EVALUATE**

**Purpose**: Chat-focused dashboard
**Design**: styles-v2.css
**Status**: Current production file

**Why Keep**:
- Compact (258 lines)
- Uses shared.js (refactored)
- Production-ready
- Links to all other -v2 pages

**Why Delete**:
- Missing dashboard features (stats, team, activity)
- Design system being replaced by luxury

**Recommendation**:
- **Short-term**: Keep as chat interface
- **Long-term**: Migrate to dashboard-luxury.html

---

### 3. dashboard-luxury.html (639 lines) ✅ **KEEP**

**Purpose**: Complete dashboard with stats, team, activity
**Design**: styles-luxury.css (luxury botanical-tech)
**Status**: New, production-ready

**Why Keep**:
- Most complete dashboard implementation
- Best design (luxury botanical-tech)
- Uses shared.js
- Full responsive layout
- Stats cards, wedding details, recent activity, quick actions

**Missing**:
- No chat interface (could add or link to dashboard-v2.html)

**Recommendation**: **Primary dashboard going forward**

---

### 4. welcome-v2.html (37 lines) ❌ **DELETE**

**Purpose**: Minimal landing page
**Design**: styles-v2.css
**Status**: Superseded by index-luxury.html

**Why Delete**:
- Only 37 lines (2 buttons, no features)
- Replaced by index-luxury.html (better UX)
- Design system being phased out

**Replacement**: index-luxury.html

**Required changes**:
- Update login-v2.html: Change "Back to Welcome" link from welcome-v2.html to index-luxury.html

---

### 5. index-luxury.html (215 lines) ✅ **KEEP**

**Purpose**: Rich landing page
**Design**: styles-luxury.css (luxury botanical-tech)
**Status**: New, production-ready

**Why Keep**:
- Complete landing page (hero, features, footer)
- Luxury design system
- Feature badges, info cards
- Production-ready

**Current links**:
- "Start Your Wedding" → onboarding-v2.html ⚠️ (design mismatch)
- "Returning" → login-v2.html ⚠️ (design mismatch)

**Recommendation**: Update links to luxury versions

---

### 6. login-v2.html (86 lines) ⚠️ **MIGRATE TO LUXURY**

**Purpose**: Login form
**Design**: styles-v2.css
**Status**: Current production, needs luxury version

**Why Migrate**:
- Design inconsistency with index-luxury.html
- Links to welcome-v2.html (being deleted)
- Redirects to dashboard-v2.html (prefer dashboard-luxury.html)

**Recommendation**: Create login-luxury.html

---

### 7. signup-luxury.html (391 lines) ✅ **KEEP**

**Purpose**: Single-page signup form
**Design**: styles-luxury.css (luxury botanical-tech)
**Status**: New, production-ready

**Why Keep**:
- Best signup design
- Complete validation
- Luxury design system
- Google OAuth option

**Current issue**:
- Not linked from anywhere! (orphaned)
- Redirects to onboarding-v2.html (design mismatch)

**Recommendation**:
- Link from index-luxury.html OR
- Keep onboarding-v2.html for all-in-one signup

---

### 8. onboarding-v2.html (439 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Multi-step signup + wedding setup (7 slides)
**Design**: styles-v2.css
**Status**: Current production

**Why Keep**:
- Excellent UX (progressive disclosure)
- Creates user account + wedding profile
- Handles full onboarding flow

**Why Migrate**:
- Design mismatch with index-luxury.html
- styles-v2.css being replaced

**Recommendation**:
- Create onboarding-luxury.html (convert to luxury components)
- OR split into signup-luxury.html + wedding-setup-luxury.html

---

### 9. bestie-v2.html (261 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Bestie chat mode (private planning)
**Design**: styles-v2.css
**Status**: Current production

**Why Keep**:
- Unique feature (bestie mode)
- Uses shared.js (refactored)
- Production-ready

**Why Migrate**:
- Design consistency with luxury system

**Recommendation**: Create bestie-luxury.html

---

### 10. invite-v2.html (427 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Create wedding invites
**Design**: styles-v2.css
**Status**: Current production

**Why Keep**:
- Core feature
- Uses shared.js
- Production-ready

**Why Migrate**:
- Design consistency

**Recommendation**: Create invite-luxury.html

---

### 11. accept-invite.html (465 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Accept wedding invite
**Design**: styles-v2.css
**Status**: Current production

**Why Keep**:
- Core feature
- Handles invite acceptance flow

**Why Migrate**:
- Design consistency
- No "-v2" suffix (inconsistent naming)

**Recommendation**: Rename to accept-invite-luxury.html

---

### 12. notifications-v2.html (280 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Notifications page
**Design**: styles-v2.css
**Status**: Current production

**Why Migrate**:
- Design consistency

**Recommendation**: Create notifications-luxury.html

---

### 13. subscribe-v2.html (161 lines) ✅ **KEEP (Migrate to Luxury)**

**Purpose**: Subscription/upgrade modal
**Design**: styles-v2.css
**Status**: Current production

**Why Migrate**:
- Design consistency

**Recommendation**: Create subscribe-luxury.html (or use modal component)

---

## Summary of Duplications

| Duplication Type | Files Involved | Impact |
|------------------|----------------|--------|
| Dashboard pages | 3 files (dashboard.html, dashboard-v2.html, dashboard-luxury.html) | 🔴 Critical |
| Landing pages | 2 files (welcome-v2.html, index-luxury.html) | 🟡 Medium |
| Signup flows | 2 files (onboarding-v2.html, signup-luxury.html) | 🟡 Medium |
| Design systems | 3 systems (Tailwind, v2, luxury) | 🔴 Critical |
| **TOTAL** | **13 files, 3 design systems** | **High confusion** |

---

## Recommended Cleanup Plan

### Phase 1: Remove Legacy Files (Immediate)

❌ **DELETE**:
1. `dashboard.html` (1,195 lines of abandoned Tailwind code)
2. `welcome-v2.html` (superseded by index-luxury.html)

**Lines removed**: ~1,232 lines
**Impact**: No functionality lost

### Phase 2: Create Missing Luxury Files (High Priority)

✅ **CREATE**:
1. `login-luxury.html` (copy from signup-luxury, simplify)
2. `onboarding-luxury.html` (convert onboarding-v2.html to luxury components)

**Lines added**: ~600 lines
**Impact**: Complete luxury system, design consistency

### Phase 3: Migrate Remaining Files to Luxury (Medium Priority)

**Convert to luxury design**:
1. `bestie-v2.html` → `bestie-luxury.html`
2. `invite-v2.html` → `invite-luxury.html`
3. `accept-invite.html` → `accept-invite-luxury.html`
4. `notifications-v2.html` → `notifications-luxury.html`
5. `subscribe-v2.html` → `subscribe-luxury.html` (or use modal)

**Estimated effort**: ~3-5 hours (can use component library)

### Phase 4: Delete v2 Files (After Migration)

❌ **DELETE** (after luxury versions created):
1. `dashboard-v2.html`
2. `login-v2.html`
3. `onboarding-v2.html`
4. `bestie-v2.html`
5. `invite-v2.html`
6. `accept-invite.html`
7. `notifications-v2.html`
8. `subscribe-v2.html`

**Lines removed**: ~2,477 lines
**Impact**: Single design system, no duplication

### Phase 5: Update All Links

**Update references**:
- Change all `welcome-v2.html` → `index-luxury.html`
- Change all `login-v2.html` → `login-luxury.html`
- Change all `dashboard-v2.html` → `dashboard-luxury.html`
- Change all `-v2.html` → `-luxury.html`

---

## Total Cleanup Impact

### Before Cleanup:
- **13 HTML files** (~4,854 lines)
- **3 design systems** (Tailwind, v2, luxury)
- **3 dashboard versions**
- **2 landing pages**
- **Design inconsistency** across user journey

### After Cleanup:
- **13 HTML files** (luxury versions)
- **1 design system** (luxury)
- **1 dashboard version** (dashboard-luxury.html)
- **1 landing page** (index-luxury.html)
- **Consistent design** across entire app

### Files to Delete (Immediate):
1. ❌ `dashboard.html` (1,195 lines)
2. ❌ `welcome-v2.html` (37 lines)

**Total removal**: 1,232 lines (25% reduction)

### Files to Create:
1. ✅ `login-luxury.html` (~100 lines)
2. ✅ `onboarding-luxury.html` (~500 lines)

### Files to Convert (later):
1. `bestie-v2.html` → `bestie-luxury.html`
2. `invite-v2.html` → `invite-luxury.html`
3. `accept-invite.html` → `accept-invite-luxury.html`
4. `notifications-v2.html` → `notifications-luxury.html`
5. `subscribe-v2.html` → `subscribe-luxury.html`
6. `dashboard-v2.html` → (merge features into dashboard-luxury.html or keep as chat page)

---

## Decision Matrix

| File | Recommendation | Reason | Priority |
|------|----------------|--------|----------|
| `dashboard.html` | ❌ DELETE | Abandoned design system, bloated | 🔴 High |
| `dashboard-v2.html` | ⚠️ EVALUATE | Chat-focused, could merge into luxury | 🟡 Medium |
| `dashboard-luxury.html` | ✅ KEEP | Best dashboard, complete features | ✅ Keep |
| `welcome-v2.html` | ❌ DELETE | Superseded by index-luxury | 🔴 High |
| `index-luxury.html` | ✅ KEEP | Best landing page | ✅ Keep |
| `login-v2.html` | ⚠️ MIGRATE | Create login-luxury.html | 🟡 Medium |
| `signup-luxury.html` | ✅ KEEP | Best signup design | ✅ Keep |
| `onboarding-v2.html` | ⚠️ MIGRATE | Convert to luxury | 🟡 Medium |
| `bestie-v2.html` | ⚠️ MIGRATE | Convert to luxury | 🟢 Low |
| `invite-v2.html` | ⚠️ MIGRATE | Convert to luxury | 🟢 Low |
| `accept-invite.html` | ⚠️ MIGRATE | Convert to luxury | 🟢 Low |
| `notifications-v2.html` | ⚠️ MIGRATE | Convert to luxury | 🟢 Low |
| `subscribe-v2.html` | ⚠️ MIGRATE | Convert to luxury or use modal | 🟢 Low |

---

## Conclusion

Your UI codebase has **significant duplication** primarily due to:
1. **Three design systems** running in parallel
2. **Legacy files** not cleaned up (dashboard.html)
3. **Incomplete luxury migration** (missing login, onboarding)
4. **Inconsistent user experience** across pages

**Immediate actions** (Phase 1):
- ✅ Delete dashboard.html (1,195 lines of abandoned code)
- ✅ Delete welcome-v2.html (superseded)

**High-priority actions** (Phase 2):
- ✅ Create login-luxury.html
- ✅ Create onboarding-luxury.html

**Result**: Consistent luxury design system across entire app

**Next steps**:
1. Delete immediate files
2. Create missing luxury files
3. Gradually migrate -v2 files to luxury
4. Update all internal links
5. Deprecate styles-v2.css

---

**The luxury UI system is superior in every way** - it just needs completion!
