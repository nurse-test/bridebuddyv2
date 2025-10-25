/**
 * Bride Buddy - Shared JavaScript Module
 * Common utilities and functions used across multiple pages
 */

// ============================================================================
// CONSTANTS
// ============================================================================

const SUPABASE_URL = 'https://nluvnjydydotsrpluhey.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sdXZuanlkeWRvdHNycGx1aGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjE5MjAsImV4cCI6MjA3NjMzNzkyMH0.p5S8vYtZeYqp24avigifhjEDRaKv8TxJTaTkeLoE5mY';

// Lazy Susan icon paths
const LAZY_SUSAN_ICONS = ['/i.png', '/i-2.png', '/i-3.png', '/i-4.png'];

// ============================================================================
// SUPABASE CLIENT
// ============================================================================

let supabaseClient = null;

/**
 * Initialize and return Supabase client (singleton pattern)
 * @returns {Object} Supabase client instance
 */
export function initSupabase() {
    if (!supabaseClient && window.supabase) {
        supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    }
    return supabaseClient;
}

/**
 * Get existing Supabase client instance
 * @returns {Object} Supabase client instance
 */
export function getSupabase() {
    if (!supabaseClient) {
        return initSupabase();
    }
    return supabaseClient;
}

// ============================================================================
// URL PARAMETER HELPERS
// ============================================================================

/**
 * Get URL parameter by name
 * @param {string} paramName - Name of the URL parameter
 * @returns {string|null} Parameter value or null if not found
 */
export function getUrlParam(paramName) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(paramName);
}

/**
 * Get wedding ID from URL
 * @returns {string|null} Wedding ID or null
 */
export function getWeddingIdFromUrl() {
    return getUrlParam('wedding_id');
}

/**
 * Update URL with wedding_id parameter
 * @param {string} weddingId - Wedding ID to add to URL
 */
export function updateUrlWithWeddingId(weddingId) {
    window.history.replaceState({}, '', `?wedding_id=${weddingId}`);
}

// ============================================================================
// LOADING INDICATOR (Lazy Susan Animation)
// ============================================================================

let currentIconIndex = 0;
let iconInterval = null;

/**
 * Start Lazy Susan icon cycling animation
 * @param {HTMLImageElement} imgElement - Image element to animate
 */
function startIconCycle(imgElement) {
    currentIconIndex = 0;
    imgElement.src = LAZY_SUSAN_ICONS[currentIconIndex];

    iconInterval = setInterval(() => {
        currentIconIndex = (currentIconIndex + 1) % LAZY_SUSAN_ICONS.length;
        imgElement.src = LAZY_SUSAN_ICONS[currentIconIndex];
    }, 1000); // Change icon every 1 second
}

/**
 * Stop Lazy Susan icon cycling animation
 */
function stopIconCycle() {
    if (iconInterval) {
        clearInterval(iconInterval);
        iconInterval = null;
    }
}

/**
 * Loading indicator utilities
 */
export const loadingIndicator = {
    /**
     * Show loading indicator with Lazy Susan animation
     * @param {string} containerId - ID of container to append loading indicator
     */
    show(containerId = 'chatMessages') {
        const messagesContainer = document.getElementById(containerId);
        if (!messagesContainer) {
            console.error(`Container with ID "${containerId}" not found`);
            return;
        }

        const loadingDiv = document.createElement('div');
        loadingDiv.id = 'loadingIndicator';
        loadingDiv.className = 'chat-loading';

        const lazySusan = document.createElement('div');
        lazySusan.className = 'lazy-susan';

        const icon = document.createElement('img');
        icon.className = 'lazy-susan-icon';
        icon.alt = 'Loading...';

        lazySusan.appendChild(icon);
        loadingDiv.appendChild(lazySusan);
        messagesContainer.appendChild(loadingDiv);

        // Start cycling through icons
        startIconCycle(icon);

        // Scroll to bottom
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    },

    /**
     * Hide loading indicator
     */
    hide() {
        stopIconCycle();
        const loadingIndicator = document.getElementById('loadingIndicator');
        if (loadingIndicator) {
            loadingIndicator.remove();
        }
    }
};

