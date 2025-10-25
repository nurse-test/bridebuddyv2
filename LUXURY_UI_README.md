# Bride Buddy Luxury UI System
## Sunset Glow Design Language

Welcome to the Bride Buddy luxury UI system! This guide explains the design system, component library, and how to build production-ready pages using our sunset glow aesthetic.

---

## 📁 File Structure

```
/public
  /css
    styles-luxury.css        # Core design system & utilities
    components-luxury.css    # Reusable UI components
  /js
    shared.js               # Shared JavaScript utilities
  /images
    # Add your logo or supplemental artwork here (backgrounds are handled via CSS gradients)
  index-luxury.html         # Landing page (complete)
  # Add remaining pages here
```

---

## 🎨 Design Philosophy

**Sunset Glow Aesthetic**
- Dark-to-warm twilight gradient with illuminated frosted glass panels
- Champagne gold LED accents with subtle radial backlighting
- "Intentional technology" - warm hospitality meets intelligent systems
- Luxurious, sophisticated, and ready for launch

---

## 🌈 Color Palette

### Primary Colors

| Color | Hex | CSS Variable | Usage |
|-------|-----|--------------|-------|
| **Deep Twilight** | `#1A0B2E` | `var(--color-background-top)` | Background gradient (top), button text |
| **Midnight Plum** | `#4A1942` | `var(--color-background-middle)` | Gradient midpoint, overlays |
| **Sunset Ember** | `#8B4513` | `var(--color-warm)` | Warm accents, warnings |
| **Champagne Glow** | `#C9A961` | `var(--color-accent)` | Primary CTAs, highlights |
| **Amber Depth** | `#B8933D` | `var(--color-accent-dark)` | Hover states, emphasis |
| **Luminous Cream** | `#FFF9E6` | `var(--color-heading)` | Headlines, logo glow |
| **Soft Cream** | `#F5E6D3` | `var(--color-body)` | Body copy, supporting text |
| **Frosted Peach** | `rgba(255, 235, 205, 0.15)` | `var(--color-surface)` | Card surfaces, modals |

### Gradients

```css
--gradient-gold: linear-gradient(135deg, #C9A961 0%, #B8933D 100%);
--gradient-sunset: linear-gradient(180deg, #1A0B2E 0%, #4A1942 50%, #8B4513 100%);
--gradient-glow: radial-gradient(circle at 20% 20%, rgba(255, 235, 205, 0.2) 0%, transparent 55%);
```

---

## 📐 Typography

### Font Families

- **Headings**: `'Playfair Display'` - Elegant serif for titles
- **Body**: `'Montserrat'` - Clean, modern sans-serif
- **Code**: SF Mono / Monaco

### Type Scale

```css
--text-xs: 0.75rem;      /* 12px */
--text-sm: 0.875rem;     /* 14px */
--text-base: 1rem;       /* 16px */
--text-lg: 1.125rem;     /* 18px */
--text-xl: 1.25rem;      /* 20px */
--text-2xl: 1.5rem;      /* 24px */
--text-3xl: 1.875rem;    /* 30px */
--text-4xl: 2.25rem;     /* 36px */
--text-5xl: 3rem;        /* 48px */
--text-6xl: 3.75rem;     /* 60px */
```

---

## 🧩 Component Library

### 1. Buttons

#### Primary Button (Gold Gradient)
```html
<button class="btn btn-primary">Start Planning</button>
<button class="btn btn-primary btn-lg">Large CTA</button>
<button class="btn btn-primary btn-sm">Small Button</button>
<button class="btn btn-primary btn-full">Full Width</button>
```

#### Secondary Button (Cream Outline)
```html
<button class="btn btn-secondary">Learn More</button>
```

#### Tertiary Button (Text Accent)
```html
<button class="btn btn-tertiary">Cancel</button>
```

#### Loading State
```html
<button class="btn btn-primary btn-loading">Processing...</button>
```

#### Icon Button
```html
<button class="btn btn-icon btn-primary">
  <svg><!-- icon --></svg>
</button>
```

---

### 2. Cards (Frosted Glass)

