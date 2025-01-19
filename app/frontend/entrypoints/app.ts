import "../react-mounter"
import moment from "moment-timezone"

window.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector("#menu-toggle") as HTMLInputElement
  const menuContainer = document.querySelector(".menu-container")
  if (toggle && menuContainer) {
    document.body.addEventListener("click", event => {
      if (menuContainer.contains(event.target as Node)) return
      toggle.checked = false
    })
  }

  const startTimes = document.querySelectorAll(".event-time")
  startTimes.forEach(startTime => {
    const time = moment
      .unix(parseInt(startTime.getAttribute("datetime") || ""))
      .tz(Intl.DateTimeFormat().resolvedOptions().timeZone)
    startTime.innerHTML = `${time.format("dddd")} @ ${time.format("h:mm a z")}`
  })
})
