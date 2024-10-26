window.addEventListener("DOMContentLoaded", () => {

  const toggle = document.querySelector("#menu-toggle")
  const menuContainer = document.querySelector(".menu-container")
  if (menuContainer) {
    document.body.addEventListener("click", event => {
      if (menuContainer.contains(event.target)) return
      toggle.checked = false
    })
  }

  const startTimes = document.querySelectorAll(".event-time")
  startTimes.forEach(startTime => {
    const time = moment.unix(startTime.getAttribute("datetime")).tz(Intl.DateTimeFormat().resolvedOptions().timeZone)
    startTime.innerHTML = `Starting ${time.format("dddd")} @ ${time.format("h:mm a z")}`
  })

});