```html
<!-- Basic Card -->
<div class="card">
  <h3>Card Title</h3>
  <p>Card content goes here</p>
</div>

<!-- Small Card -->
<div class="card card-sm">
  <p>Compact content</p>
</div>

<!-- Large Card -->
<div class="card card-lg">
  <h2>Large Card</h2>
</div>

<!-- Card with Gold Accent -->
<div class="card card-gold-accent">
  <h3>Highlighted Card</h3>
</div>

<!-- Featured Card (Premium) -->
<div class="card card-featured">
  <h2>Premium Feature</h2>
</div>
```

---

### 3. Form Inputs

#### Text Input
```html
<div class="form-group">
  <label class="form-label" for="name">Full Name</label>
  <input
    type="text"
    id="name"
    class="form-input"
    placeholder="Jane Smith"
  >
</div>
```

#### Email Input with Validation
```html
<div class="form-group">
  <label class="form-label" for="email">Email</label>
  <input
    type="email"
    id="email"
    class="form-input is-error"
    placeholder="you@example.com"
  >
  <div class="form-error">Please enter a valid email</div>
</div>
```

#### Password Input with Toggle
```html
<div class="form-group">
  <label class="form-label" for="password">Password</label>
  <div class="form-input-wrapper">
    <input
      type="password"
      id="password"
      class="form-input"
      placeholder="Enter password"
    >
    <button type="button" class="password-toggle" aria-label="Toggle password visibility">
      👁️
    </button>
  </div>
</div>
```

#### Textarea
```html
<div class="form-group">
  <label class="form-label" for="notes">Notes</label>
  <textarea
    id="notes"
    class="form-textarea"
    placeholder="Enter your notes..."
  ></textarea>
</div>
```

#### Checkbox
```html
<div class="checkbox-wrapper">
  <input type="checkbox" id="agree" class="checkbox-input">
  <label for="agree" class="checkbox-label">
    I agree to the terms and conditions
  </label>
</div>
```

#### Toggle Switch
```html
<div class="toggle-wrapper">
  <label for="notifications">Email Notifications</label>
  <label>
    <input type="checkbox" id="notifications" class="toggle-input">
    <div class="toggle-switch"></div>
  </label>
</div>
```

---

### 4. Modals

```html
<!-- Modal Backdrop -->
<div class="modal-backdrop is-active">
  <div class="modal">
    <!-- Modal Header -->
    <div class="modal-header">
      <h2 class="modal-title">Modal Title</h2>
      <button class="modal-close" aria-label="Close modal">×</button>
    </div>

    <!-- Modal Body -->
    <div class="modal-body">
      <p>Modal content goes here</p>
    </div>

    <!-- Modal Footer -->
    <div class="modal-footer">
      <button class="btn btn-tertiary">Cancel</button>
      <button class="btn btn-primary">Confirm</button>
    </div>
  </div>
</div>
```

**JavaScript to Toggle Modal:**
```javascript
const modal = document.querySelector('.modal-backdrop');
const openBtn = document.querySelector('[data-modal-open]');
const closeBtn = document.querySelector('.modal-close');

openBtn.addEventListener('click', () => {
  modal.classList.add('is-active');
});

closeBtn.addEventListener('click', () => {
  modal.classList.remove('is-active');
});

// Close on backdrop click
modal.addEventListener('click', (e) => {
  if (e.target === modal) {
    modal.classList.remove('is-active');
  }
});
```

---

### 5. Toasts / Notifications

```html
<!-- Toast Container (place at end of body) -->
<div class="toast-container">

  <!-- Success Toast -->
  <div class="toast toast-success">
    <div class="toast-icon">✓</div>
    <div class="toast-content">
      <div class="toast-title">Success!</div>
      <p class="toast-message">Your changes have been saved.</p>
    </div>
    <button class="toast-close">×</button>
  </div>

  <!-- Error Toast -->
  <div class="toast toast-error">
    <div class="toast-icon">✗</div>
    <div class="toast-content">
      <div class="toast-title">Error</div>
      <p class="toast-message">Something went wrong.</p>
    </div>
    <button class="toast-close">×</button>
  </div>

  <!-- Info Toast -->
  <div class="toast toast-info">
    <div class="toast-icon">ℹ</div>
    <div class="toast-content">
      <div class="toast-title">Info</div>
      <p class="toast-message">New updates available.</p>
    </div>
    <button class="toast-close">×</button>
  </div>
</div>
```