// ============================================================================
// CHAT MESSAGE DISPLAY
// ============================================================================

/**
 * Display message in chat container
 * @param {string} content - Message content (supports HTML)
 * @param {string} role - Message role ('user' or 'assistant')
 * @param {string} containerId - ID of chat container
 */
export function displayMessage(content, role = 'assistant', containerId = 'chatMessages') {
    const messagesContainer = document.getElementById(containerId);
    if (!messagesContainer) {
        console.error(`Container with ID "${containerId}" not found`);
        return;
    }

    const messageDiv = document.createElement('div');
    messageDiv.className = `chat-message ${role}`;

    const bubbleDiv = document.createElement('div');
    bubbleDiv.className = 'chat-bubble';
    bubbleDiv.innerHTML = content.replace(/\n/g, '<br>');

    messageDiv.appendChild(bubbleDiv);
    messagesContainer.appendChild(messageDiv);

    // Scroll to bottom
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

// ============================================================================
// NAVIGATION FUNCTIONS
// ============================================================================

/**
 * Navigate to a page with wedding_id parameter
 * @param {string} page - Page filename (e.g., 'dashboard-luxury.html')
 * @param {string|null} weddingId - Wedding ID (defaults to URL param)
 */
export function navigateTo(page, weddingId = null) {
    const id = weddingId || getWeddingIdFromUrl();
    if (id) {
        window.location.href = `${page}?wedding_id=${id}`;
    } else {
        window.location.href = page;
    }
}

/**
 * Navigate back to dashboard
 * @param {string|null} weddingId - Wedding ID (defaults to URL param)
 */
export function goToDashboard(weddingId = null) {
    navigateTo('dashboard-luxury.html', weddingId);
}

/**
 * Navigate back to welcome page
 */
export function goToWelcome() {
    window.location.href = 'index-luxury.html';
}

// ============================================================================
// AUTHENTICATION FUNCTIONS
// ============================================================================

/**
 * Logout user and redirect to welcome page
 */
export async function logout() {
    const supabase = getSupabase();
    await supabase.auth.signOut();
    goToWelcome();
}

/**
 * Check if user is authenticated
 * @returns {Promise<Object|null>} User session or null
 */
export async function checkAuth() {
    const supabase = getSupabase();
    const { data: { session } } = await supabase.auth.getSession();
    return session;
}

/**
 * Get current authenticated user
 * @returns {Promise<Object|null>} User object or null
 */
export async function getCurrentUser() {
    const supabase = getSupabase();
    const { data: { user } } = await supabase.auth.getUser();
    return user;
}

/**
 * Require authentication - redirect to welcome if not authenticated
 * @returns {Promise<Object>} User session
 */
export async function requireAuth() {
    const session = await checkAuth();
    if (!session) {
        goToWelcome();
        throw new Error('Not authenticated');
    }
    return session;
}

// ============================================================================
// WEDDING DATA LOADING
// ============================================================================

/**
 * Load wedding data and verify user access
 * @param {Object} options - Configuration options
 * @param {string} options.weddingId - Wedding ID (optional, will use URL param)
 * @param {boolean} options.requireAuth - Require authentication (default: true)
 * @param {boolean} options.redirectOnError - Redirect to welcome on error (default: true)
 * @returns {Promise<Object>} Wedding data object with { wedding, weddingId, member }
 */
export async function loadWeddingData(options = {}) {
    const {
        weddingId: providedWeddingId = null,
        requireAuth: shouldRequireAuth = true,
        redirectOnError = true
    } = options;

    try {
        const supabase = getSupabase();
        let weddingId = providedWeddingId || getWeddingIdFromUrl();

        // Check authentication
        const { data: { user } } = await supabase.auth.getUser();

        if (!user && shouldRequireAuth) {
            if (redirectOnError) {
                goToWelcome();
            }
            throw new Error('Not authenticated');
        }

        // If no wedding_id in URL, get it from user's membership
        if (!weddingId) {
            const { data: membership, error: memberError } = await supabase
                .from('wedding_members')
                .select('wedding_id')
                .eq('user_id', user.id)
                .single();

            console.log('Membership query result:', { membership, memberError, userId: user.id });

            if (memberError || !membership) {
                console.error('No wedding membership found for user:', user.id);
                console.error('Member error:', memberError);
                if (redirectOnError) {
                    alert('You need to create or join a wedding first.');
                    goToWelcome();
                }
                throw new Error('No wedding membership found');
            }

            weddingId = membership.wedding_id;
            console.log('Set weddingId to:', weddingId);

            // Update URL with wedding_id
            updateUrlWithWeddingId(weddingId);
        }

        // Extra safety check before querying
        if (!weddingId || weddingId === 'undefined' || weddingId === 'null') {
            console.error('Invalid wedding_id:', weddingId);
            if (redirectOnError) {
                alert('Unable to load wedding. Please create or join a wedding.');
                goToWelcome();
            }
            throw new Error('Invalid wedding_id');
        }

        console.log('Querying wedding_profiles with id:', weddingId);

        // Get wedding profile
        const { data: wedding, error } = await supabase
            .from('wedding_profiles')
            .select('*')
            .eq('id', weddingId)
            .single();

        if (error) {
            console.error('Error loading wedding:', error);
            throw error;
        }

        // Get member info
        const { data: member, error: memberError } = await supabase
            .from('wedding_members')
            .select('*')
            .eq('wedding_id', weddingId)
            .eq('user_id', user.id)
            .single();

        if (memberError) {
            console.error('Error loading member:', memberError);
        }

        return {
            wedding,
            weddingId,
            member,
            user
        };

    } catch (error) {
        console.error('Error in loadWeddingData:', error);
        throw error;
    }
}

// ============================================================================
// CHAT HISTORY LOADING
// ============================================================================

/**
 * Load chat history for a wedding
 * @param {Object} options - Configuration options
 * @param {string} options.weddingId - Wedding ID
 * @param {string} options.messageType - Message type filter ('main', 'bestie', etc.)
 * @param {number} options.limit - Maximum number of messages to load (default: 20)
 * @returns {Promise<Array>} Array of chat messages
 */
export async function loadChatHistory(options = {}) {
    const {
        weddingId,
        messageType = 'main',
        limit = 20
    } = options;

    if (!weddingId) {
        throw new Error('weddingId is required');
    }

    try {
        const supabase = getSupabase();
        const user = await getCurrentUser();

        if (!user) {
            throw new Error('User not authenticated');
        }

        const { data: messages, error } = await supabase
            .from('chat_messages')
            .select('*')
            .eq('wedding_id', weddingId)
            .eq('user_id', user.id)
            .eq('message_type', messageType)
            .order('created_at', { ascending: true })
            .limit(limit);

        if (error) {
            console.error('Error loading chat history:', error);
            throw error;
        }

        return messages || [];

    } catch (error) {
        console.error('Error in loadChatHistory:', error);
        throw error;
    }
}

/**
 * Display chat history in a container
 * @param {Array} messages - Array of message objects
 * @param {string} containerId - ID of container to display messages
 */
export function displayChatHistory(messages, containerId = 'chatMessages') {
    if (!messages || messages.length === 0) {
        return;
    }

    messages.forEach(msg => {
        if (msg.role === 'user' || msg.role === 'assistant') {
            displayMessage(msg.message, msg.role, containerId);
        }
    });
}

// ============================================================================
// FORM VALIDATION HELPERS
// ============================================================================

/**
 * Validate email format
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid
 */
export function isValidEmail(email) {
    return email && email.includes('@') && email.includes('.');
}

/**
 * Validate password strength
 * @param {string} password - Password to validate
 * @param {number} minLength - Minimum length (default: 6)
 * @returns {boolean} True if valid
 */
export function isValidPassword(password, minLength = 6) {
    return password && password.length >= minLength;
}

/**
 * Show form error message
 * @param {string} elementId - ID of error element
 * @param {string} message - Error message (optional)
 */
export function showFormError(elementId, message = null) {
    const errorElement = document.getElementById(elementId);
    if (errorElement) {
        if (message) {
            errorElement.textContent = message;
        }
        errorElement.style.display = 'block';
    }
}

/**
 * Hide form error message
 * @param {string} elementId - ID of error element
 */
export function hideFormError(elementId) {
    const errorElement = document.getElementById(elementId);
    if (errorElement) {
        errorElement.style.display = 'none';
    }
}

// ============================================================================
// MENU/MODAL HELPERS
// ============================================================================

/**
 * Toggle menu/modal visibility
 * @param {string} elementId - ID of element to toggle
 */
export function toggleMenu(elementId = 'menuOverlay') {
    const menu = document.getElementById(elementId);
    if (menu) {
        menu.classList.toggle('hidden');
    }
}

/**
 * Show element by removing 'hidden' class
 * @param {string} elementId - ID of element to show
 */
export function showElement(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.remove('hidden');
    }
}

