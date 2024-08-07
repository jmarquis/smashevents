window.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector("#menu-toggle")
  const menuContainer = document.querySelector(".menu-container")
  if (menuContainer) {
    document.body.addEventListener("click", event => {
      if (menuContainer.contains(event.target)) return
      toggle.checked = false
    })
  }
});
