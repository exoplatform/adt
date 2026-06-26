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
