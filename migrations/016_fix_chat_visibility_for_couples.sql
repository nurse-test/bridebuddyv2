-- Migration 016: Fix Chat Message Visibility for Owner/Partner
-- ============================================================================
-- Purpose: Allow owner and partner to see each other's main chat messages
-- while keeping bestie chat private
-- ============================================================================

-- Drop existing policy
DROP POLICY IF EXISTS "Users can view own chat messages" ON chat_messages;

-- Create new policy that allows couples to share main chat
CREATE POLICY "Users can view wedding chat messages"
ON chat_messages FOR SELECT
TO authenticated
USING (
  -- Must be a member of the wedding
  wedding_id IN (
    SELECT wedding_id
    FROM wedding_members
    WHERE user_id = auth.uid()
  )
  AND (
    -- Can always see own messages
    user_id = auth.uid()
    OR
    -- Owner/Partner can see each other's 'main' messages (shared planning)
    (
      message_type = 'main'
      AND EXISTS (
        SELECT 1 FROM wedding_members
        WHERE wedding_id = chat_messages.wedding_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'partner')
      )
    )
  )
);

-- Add comment explaining the policy
COMMENT ON POLICY "Users can view wedding chat messages" ON chat_messages IS
'Allows users to see their own messages. Owner and partner can see each others main (shared planning) messages, but bestie messages remain private.';