**JavaScript for Auto-Dismiss:**
```javascript
function showToast(type, title, message, duration = 5000) {
  const container = document.querySelector('.toast-container');

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `
    <div class="toast-icon">${type === 'success' ? '✓' : type === 'error' ? '✗' : 'ℹ'}</div>
    <div class="toast-content">
      <div class="toast-title">${title}</div>
      <p class="toast-message">${message}</p>
    </div>
    <button class="toast-close">×</button>
  `;

  container.appendChild(toast);

  // Close button
  toast.querySelector('.toast-close').addEventListener('click', () => {
    toast.remove();
  });

  // Auto-dismiss
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// Usage:
showToast('success', 'Saved!', 'Your wedding details have been updated.');
```

---

### 6. Navigation

#### Top Navbar
```html
<nav class="navbar">
  <div class="navbar-container">
    <!-- Logo -->
    <img src="/images/logo.svg" alt="Bride Buddy" class="navbar-logo">

    <!-- Center Content -->
    <div class="navbar-center">
      <div class="navbar-wedding-name">Sarah & John's Wedding</div>
    </div>

    <!-- User Menu -->
    <div class="navbar-menu">
      <button class="navbar-user-button" aria-label="User menu">
        <div class="navbar-avatar">SJ</div>
        <span>Sarah</span>
        <svg width="16" height="16" fill="currentColor">
          <path d="M4.5 6l3.5 3.5L11.5 6z"/>
        </svg>
      </button>

      <!-- Dropdown -->
      <div class="dropdown-menu">
        <a href="#" class="dropdown-item">👤 Profile</a>
        <a href="#" class="dropdown-item">⚙️ Settings</a>
        <div class="dropdown-divider"></div>
        <button class="dropdown-item">🚪 Log Out</button>
      </div>
    </div>
  </div>
</nav>
```

#### Sidebar Navigation
```html
<aside class="sidebar">
  <nav class="sidebar-nav">
    <ul>
      <li class="sidebar-item">
        <a href="#" class="sidebar-link is-active">
          <span class="sidebar-icon">🏠</span>
          Dashboard
        </a>
      </li>
      <li class="sidebar-item">
        <a href="#" class="sidebar-link">
          <span class="sidebar-icon">💬</span>
          AI Chat
        </a>
      </li>
      <li class="sidebar-item">
        <a href="#" class="sidebar-link">
          <span class="sidebar-icon">👥</span>
          Team
        </a>
      </li>
      <li class="sidebar-item">
        <a href="#" class="sidebar-link">
          <span class="sidebar-icon">✉️</span>
          Invites
        </a>
      </li>
    </ul>
  </nav>
</aside>
```

#### Mobile Bottom Navigation
```html
<nav class="bottom-nav">
  <a href="#" class="bottom-nav-item is-active">
    <span class="bottom-nav-icon">🏠</span>
    Home
  </a>
  <a href="#" class="bottom-nav-item">
    <span class="bottom-nav-icon">💬</span>
    Chat
  </a>
  <a href="#" class="bottom-nav-item">
    <span class="bottom-nav-icon">👥</span>
    Team
  </a>
  <a href="#" class="bottom-nav-item">
    <span class="bottom-nav-icon">⚙️</span>
    Settings
  </a>
</nav>
```

---

### 7. Badges

```html
<span class="badge badge-gold">VIP Trial</span>
<span class="badge badge-burgundy">Co-planner</span>
<span class="badge badge-navy">Owner</span>
<span class="badge badge-gold badge-outlined">7 Days Left</span>
```

---

### 8. Loading States

#### Spinner
```html
<div class="spinner"></div>
<div class="spinner spinner-sm"></div>
<div class="spinner spinner-lg"></div>
```

#### Skeleton Loading
```html
<div class="skeleton skeleton-heading"></div>
<div class="skeleton skeleton-text"></div>
<div class="skeleton skeleton-text"></div>
```

