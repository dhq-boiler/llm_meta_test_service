// Popover positioning
document.addEventListener('DOMContentLoaded', () => {
  const userMenuToggle = document.querySelector('.user-menu-toggle');
  const userPopoverMenu = document.getElementById('user-menu-popover');

  if (userMenuToggle && userPopoverMenu) {
    userMenuToggle.addEventListener('click', () => {
      // Wait for popover to open
      setTimeout(() => {
        const buttonRect = userMenuToggle.getBoundingClientRect();
        const popoverRect = userPopoverMenu.getBoundingClientRect();

        // Position popover below the button, aligned to the right
        const top = buttonRect.bottom + 8; // 8px gap
        const right = window.innerWidth - buttonRect.right;

        // Check if popover would go off screen
        const wouldOverflowRight = (window.innerWidth - buttonRect.right) + popoverRect.width > window.innerWidth;
        const wouldOverflowBottom = top + popoverRect.height > window.innerHeight;

        if (!wouldOverflowRight && !wouldOverflowBottom) {
          userPopoverMenu.style.position = 'fixed';
          userPopoverMenu.style.top = `${top}px`;
          userPopoverMenu.style.right = `${right}px`;
          userPopoverMenu.style.left = 'auto';
          userPopoverMenu.style.bottom = 'auto';
        } else {
          // Fallback positioning
          userPopoverMenu.style.position = 'fixed';
          userPopoverMenu.style.top = `${buttonRect.bottom + 8}px`;
          userPopoverMenu.style.left = `${buttonRect.left}px`;
          userPopoverMenu.style.right = 'auto';
          userPopoverMenu.style.bottom = 'auto';
        }
      }, 10);
    });
  }
});
