// Popover positioning for browsers that don't support CSS Anchor Positioning
document.addEventListener('DOMContentLoaded', () => {
  // Check if browser supports CSS Anchor Positioning
  if (CSS.supports('position-area', 'block-end')) {
    return; // Native CSS support, no JS needed
  }

  const userMenuToggle = document.querySelector('.user-menu-toggle');
  const userPopoverMenu = document.getElementById('user-menu-popover');

  if (userMenuToggle && userPopoverMenu) {
    const positionPopover = () => {
      const buttonRect = userMenuToggle.getBoundingClientRect();

      // Position below button, aligned to the right edge
      userPopoverMenu.style.position = 'fixed';
      userPopoverMenu.style.top = `${buttonRect.bottom + 8}px`;
      userPopoverMenu.style.right = `${window.innerWidth - buttonRect.right}px`;
      userPopoverMenu.style.left = 'auto';
    };

    userMenuToggle.addEventListener('click', () => {
      // Position on next frame after popover opens
      requestAnimationFrame(positionPopover);
    });

    // Reposition on window resize
    window.addEventListener('resize', () => {
      if (userPopoverMenu.matches(':popover-open')) {
        positionPopover();
      }
    });
  }
});