---

### 9. Avatars

```html
<!-- Avatar with Initials -->
<div class="avatar avatar-gold avatar-md">SJ</div>

<!-- Avatar with Image -->
<div class="avatar avatar-lg">
  <img src="/path/to/image.jpg" alt="User" class="avatar-img">
</div>

<!-- Avatar Sizes -->
<div class="avatar avatar-gold avatar-sm">S</div>
<div class="avatar avatar-gold avatar-md">SJ</div>
<div class="avatar avatar-gold avatar-lg">SJ</div>

<!-- Avatar Group -->
<div class="avatar-group">
  <div class="avatar avatar-gold avatar-md">SJ</div>
  <div class="avatar avatar-gold avatar-md">AB</div>
  <div class="avatar avatar-gold avatar-md">CD</div>
</div>
```

---

### 10. Progress Bars

```html
<div class="progress">
  <div class="progress-bar" style="width: 75%;"></div>
</div>

<div class="progress progress-lg">
  <div class="progress-bar" style="width: 50%;"></div>
</div>
```

---

### 11. Tabs

```html
<div class="tabs">
  <button class="tab is-active">Profile</button>
  <button class="tab">Wedding Details</button>
  <button class="tab">Notifications</button>
  <button class="tab">Billing</button>
</div>
```

---

### 12. Alerts

```html
<!-- Success Alert -->
<div class="alert alert-success">
  <div class="alert-icon">✓</div>
  <div class="alert-content">
    <div class="alert-title">Success!</div>
    <p class="alert-message">Your changes have been saved.</p>
  </div>
</div>

<!-- Error Alert -->
<div class="alert alert-error">
  <div class="alert-icon">✗</div>
  <div class="alert-content">
    <div class="alert-title">Error</div>
    <p class="alert-message">Please fix the errors below.</p>
  </div>
</div>

<!-- Info Alert -->
<div class="alert alert-info">
  <div class="alert-icon">ℹ</div>
  <div class="alert-content">
    <div class="alert-title">Trial Ending Soon</div>
    <p class="alert-message">Your trial ends in 3 days. Upgrade to continue.</p>
  </div>
</div>
```

---

### 13. Empty States

```html
<div class="empty-state">
  <div class="empty-state-icon">📭</div>
  <h3 class="empty-state-title">No messages yet</h3>
  <p class="empty-state-description">
    Start a conversation with your AI wedding assistant to get personalized planning help.
  </p>
  <button class="btn btn-primary">Start Chatting</button>
</div>
```

---

## 🏗️ Building Pages - Templates

### Page Template Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Title - Bride Buddy</title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Montserrat:wght@300;400;500;600;700&display=swap" rel="stylesheet">

    <!-- Stylesheets -->
    <link rel="stylesheet" href="/css/styles-luxury.css">
    <link rel="stylesheet" href="/css/components-luxury.css">
</head>
<body>
    <!-- Skip to main -->
    <a href="#main-content" class="skip-to-main">Skip to main content</a>

    <!-- Choose background type -->
    <div class="bg-sunset"> <!-- OR bg-sunset for dashboard pages -->

        <!-- For landing pages -->
        <div class="container" style="min-height: 100vh;">
            <main id="main-content">
                <!-- Content here -->
            </main>
        </div>

        <!-- OR for dashboard pages with nav -->
        <nav class="navbar">
            <!-- Navbar here -->
        </nav>

        <aside class="sidebar">
            <!-- Sidebar here -->
        </aside>

        <main id="main-content" style="margin-left: 260px; padding: var(--space-6);">
            <!-- Dashboard content here -->
        </main>

        <nav class="bottom-nav">
            <!-- Mobile nav here -->
        </nav>
    </div>

    <!-- Scripts -->
    <script src="/js/shared.js" type="module"></script>
    <script>
        // Page-specific JavaScript
    </script>
