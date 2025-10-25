// Authentication helpers for Bride Buddy UI (placeholder implementation)

export function validateSignupForm(form) {
  const errors = {};
  const fullName = form.querySelector('[name="fullName"]').value.trim();
  const email = form.querySelector('[name="email"]').value.trim();
  const password = form.querySelector('[name="password"]').value;
  const confirm = form.querySelector('[name="confirmPassword"]').value;

  if (!fullName) errors.fullName = 'Please enter your full name';
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) errors.email = 'Enter a valid email address';
  if (!password || password.length < 8) errors.password = 'Password must be at least 8 characters';
  if (password !== confirm) errors.confirmPassword = 'Passwords do not match';

  return errors;
}

export function showFormErrors(form, errors) {
  form.querySelectorAll('.error-message').forEach((node) => node.remove());
  form.querySelectorAll('.error').forEach((field) => field.classList.remove('error'));

  Object.entries(errors).forEach(([name, message]) => {
    const field = form.querySelector(`[name="${name}"]`);
    if (!field) return;
    field.classList.add('error');
    const error = document.createElement('div');
    error.className = 'error-message';
    error.textContent = message;
    field.insertAdjacentElement('afterend', error);
  });
}

export function simulateLoading(button, callback) {
  const originalText = button.textContent;
  button.disabled = true;
  button.dataset.loading = 'true';
  button.textContent = 'Processing…';
  setTimeout(() => {
    button.disabled = false;
    button.dataset.loading = 'false';
    button.textContent = originalText;
    callback?.();
  }, 1300);
}
