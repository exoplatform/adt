// Not while the tab is hidden (every reload makes the server query all the acceptance servers), nor while a
// modal is open or a field is being edited: try again shortly instead
setTimeout(function reload() {
  var a = document.activeElement;
  if (document.visibilityState === 'hidden' || document.querySelector('.modal.show') ||
      (a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName))) {
    setTimeout(reload, 15000);
    return;
  }
  window.location.reload();
}, 120000);