</body>
</html>
```

---

## 📄 Page-Specific Examples

### Signup Page (signup.html)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sign Up - Bride Buddy</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Montserrat:wght@300;400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="/css/styles-luxury.css">
    <link rel="stylesheet" href="/css/components-luxury.css">
</head>
<body>
    <div class="bg-sunset">
        <div class="container" style="min-height: 100vh; display: flex; flex-direction: column; justify-content: center; align-items: center; padding: var(--space-8);">

            <!-- Logo (links to home) -->
            <a href="index-luxury.html" style="margin-bottom: var(--space-8);">
                <h1 class="logo" style="font-family: var(--font-heading); font-size: var(--text-4xl); color: var(--color-gold); margin: 0;">
                    <span style="font-style: italic; font-weight: 400;">Bride</span>
                    <span style="font-weight: 700;">BUDDY</span>
                </h1>
            </a>

            <!-- Signup Card -->
            <div class="card card-gold-accent" style="max-width: 480px; width: 100%;">
                <h2 style="text-align: center; margin-bottom: var(--space-6);">Start Planning Your Dream Wedding</h2>

                <form id="signupForm">
                    <!-- Full Name -->
                    <div class="form-group">
                        <label class="form-label" for="fullName">Full Name</label>
                        <input type="text" id="fullName" class="form-input" placeholder="Jane Smith" required>
                    </div>

                    <!-- Email -->
                    <div class="form-group">
                        <label class="form-label" for="email">Email</label>
                        <input type="email" id="email" class="form-input" placeholder="you@example.com" required>
                        <div class="form-error">Please enter a valid email</div>
                    </div>

                    <!-- Password -->
                    <div class="form-group">
                        <label class="form-label" for="password">Password</label>
                        <div class="form-input-wrapper">
                            <input type="password" id="password" class="form-input" placeholder="Choose a secure password" required>
                            <button type="button" class="password-toggle" onclick="togglePassword('password')">👁️</button>
                        </div>
                        <div class="form-error">Password must be at least 6 characters</div>
                    </div>

                    <!-- Confirm Password -->
                    <div class="form-group">
                        <label class="form-label" for="confirmPassword">Confirm Password</label>
                        <div class="form-input-wrapper">
                            <input type="password" id="confirmPassword" class="form-input" placeholder="Confirm password" required>
                            <button type="button" class="password-toggle" onclick="togglePassword('confirmPassword')">👁️</button>
                        </div>
                        <div class="form-error">Passwords do not match</div>
                    </div>

                    <!-- Submit -->
                    <button type="submit" class="btn btn-primary btn-lg btn-full">Create Account</button>
                </form>

                <!-- Divider -->
                <div class="divider">
                    <span class="divider-text">or</span>
                </div>

                <!-- Social Login (optional) -->
                <button class="btn btn-secondary btn-full mb-4">
                    <svg width="20" height="20" viewBox="0 0 20 20"><!-- Google icon --></svg>
                    Continue with Google
                </button>

                <!-- Footer Link -->
                <p style="text-align: center; font-size: var(--text-sm); color: var(--color-burgundy); margin-top: var(--space-6);">
                    Already have an account?
                    <a href="login-v2.html" style="color: var(--color-gold); font-weight: var(--font-semibold);">Log in</a>
                </p>
            </div>
        </div>
    </div>

    <script>
        function togglePassword(id) {
            const input = document.getElementById(id);
            input.type = input.type === 'password' ? 'text' : 'password';
        }

        document.getElementById('signupForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = e.target.querySelector('button[type="submit"]');
            btn.classList.add('btn-loading');

            // Your signup logic here using /js/shared.js functions
            // Example:
            // const email = document.getElementById('email').value;
            // const password = document.getElementById('password').value;
            // await handleSignup(email, password);

            setTimeout(() => {
                btn.classList.remove('btn-loading');
                window.location.href = 'onboarding-v2.html';
            }, 2000);
        });
    </script>
</body>
</html>
```

---

### Dashboard Page Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Bride Buddy</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Montserrat:wght@300;400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="/css/styles-luxury.css">
    <link rel="stylesheet" href="/css/components-luxury.css">
