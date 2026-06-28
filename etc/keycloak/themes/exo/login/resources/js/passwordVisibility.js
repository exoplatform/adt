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
document.querySelectorAll("[data-password-toggle]").forEach(function(button) {
    button.addEventListener("click", function() {
        var passwordInput = document.getElementById(button.getAttribute("aria-controls"));
        if (passwordInput) {
            var isPassword = passwordInput.type === "password";
            passwordInput.type = isPassword ? "text" : "password";
            button.setAttribute("aria-label", isPassword ? button.dataset.labelHide : button.dataset.labelShow);
            var icon = button.querySelector("i");
            if (icon) {
                icon.className = isPassword ? button.dataset.iconHide : button.dataset.iconShow;
            }
        }
    });
});