/**
 * Hide element by adding 'hidden' class
 * @param {string} elementId - ID of element to hide
 */
export function hideElement(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.classList.add('hidden');
    }
}

// ============================================================================
// SUBSCRIPTION/TRIAL HELPERS
// ============================================================================

/**
 * Calculate days remaining in trial
 * @param {string} trialEndDate - Trial end date (ISO string)
 * @returns {number} Days remaining
 */
export function getDaysRemainingInTrial(trialEndDate) {
    const endDate = new Date(trialEndDate);
    const now = new Date();
    return Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
}

/**
 * Update trial badge with days remaining
 * @param {Object} wedding - Wedding object with trial_end_date
 * @param {string} badgeElementId - ID of badge element
 */
export function updateTrialBadge(wedding, badgeElementId = 'trialBadge') {
    const badgeElement = document.getElementById(badgeElementId);
    if (!badgeElement) return;

    if (wedding.subscription_status === 'trialing') {
        const daysLeft = getDaysRemainingInTrial(wedding.trial_end_date);

        badgeElement.textContent = `VIP Trial • ${daysLeft} days left`;

        if (daysLeft <= 2) {
            badgeElement.classList.remove('badge-trial');
            badgeElement.classList.add('badge-warning');
        }
    }
}

// ============================================================================
// TOAST NOTIFICATIONS
// ============================================================================