</head>
<body>
    <div class="bg-sunset">

        <!-- Top Navbar -->
        <nav class="navbar">
            <div class="navbar-container">
                <img src="/images/logo.svg" alt="Bride Buddy" class="navbar-logo">

                <div class="navbar-center">
                    <div class="navbar-wedding-name">Sarah & John - June 15, 2026</div>
                </div>

                <div class="navbar-menu">
                    <button class="navbar-user-button" id="userMenuBtn">
                        <div class="navbar-avatar">SJ</div>
                        <span>Sarah</span>
                    </button>

                    <div class="dropdown-menu" id="userDropdown">
                        <a href="#" class="dropdown-item">👤 Profile</a>
                        <a href="#" class="dropdown-item">⚙️ Settings</a>
                        <div class="dropdown-divider"></div>
                        <button class="dropdown-item" onclick="logout()">🚪 Log Out</button>
                    </div>
                </div>
            </div>
        </nav>

        <!-- Sidebar -->
        <aside class="sidebar" id="sidebar">
            <nav class="sidebar-nav">
                <ul>
                    <li class="sidebar-item">
                        <a href="dashboard.html" class="sidebar-link is-active">
                            <span class="sidebar-icon">🏠</span>
                            Dashboard
                        </a>
                    </li>
                    <li class="sidebar-item">
                        <a href="chat.html" class="sidebar-link">
                            <span class="sidebar-icon">💬</span>
                            AI Chat
                        </a>
                    </li>
                    <li class="sidebar-item">
                        <a href="team.html" class="sidebar-link">
                            <span class="sidebar-icon">👥</span>
                            Team
                        </a>
                    </li>
                    <li class="sidebar-item">
                        <a href="invite.html" class="sidebar-link">
                            <span class="sidebar-icon">✉️</span>
                            Invites
                        </a>
                    </li>
                    <li class="sidebar-item">
                        <a href="settings.html" class="sidebar-link">
                            <span class="sidebar-icon">⚙️</span>
                            Settings
                        </a>
                    </li>
                </ul>
            </nav>
        </aside>

        <!-- Main Content -->
        <main id="main-content" style="margin-left: 260px; padding: var(--space-6); min-height: calc(100vh - 72px);">

            <!-- Welcome Message -->
            <h1 style="margin-bottom: var(--space-6);">Welcome back, Sarah!</h1>

            <!-- Quick Stats -->
            <div class="grid grid-cols-3 gap-6" style="margin-bottom: var(--space-8);">
                <!-- Days Until Wedding -->
                <div class="card">
                    <p style="font-size: var(--text-sm); color: var(--color-burgundy); margin-bottom: var(--space-2);">Days Until Wedding</p>
                    <h2 style="font-size: var(--text-5xl); color: var(--color-gold); margin: 0;">247</h2>
                </div>

                <!-- Team Members -->
                <div class="card">
                    <p style="font-size: var(--text-sm); color: var(--color-burgundy); margin-bottom: var(--space-2);">Team Members</p>
                    <div style="display: flex; align-items: center; gap: var(--space-3);">
                        <h2 style="font-size: var(--text-5xl); color: var(--color-gold); margin: 0;">5</h2>
                        <div class="avatar-group">
                            <div class="avatar avatar-gold avatar-sm">SJ</div>
                            <div class="avatar avatar-gold avatar-sm">MK</div>
                            <div class="avatar avatar-gold avatar-sm">AB</div>
                        </div>
                    </div>
                </div>

                <!-- Tasks Completed -->
                <div class="card">
                    <p style="font-size: var(--text-sm); color: var(--color-burgundy); margin-bottom: var(--space-2);">Tasks Completed</p>
                    <h2 style="font-size: var(--text-5xl); color: var(--color-gold); margin: 0;">32/50</h2>
                    <div class="progress" style="margin-top: var(--space-3);">
                        <div class="progress-bar" style="width: 64%;"></div>
                    </div>
                </div>
            </div>

            <!-- Recent Activity -->
            <div class="card" style="margin-bottom: var(--space-8);">
                <h3 style="margin-bottom: var(--space-4);">Recent Activity</h3>

                <div style="display: flex; flex-direction: column; gap: var(--space-4);">
                    <div style="display: flex; gap: var(--space-3); padding: var(--space-3); background: var(--color-cream); border-radius: var(--radius-md);">
                        <div class="avatar avatar-gold avatar-sm">MK</div>
                        <div>
                            <p style="margin: 0; font-size: var(--text-sm); color: var(--color-navy);"><strong>Mary</strong> added vendor: Elegant Florals</p>
                            <p style="margin: 0; font-size: var(--text-xs); color: var(--color-burgundy); opacity: 0.7;">2 hours ago</p>
                        </div>
                    </div>

                    <div style="display: flex; gap: var(--space-3); padding: var(--space-3); background: var(--color-cream); border-radius: var(--radius-md);">
                        <div class="avatar avatar-gold avatar-sm">AB</div>
                        <div>
                            <p style="margin: 0; font-size: var(--text-sm); color: var(--color-navy);"><strong>Alex</strong> updated guest list</p>
                            <p style="margin: 0; font-size: var(--text-xs); color: var(--color-burgundy); opacity: 0.7;">5 hours ago</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card">
                <h3 style="margin-bottom: var(--space-4);">Quick Actions</h3>
                <div style="display: flex; gap: var(--space-3); flex-wrap: wrap;">
                    <a href="chat.html" class="btn btn-primary">💬 Chat with AI</a>
                    <a href="invite.html" class="btn btn-secondary">✉️ Invite Someone</a>
                    <button class="btn btn-secondary">✓ Add Task</button>
                </div>
            </div>
        </main>

        <!-- Mobile Bottom Nav -->
        <nav class="bottom-nav">
            <a href="dashboard.html" class="bottom-nav-item is-active">
                <span class="bottom-nav-icon">🏠</span>
                Home
            </a>
            <a href="chat.html" class="bottom-nav-item">
                <span class="bottom-nav-icon">💬</span>
                Chat
            </a>
            <a href="team.html" class="bottom-nav-item">
                <span class="bottom-nav-icon">👥</span>
                Team
            </a>
            <a href="settings.html" class="bottom-nav-item">
                <span class="bottom-nav-icon">⚙️</span>
                Settings
            </a>
        </nav>
    </div>

    <script>
        // Dropdown toggle
        const userMenuBtn = document.getElementById('userMenuBtn');
        const userDropdown = document.getElementById('userDropdown');

        userMenuBtn.addEventListener('click', () => {
            userDropdown.classList.toggle('is-active');
        });

        // Close dropdown when clicking outside
        document.addEventListener('click', (e) => {
            if (!userMenuBtn.contains(e.target) && !userDropdown.contains(e.target)) {
                userDropdown.classList.remove('is-active');
            }
        });

        // Mobile sidebar toggle
        // Add hamburger button and toggle logic as needed
    </script>
