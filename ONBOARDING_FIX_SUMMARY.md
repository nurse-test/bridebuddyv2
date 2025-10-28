# Onboarding Flow Fix - Immediate Wedding Creation

## Issue Reported

Users who create an account but don't complete the full onboarding flow end up in a broken state:
- Profile is created but `is_owner = false`
- No wedding record is created
- User can't access the app properly
- Users get stuck in redirect loops

## Root Cause

The original implementation required users to complete ALL onboarding questions before a wedding profile was created. This meant:

1. **Abandoned onboarding = no access**: Users who created accounts but didn't finish all questions had no wedding profile
2. **Forced completion**: Users couldn't skip onboarding even though they could fill in details through chat later
3. **Bad UX**: Users had to answer questions before accessing any part of the app

## Solution Implemented

### Key Change: Wedding Created Immediately After Signup

**New Flow:**
1. User creates account (slide 1)
2. **Wedding profile is IMMEDIATELY created** with minimal data
3. User gets `is_owner = true` in their profile
4. User can now **skip remaining onboarding questions** and access the app
5. Remaining onboarding questions just UPDATE the existing wedding profile
6. Users can fill in details through chat interface instead

This matches the user's requirement: *"Onboarding does not have to be completed for a wedding ID to be assigned to the owner. Onboarding can easily be completed through the chat interface as the details come up."*

### Implementation Details

#### 1. Immediate Wedding Creation (onboarding-luxury.html)

**Function: `createAccount()`** (lines 532-575)
- After successful account creation, immediately calls `createInitialWedding()`
- Shows toast: "Account created! You can now skip to your dashboard or continue to add more details."

**Function: `createInitialWedding()`** (lines 577-623)
- Creates wedding profile with minimal data (just user's name)
- Stores wedding_id in `onboardingData.weddingId`
- Doesn't block user if this fails (but logs warning)
- User can now access the app

#### 2. Onboarding Questions Now Update (Not Create)

**Function: `createWedding()`** (lines 625-711) - RENAMED/REPURPOSED
- Now UPDATES the existing wedding profile instead of creating one
- Gets wedding_id from `onboardingData.weddingId` or from database
- Updates fields: `wedding_name`, `engagement_date`, `started_planning`, `planning_completed`
- Falls back to creating wedding if somehow one doesn't exist (legacy safety)
- Redirects to dashboard at the end

#### 3. Session Detection Handles All Cases

**Function: `checkExistingSession()`** (lines 310-357)
- **User with account + wedding**: Redirects to dashboard immediately
- **User with account but no wedding** (legacy): Creates wedding now, shows slide 2
- **New user**: Normal onboarding flow

#### 4. Profile Gets is_owner Set (api/create-wedding.js)

**Step 8** (lines 209-221)
- After creating wedding and adding member, sets `is_owner = true` in profile
- Ensures access control works correctly

#### 5. Redirect Logic (public/js/shared.js)

**Function: `loadWeddingData()`** (lines 316-328)
- Users without weddings get redirected to onboarding (not welcome page)
- But with new flow, this should rarely/never happen

## User Flow Scenarios

### Scenario 1: New User - Complete Onboarding
1. User enters email/password (slide 1) → moves to slide 2
2. **Wedding created automatically ✅**
3. User answers slides 2-5 about couple info, engagement, planning status
4. User selects planning status → redirects to dashboard
5. Wedding profile is updated with onboarding details ✅

### Scenario 2: New User - Skip Onboarding
1. User enters email/password (slide 1) → moves to slide 2
2. **Wedding created automatically ✅**
3. User closes browser or navigates away
4. User later accesses chat/dashboard directly
5. **User can access app and fill in details through chat ✅**

### Scenario 3: Returning User
1. User with account+wedding goes to onboarding page
2. Detected immediately, redirected to dashboard ✅
3. Shows: "Redirecting to your dashboard..."

### Scenario 4: Legacy User (Account but No Wedding)
1. User somehow has account but no wedding (shouldn't happen with new flow)
2. Session detection creates wedding for them
3. User can continue with onboarding or skip to dashboard ✅

## Database Changes

### profiles Table
```sql
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_owner BOOLEAN DEFAULT false;
```

Set by `api/create-wedding.js` when wedding is created.

### No Other Schema Changes Required
All other columns already exist in `wedding_profiles` table.

## Files Modified

1. **`public/onboarding-luxury.html`** - Major changes:
   - Added `createInitialWedding()` function (lines 577-623)
   - Modified `createAccount()` to call it immediately (line 562)
   - Renamed/repurposed `createWedding()` to update instead of create (lines 625-711)
   - Updated session detection logic (lines 310-357)
   - Added `weddingId` to onboardingData (line 305)

2. **`api/create-wedding.js`** - Set is_owner:
   - Added step 8 to set `is_owner = true` after wedding creation (lines 209-221)
   - Added `is_owner: false` when creating profiles (line 105)

3. **`public/js/shared.js`** - Better redirect:
   - Updated `loadWeddingData()` to redirect to onboarding instead of welcome (lines 316-328)

4. **`database_init.sql`** - Added is_owner column:
   - Added `is_owner BOOLEAN DEFAULT false` to profiles table
   - Updated trigger to include is_owner

5. **`migrations/019_add_is_owner_to_profiles.sql`** - NEW:
   - Migration to add is_owner column (if doesn't exist)
   - Backfills existing owners

## Benefits

✅ **No broken states**: Users always have a wedding profile after signup
✅ **Better UX**: Users can skip onboarding and fill details through chat
✅ **Immediate access**: Users can use app right after account creation
✅ **Flexible**: Onboarding questions are optional enhancements, not blockers
✅ **Backward compatible**: Handles legacy users without weddings
✅ **Proper access control**: `is_owner` field correctly set

## Testing

1. **Test immediate wedding creation**:
   - Create account (slide 1)
   - Check database - wedding_profiles should have new record
   - Check profiles - is_owner should be true

2. **Test skipping onboarding**:
   - Create account
   - Close browser after slide 2
   - Access chat-luxury.html directly
   - Should work! ✅

3. **Test completing onboarding**:
   - Create account
   - Complete all slides
   - Check wedding_profiles - should have onboarding data
   - Should redirect to dashboard ✅

4. **Test returning user**:
   - User with wedding goes to onboarding
   - Should redirect to dashboard immediately ✅

## Deployment

1. **Run migration (if needed)**:
   ```sql
   -- Only if is_owner doesn't exist in profiles
   -- Execute migrations/019_add_is_owner_to_profiles.sql
   ```

2. **Deploy code**:
   - Push all modified files
   - Test signup flow end-to-end

3. **Verify**:
   - New signups get wedding profiles immediately
   - Users can skip onboarding questions
   - is_owner is set correctly
