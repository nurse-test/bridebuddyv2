// Global interactions for Bride Buddy UI
const qs = (selector, scope = document) => scope.querySelector(selector);
const qsa = (selector, scope = document) => Array.from(scope.querySelectorAll(selector));

document.addEventListener('DOMContentLoaded', () => {
  setupSidebarToggle();
  setupPasswordToggles();
  setupChatInteractions();
  setupInviteRoleSelection();
  setupTabNavigation();
  setupCopyButtons();
});

function setupSidebarToggle() {
  const toggle = qs('[data-sidebar-toggle]');
  const sidebar = qs('.sidebar');
  if (!toggle || !sidebar) return;

  toggle.addEventListener('click', () => {
    sidebar.classList.toggle('open');
  });
}

function setupPasswordToggles() {
  qsa('[data-password-toggle]').forEach((button) => {
    button.addEventListener('click', () => {
      const input = button.closest('.input-with-icon')?.querySelector('input');
      if (!input) return;
      if (input.type === 'password') {
        input.type = 'text';
        button.innerHTML = '🙈';
      } else {
        input.type = 'password';
        button.innerHTML = '👁️';
      }
    });
  });
}

function setupChatInteractions() {
  const textarea = qs('[data-chat-input]');
  if (!textarea) return;

  textarea.addEventListener('input', () => {
    textarea.style.height = 'auto';
    textarea.style.height = `${textarea.scrollHeight}px`;
  });

  qsa('[data-quick-suggestion]').forEach((button) => {
    button.addEventListener('click', () => {
      textarea.value = `${textarea.value ? textarea.value + '\n' : ''}${button.dataset.quickSuggestion}`;
      textarea.dispatchEvent(new Event('input'));
      textarea.focus();
    });
  });
}

function setupInviteRoleSelection() {
  const roleCards = qsa('[data-role-select]');
  if (!roleCards.length) return;

  roleCards.forEach((card) => {
    card.addEventListener('click', () => {
      const selectedRole = card.dataset.roleSelect;
      roleCards.forEach((c) => c.classList.toggle('selected', c === card));
      const roleLabel = qs('[data-role-label]');
      if (roleLabel) roleLabel.textContent = card.dataset.roleName;
      qsa('[data-role-dependent]').forEach((section) => {
        const allowedRoles = section.dataset.roleDependent?.split(',') ?? [];
        section.classList.toggle('hidden', !allowedRoles.includes(selectedRole));
      });
    });
  });
}

function setupTabNavigation() {
  qsa('[data-tab-target]').forEach((tabButton) => {
    tabButton.addEventListener('click', () => {
      const targetId = tabButton.dataset.tabTarget;
      const container = tabButton.closest('[data-tabs]');
      if (!container) return;

      qsa('[data-tab-target]', container).forEach((btn) => btn.classList.toggle('active', btn === tabButton));
      qsa('[data-tab-panel]', container).forEach((panel) => {
        panel.classList.toggle('hidden', panel.id !== targetId);
      });
    });
  });
}

function setupCopyButtons() {
  qsa('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const targetSelector = button.dataset.copy;
      const target = qs(targetSelector);
      if (!target) return;

      try {
        await navigator.clipboard.writeText(target.textContent.trim());
        showToast('Invite link copied to clipboard', 'success');
      } catch (error) {
        console.error(error);
        showToast('Unable to copy link', 'error');
      }
    });
  });
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.setAttribute('role', 'status');
  toast.innerHTML = `
    <div>${message}</div>
    <button class="btn-text" aria-label="Close notification">Close</button>
  `;
  document.body.appendChild(toast);

  const close = toast.querySelector('button');
  const removeToast = () => {
    toast.classList.add('fade-out');
    setTimeout(() => toast.remove(), 220);
  };
  close.addEventListener('click', removeToast);

  setTimeout(removeToast, 5000);
}

window.showToast = showToast;