</body>
</html>
```

---

## 🔌 Integration with Existing Code

### Using Shared JavaScript Functions

Your existing `/js/shared.js` module can be integrated:

```html
<script src="/js/shared.js" type="module"></script>
<script type="module">
    import {
        initSupabase,
        loadWeddingData,
        displayMessage,
        navigateTo,
        logout
    } from '/js/shared.js';

    const supabase = initSupabase();

    // Use functions
    async function init() {
        const { wedding, weddingId } = await loadWeddingData();
        console.log('Wedding loaded:', wedding);
    }

    init();
</script>
```

### Connecting to API Endpoints

```javascript
// Example: Signup Form
document.getElementById('signupForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const btn = e.target.querySelector('button[type="submit"]');
    btn.classList.add('btn-loading');

    try {
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        const fullName = document.getElementById('fullName').value;

        // Use existing Supabase functions from shared.js
        const supabase = initSupabase();
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                data: { full_name: fullName }
            }
        });

        if (error) throw error;

        // Show success toast
        showToast('success', 'Account Created!', 'Redirecting to onboarding...');

        // Redirect
        setTimeout(() => {
            window.location.href = 'onboarding-v2.html';
        }, 1500);

    } catch (error) {
        console.error('Signup error:', error);
        showToast('error', 'Signup Failed', error.message);
    } finally {
        btn.classList.remove('btn-loading');
    }
});
```

---

## 📱 Responsive Design

### Mobile-First Approach

All components are built mobile-first. Use breakpoints to adjust layouts:

```css
/* Mobile: Base styles */
.card-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--space-4);
}

