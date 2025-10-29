# COMPLETE DATABASE SCHEMA

**Generated:** 2025-10-29
**Source:** Based on `database_init.sql` and all migration files

This document shows ALL tables in the Bride Buddy database with their complete column structures after all migrations have been applied.

---

## Table of Contents

1. [Core Tables](#core-tables)
   - profiles
   - wedding_profiles
   - wedding_members
2. [Communication Tables](#communication-tables)
   - chat_messages
   - pending_updates
3. [Invite System](#invite-system)
   - invite_codes
4. [Bestie System](#bestie-system)
   - bestie_permissions
   - bestie_knowledge
   - bestie_profile
5. [Wedding Planning Tables](#wedding-planning-tables)
   - vendor_tracker
   - budget_tracker
   - wedding_tasks

---

## Core Tables

### 1. `profiles`
User profile information linked to Supabase auth.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY, REFERENCES auth.users(id) ON DELETE CASCADE | User ID from Supabase Auth |
| full_name | TEXT | | User's full name |
| email | TEXT | | User's email address |
| is_owner | BOOLEAN | DEFAULT false | Whether user is a wedding owner |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Account creation timestamp |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update timestamp |

**Indexes:**
- `profiles_id_idx` on (id)
- `profiles_is_owner_idx` on (is_owner)

---

### 2. `wedding_profiles`
Main wedding information and subscription details.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Wedding profile ID |
| owner_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | Primary wedding owner |
| **Basic Wedding Info** |
| wedding_name | TEXT | | Name/title of the wedding |
| partner1_name | TEXT | | First partner's name |
| partner2_name | TEXT | | Second partner's name |
| wedding_date | DATE | | Wedding date |
| wedding_time | TIME | | Wedding time |
| engagement_date | DATE | | When the couple got engaged |
| **Location Info** |
| ceremony_location | TEXT | | Where the ceremony will be held |
| reception_location | TEXT | | Where the reception will be held |
| venue_name | TEXT | | Venue name |
| venue_cost | NUMERIC(10, 2) | | Cost of the venue |
| **Planning Details** |
| expected_guest_count | INTEGER | | Expected number of guests |
| total_budget | NUMERIC(10, 2) | | Total wedding budget |
| wedding_style | TEXT | | Wedding style (e.g., rustic, modern, classic) |
| color_scheme_primary | TEXT | | Primary color scheme |
| color_scheme_secondary | TEXT | | Secondary color scheme |
| started_planning | BOOLEAN | DEFAULT false | Whether planning has started |
| planning_completed | JSONB | DEFAULT '[]'::jsonb | Array of completed planning items |
| **Vendor Info (Legacy - use vendor_tracker instead)** |
| photographer_name | TEXT | | Photographer name |
| photographer_cost | NUMERIC(10, 2) | | Photographer cost |
| caterer_name | TEXT | | Caterer name |
| caterer_cost | NUMERIC(10, 2) | | Caterer cost |
| florist_name | TEXT | | Florist name |
| florist_cost | NUMERIC(10, 2) | | Florist cost |
| dj_band_name | TEXT | | DJ/Band name |
| dj_band_cost | NUMERIC(10, 2) | | DJ/Band cost |
| baker_name | TEXT | | Baker name |
| cake_flavors | TEXT | | Cake flavors |
| **Subscription Management** |
| plan_type | TEXT | CHECK (plan_type IN ('trial', 'free', 'basic', 'premium', 'enterprise')) | Subscription plan type |
| subscription_status | TEXT | CHECK (subscription_status IN ('trialing', 'active', 'past_due', 'canceled', 'unpaid')) | Current subscription status |
| trial_start_date | TIMESTAMPTZ | | Trial period start |
| trial_end_date | TIMESTAMPTZ | | Trial period end |
| subscription_start_date | TIMESTAMPTZ | | Paid subscription start |
| subscription_end_date | TIMESTAMPTZ | | Subscription expiration (or wedding_date for "Until I Do") |
| bestie_addon_enabled | BOOLEAN | DEFAULT FALSE | Whether Bestie AI addon is enabled |
| is_vip | BOOLEAN | DEFAULT FALSE | VIP status |
| **Stripe Integration** |
| stripe_customer_id | TEXT | | Stripe customer ID |
| stripe_subscription_id | TEXT | | Stripe subscription ID |
| **Timestamps** |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Profile creation timestamp |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update timestamp |

**Indexes:**
- `wedding_profiles_owner_id_idx` on (owner_id)
- `wedding_profiles_created_at_idx` on (created_at DESC)
- `wedding_profiles_engagement_date_idx` on (engagement_date)

**Triggers:**
- `trigger_update_wedding_profiles_updated_at` - Auto-updates `updated_at` on changes

---

### 3. `wedding_members`
Links users to weddings with their roles and permissions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding ID |
| user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | User ID |
| role | TEXT | NOT NULL CHECK (role IN ('owner', 'partner', 'bestie')) | User's role in the wedding |
| invited_by_user_id | UUID | REFERENCES auth.users(id) ON DELETE SET NULL | Who invited this user |
| wedding_profile_permissions | JSONB | DEFAULT '{"can_read": false, "can_edit": false}'::jsonb | Permissions for wedding profile |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | When user joined wedding |

**Primary Key:** (wedding_id, user_id)

**Indexes:**
- `wedding_members_user_id_idx` on (user_id)
- `wedding_members_wedding_id_idx` on (wedding_id)
- `wedding_members_role_idx` on (role)
- `wedding_members_invited_by_idx` on (invited_by_user_id)
- `wedding_members_created_at_idx` on (created_at DESC)

**Constraints:**
- Role must be 'owner', 'partner', or 'bestie'
- wedding_profile_permissions must be valid JSON with can_read and can_edit fields

---

## Communication Tables

### 4. `chat_messages`
Stores chat messages between users and AI assistants.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Message ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this message belongs to |
| user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | User who sent/received message |
| message | TEXT | NOT NULL | Message content |
| role | TEXT | NOT NULL CHECK (role IN ('user', 'assistant')) | Who sent the message |
| message_type | TEXT | NOT NULL CHECK (message_type IN ('main', 'bestie')) | Main chat or Bestie chat |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Message timestamp |

**Indexes:**
- `chat_messages_wedding_id_idx` on (wedding_id)
- `chat_messages_user_id_idx` on (user_id)
- `chat_messages_created_at_idx` on (created_at DESC)

---

### 5. `pending_updates`
Tracks pending changes to wedding profiles that need approval.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Update ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding being updated |
| user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | User who proposed the update |
| field_name | TEXT | NOT NULL | Field to be updated |
| old_value | TEXT | | Current value |
| new_value | TEXT | | Proposed new value |
| status | TEXT | NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')) | Update status |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | When update was proposed |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last status change |

**Indexes:**
- Created via database_init.sql

---

## Invite System

### 6. `invite_codes`
One-time-use invite links for partner, co-planner, and bestie roles.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Invite ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding for this invite |
| code | TEXT | UNIQUE | Legacy code field |
| invite_token | TEXT | NOT NULL UNIQUE | Unique invite token (replaces code) |
| role | TEXT | CHECK (role IN ('partner', 'co_planner', 'bestie')) | Role being invited for |
| created_by | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | Who created the invite |
| is_used | BOOLEAN | DEFAULT FALSE | Whether invite has been used |
| used_by | UUID | REFERENCES auth.users(id) ON DELETE SET NULL | Who used the invite |
| wedding_profile_permissions | JSONB | DEFAULT '{"read": false, "edit": false}'::jsonb | Permissions granted by this invite |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Invite creation time |
| used_at | TIMESTAMPTZ | | When invite was used |
| expires_at | TIMESTAMPTZ | NOT NULL | Invite expiration (7 days from creation) |

**Indexes:**
- Created via database_init.sql

**Note:** Invites expire after 7 days and can only be used once.

---

## Bestie System

### 7. `bestie_permissions`
Permissions that besties have for specific weddings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Permission record ID |
| bestie_user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | The bestie user |
| inviter_user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | Who invited the bestie |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding these permissions apply to |
| permissions | JSONB | NOT NULL DEFAULT '{"can_read": false, "can_edit": false, "can_suggest": false}'::jsonb | Detailed permissions |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Permission creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last permission update |

**Indexes:**
- Created via migration 002

**Note:** Fixed permissions based on role. Besties have read-only access by default.

---

### 8. `bestie_knowledge`
Stores notes and knowledge that besties share about the wedding.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Knowledge entry ID |
| bestie_user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | Bestie who created this |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this knowledge is about |
| content | TEXT | NOT NULL | The knowledge/note content |
| knowledge_type | TEXT | NOT NULL DEFAULT 'note' | Type of knowledge entry |
| is_private | BOOLEAN | DEFAULT FALSE | Whether visible only to bestie |
| metadata | JSONB | DEFAULT '{}'::jsonb | Additional metadata |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Entry creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update time |

**Indexes:**
- Created via migration 003

---

### 9. `bestie_profile`
Extended profile information for besties.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Profile ID |
| bestie_user_id | UUID | NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE | The bestie user |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this profile is for |
| bestie_brief | TEXT | | Information about the bestie's role/relationship |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Profile creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update time |

**Indexes:**
- Created via migration 015

**Unique Constraint:** (bestie_user_id, wedding_id) - One profile per bestie per wedding

---

## Wedding Planning Tables

### 10. `vendor_tracker`
Detailed vendor management with deposits, payments, and status tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Vendor entry ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this vendor is for |
| **Vendor Details** |
| vendor_type | TEXT | NOT NULL | photographer, caterer, florist, dj, baker, venue, planner, etc. |
| vendor_name | TEXT | NOT NULL | Vendor business name |
| vendor_contact_name | TEXT | | Contact person name |
| vendor_email | TEXT | | Vendor email |
| vendor_phone | TEXT | | Vendor phone |
| vendor_website | TEXT | | Vendor website |
| **Financial Tracking** |
| total_cost | NUMERIC(10, 2) | | Total cost for this vendor |
| deposit_amount | NUMERIC(10, 2) | | Deposit amount required |
| deposit_paid | BOOLEAN | DEFAULT false | Whether deposit has been paid |
| deposit_date | DATE | | When deposit was/will be paid |
| balance_due | NUMERIC(10, 2) | | Remaining balance |
| final_payment_date | DATE | | When final payment is due |
| final_payment_paid | BOOLEAN | DEFAULT false | Whether final payment is complete |
| **Status and Timeline** |
| status | TEXT | CHECK (status IN ('inquiry', 'pending', 'booked', 'contract_signed', 'deposit_paid', 'fully_paid', 'rejected', 'cancelled')) DEFAULT 'inquiry' | Vendor status |
| contract_signed | BOOLEAN | DEFAULT false | Whether contract is signed |
| contract_date | DATE | | When contract was signed |
| service_date | DATE | | When service will be provided |
| **Additional Info** |
| notes | TEXT | | Additional notes |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Entry creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update time |

**Indexes:**
- `idx_vendor_tracker_wedding_id` on (wedding_id)
- `idx_vendor_tracker_vendor_type` on (wedding_id, vendor_type)

**Triggers:**
- `vendor_tracker_updated_at` - Auto-updates `updated_at` on changes

**RLS Policies:**
- Users can view/create/update/delete vendors for weddings they're members of

---

### 11. `budget_tracker`
Budget management by category with spending analysis.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Budget entry ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this budget is for |
| **Budget Category** |
| category | TEXT | NOT NULL | venue, catering, flowers, photography, videography, music, cake, decorations, attire, invitations, favors, transportation, honeymoon, other |
| **Financial Tracking** |
| budgeted_amount | NUMERIC(10, 2) | DEFAULT 0 | Amount budgeted for this category |
| spent_amount | NUMERIC(10, 2) | DEFAULT 0 | Amount spent so far |
| remaining_amount | NUMERIC(10, 2) | GENERATED ALWAYS AS (budgeted_amount - spent_amount) STORED | Calculated remaining budget |
| **Transaction Details** |
| last_transaction_date | DATE | | Date of most recent transaction |
| last_transaction_amount | NUMERIC(10, 2) | | Amount of most recent transaction |
| last_transaction_description | TEXT | | Description of most recent transaction |
| **Links** |
| vendor_id | UUID | REFERENCES vendor_tracker(id) ON DELETE SET NULL | Linked vendor (if applicable) |
| **Additional Info** |
| notes | TEXT | | Additional notes |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Entry creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update time |

**Indexes:**
- `idx_budget_tracker_wedding_id` on (wedding_id)
- `idx_budget_tracker_category` on (wedding_id, category)
- `idx_budget_tracker_unique_category` on (wedding_id, category) - UNIQUE

**Constraints:**
- One budget entry per category per wedding

**Triggers:**
- `budget_tracker_updated_at` - Auto-updates `updated_at` on changes

**RLS Policies:**
- Users can view/create/update/delete budget items for weddings they're members of

---

### 12. `wedding_tasks`
Timeline and task management for wedding planning.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY DEFAULT gen_random_uuid() | Task ID |
| wedding_id | UUID | NOT NULL REFERENCES wedding_profiles(id) ON DELETE CASCADE | Wedding this task is for |
| **Task Details** |
| task_name | TEXT | NOT NULL | Task name/title |
| task_description | TEXT | | Detailed description |
| category | TEXT | | venue, catering, flowers, photography, attire, invitations, decorations, transportation, legal, honeymoon, day-of, other |
| **Timeline Tracking** |
| due_date | DATE | | When task is due |
| completed_date | DATE | | When task was completed |
| status | TEXT | CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')) DEFAULT 'not_started' | Task status |
| **Assignment** |
| assigned_to | UUID | REFERENCES auth.users(id) ON DELETE SET NULL | Who is responsible for this task |
| **Priority** |
| priority | TEXT | CHECK (priority IN ('low', 'medium', 'high', 'urgent')) DEFAULT 'medium' | Task priority |
| **Links** |
| vendor_id | UUID | REFERENCES vendor_tracker(id) ON DELETE SET NULL | Linked vendor (if applicable) |
| **Additional Info** |
| notes | TEXT | | Additional notes |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | Task creation time |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | Last update time |

**Indexes:**
- `idx_wedding_tasks_wedding_id` on (wedding_id)
- `idx_wedding_tasks_status` on (wedding_id, status)
- `idx_wedding_tasks_due_date` on (wedding_id, due_date)
- `idx_wedding_tasks_assigned_to` on (assigned_to)

**Triggers:**
- `wedding_tasks_updated_at` - Auto-updates `updated_at` on changes

**RLS Policies:**
- Users can view/create/update/delete tasks for weddings they're members of

---

## Summary

**Total Tables:** 12

### By Category:
- **Core Tables:** 3 (profiles, wedding_profiles, wedding_members)
- **Communication:** 2 (chat_messages, pending_updates)
- **Invite System:** 1 (invite_codes)
- **Bestie System:** 3 (bestie_permissions, bestie_knowledge, bestie_profile)
- **Wedding Planning:** 3 (vendor_tracker, budget_tracker, wedding_tasks)

### Security:
- All tables have Row Level Security (RLS) enabled
- Users can only access data for weddings they're members of
- Permissions are role-based (owner, partner, bestie)
- Fixed permissions based on role (see FIXED_PERMISSIONS_SYSTEM.md)

### Data Integrity:
- Foreign key constraints ensure referential integrity
- Check constraints enforce valid enum values
- Unique constraints prevent duplicates
- Triggers auto-update timestamps
- Generated columns calculate derived values (e.g., remaining_amount in budget_tracker)

---

## How to Query the Live Database

### Option 1: Using Supabase SQL Editor
Copy and paste this query into your Supabase SQL Editor:

```sql
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
```

### Option 2: Using the provided SQL file
```bash
# In Supabase SQL Editor, run:
show_all_tables_schema.sql
```

### Option 3: Using Node.js (if you have credentials)
```bash
node inspect_database_schema.js
```

---

**Last Updated:** 2025-10-29
**Migration Version:** 022 (Fixed Role-Based Permissions)