/**
 * Show toast notification
 * @param {string} message - Message to display
 * @param {string} type - Toast type: 'success', 'error', 'warning', 'info'
 * @param {number} duration - Duration in milliseconds (default: 3000)
 */
export function showToast(message, type = 'info', duration = 3000) {
    const container = document.getElementById('toastContainer') || createToastContainer();

    const toast = document.createElement('div');
    toast.className = `toast toast-${type} animate-fade-in-scale`;

    // Icon based on type
    const icons = {
        success: '✓',
        error: '✗',
        warning: '⚠',
        info: 'ℹ'
    };

    toast.innerHTML = `
        <span style="font-size: 1.25rem; margin-right: 0.5rem;">${icons[type] || icons.info}</span>
        <span>${message}</span>
    `;

    container.appendChild(toast);

    // Auto remove after duration
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(-1rem)';
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    }, duration);
}

/**
 * Create toast container if it doesn't exist
 * @returns {HTMLElement} Toast container element
 */
function createToastContainer() {
    let container = document.getElementById('toastContainer');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toastContainer';
        container.className = 'toast-container';
        document.body.appendChild(container);
    }
    return container;
}

// ============================================================================
// EXPORTS SUMMARY
// ============================================================================

// Default export for convenience
export default {
    // Supabase
    initSupabase,
    getSupabase,

    // URL helpers
    getUrlParam,
    getWeddingIdFromUrl,
    updateUrlWithWeddingId,

    // Loading indicator
    loadingIndicator,

    // Chat
    displayMessage,
    loadChatHistory,
    displayChatHistory,

    // Navigation
    navigateTo,
    goToDashboard,
    goToWelcome,

    // Auth
    logout,
    checkAuth,
    getCurrentUser,
    requireAuth,

    // Wedding data
    loadWeddingData,

    // Form validation
    isValidEmail,
    isValidPassword,
    showFormError,
    hideFormError,

    // UI helpers
    toggleMenu,
    showElement,
    hideElement,

    // Subscription helpers
    getDaysRemainingInTrial,
    updateTrialBadge,

    // Toast notifications
    showToast
};