/* Tablet: 768px+ */
@media (min-width: 768px) {
    .card-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

/* Desktop: 1024px+ */
@media (min-width: 1024px) {
    .card-grid {
        grid-template-columns: repeat(3, 1fr);
    }

    /* Show sidebar */
    .sidebar {
        transform: translateX(0);
    }

    /* Hide bottom nav */
    .bottom-nav {
        display: none;
    }
}
```

---

## ♿ Accessibility Checklist

- ✅ Semantic HTML5 elements
- ✅ ARIA labels on interactive elements
- ✅ Keyboard navigation support
- ✅ Focus visible styles (`:focus-visible`)
- ✅ Sufficient color contrast (WCAG AA compliant)
- ✅ Alt text on images
- ✅ Skip to main content link
- ✅ Screen reader friendly
- ✅ Reduced motion support

---

## 🚀 Next Steps

### Pages to Build (using templates above)

1. ✅ **Landing Page** - `index-luxury.html` (Complete)
2. **Signup Page** - Use template above
3. **Login Page** - Similar to signup, simpler form
4. **Dashboard** - Use dashboard template above
5. **Chat Interface** - Build chat UI with message bubbles
6. **Bestie Dashboard** - Similar to dashboard + permission controls
7. **Invite Creation** - Form with role selector
8. **Accept Invite** - Display invite details + accept button
9. **Team Page** - Grid of team member cards
10. **Settings Page** - Tabs with form sections
11. **Pricing Modal** - Three-column pricing cards

### Quick Start Guide

1. **Copy HTML template structure**
2. **Choose background**: `.bg-sunset` or `.bg-sunset`
3. **Add components from library**: Cards, buttons, forms, etc.
4. **Style with utility classes**: `.flex`, `.grid`, spacing utilities
5. **Add interactivity with vanilla JavaScript**
6. **Test responsiveness** at all breakpoints
7. **Check accessibility** with keyboard and screen reader

---

## 📝 Component Customization

### Creating Custom Variants

```css
/* Example: Custom card variant */
.card-premium {
    background: linear-gradient(135deg, var(--color-cream-98), var(--color-gold-10));
    border: 3px solid var(--color-gold);
    box-shadow: var(--shadow-2xl), var(--glow-gold-strong);
}

/* Example: Custom button */
.btn-danger {
    background: var(--color-rust);
    color: var(--color-white);
}

.btn-danger:hover {
    background: #A04A32;
}
```

---

## 🎯 Best Practices

1. **Use CSS Variables** - Always use design tokens from `:root`
2. **Component First** - Build with reusable components
3. **Mobile First** - Design for mobile, enhance for desktop
4. **Semantic HTML** - Use proper HTML5 elements
5. **Accessibility** - Test with keyboard and screen readers
6. **Performance** - Lazy load images, minimize CSS
7. **Consistency** - Follow the design system strictly

---

## 🐛 Troubleshooting

### Buttons not showing hover effects
- Ensure you're using `.btn` base class
- Check that transitions are not disabled by reduced motion preference

### Cards not showing frosted glass effect
- Verify backdrop-filter support in browser
- Add `-webkit-backdrop-filter` for Safari

### Sidebar not hiding on mobile
- Check media query breakpoints
- Ensure `.sidebar.is-open` class is being toggled

### Modals not centering
- Verify `.modal-backdrop` has `display: flex; align-items: center; justify-content: center;`
- Check that `.modal` doesn't have conflicting positioning

---

## 📚 Additional Resources

- [Google Fonts - Playfair Display](https://fonts.google.com/specimen/Playfair+Display)
- [Google Fonts - Montserrat](https://fonts.google.com/specimen/Montserrat)
- [CSS Backdrop Filter](https://developer.mozilla.org/en-US/docs/Web/CSS/backdrop-filter)
- [WCAG Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

---

## 💬 Support

For questions or assistance with the UI system:
1. Review this README thoroughly
2. Check component examples above
3. Inspect `index-luxury.html` for reference
4. Review CSS files for available classes

---

**Built with love for Bride Buddy** 💍✨

*Design System v1.0 - Luxury Botanical-Tech Aesthetic*
