/*
 * Copyright (C) 2026 eXo Platform SAS.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
// Show/hide password toggle. The stock markup is kept (button[data-password-toggle] with aria-controls);
// the icon is drawn in CSS from aria-pressed, so no icon font is needed.
(function () {
    var buttons = Array.prototype.slice.call(document.querySelectorAll("[data-password-toggle]"));

    function setVisible(button, visible) {
        var input = document.getElementById(button.getAttribute("aria-controls"));
        if (!input) {
            return;
        }
        input.type = visible ? "text" : "password";
        button.setAttribute("aria-pressed", visible ? "true" : "false");
        // The label names the action a click performs
        button.setAttribute("aria-label", visible ? button.dataset.labelHide : button.dataset.labelShow);
        button.setAttribute("title", visible ? button.dataset.labelHide : button.dataset.labelShow);
    }

    buttons.forEach(function (button) {
        setVisible(button, false);
        button.addEventListener("click", function () {
            var input = document.getElementById(button.getAttribute("aria-controls"));
            if (!input) {
                return;
            }
            setVisible(button, input.type === "password");
            // Keep the caret where the user was typing
            input.focus({ preventScroll: true });
        });
        var form = button.closest("form");
        if (form) {
            // Never leave a password readable once it is sent
            form.addEventListener("submit", function () { setVisible(button, false); });
        }
    });

    // Page restored from the back/forward cache: hide again
    window.addEventListener("pageshow", function (event) {
        if (event.persisted) {
            buttons.forEach(function (button) { setVisible(button, false); });
        }
    });
})();
