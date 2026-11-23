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
// Same behaviour as the stock template: a link marked data-once-link works once (prevents double submits).
document.addEventListener("click", function (event) {
    var link = event.target.closest("a[data-once-link]");
    if (!link) {
        return;
    }
    if (link.getAttribute("aria-disabled") === "true") {
        event.preventDefault();
        return;
    }
    var disabledClass = link.dataset.disabledClass;
    if (disabledClass) {
        link.classList.add.apply(link.classList, disabledClass.trim().split(/\s+/));
    }
    link.setAttribute("role", "link");
    link.setAttribute("aria-disabled", "true");
});
