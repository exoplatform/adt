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
// Light/dark toggle. The stored choice is applied before first paint by the inline script in the template head;
// without a choice the system preference decides (custom.css).
(function () {
    var root = document.documentElement;
    var button = document.querySelector("[data-exo-theme-toggle]");
    if (!button) {
        return;
    }
    function effective() {
        var explicit = root.getAttribute("data-theme");
        if (explicit === "dark" || explicit === "light") {
            return explicit;
        }
        return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }
    function render() {
        var dark = effective() === "dark";
        // The label names the action: what a click switches to
        var label = dark ? button.dataset.labelLight : button.dataset.labelDark;
        button.setAttribute("aria-label", label);
        button.setAttribute("title", label);
        button.setAttribute("aria-pressed", dark ? "true" : "false");
    }
    button.addEventListener("click", function () {
        var next = effective() === "dark" ? "light" : "dark";
        root.setAttribute("data-theme", next);
        try { localStorage.setItem("exo-theme", next); } catch (e) {}
        render();
    });
    if (window.matchMedia) {
        var mq = window.matchMedia("(prefers-color-scheme: dark)");
        var onChange = function () { render(); };
        if (mq.addEventListener) { mq.addEventListener("change", onChange); }
    }
    render();
})();
