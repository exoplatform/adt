// Not while the tab is hidden (every reload makes the server query all the acceptance servers), nor while a
// modal is open, a field is being edited or a details control (project list of a card, base branch editor) is
// open: try again shortly instead
setTimeout(function reload() {
  var a = document.activeElement;
  if (document.visibilityState === 'hidden' || document.querySelector('.modal.show') || document.querySelector('.feature-more[open], .feature-base[open]') ||
      (a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName))) {
    setTimeout(reload, 15000);
    return;
  }
  window.location.reload();
}, 120000);
