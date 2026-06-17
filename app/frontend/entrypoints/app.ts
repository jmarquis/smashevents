import "../react-mounter"
import moment from "moment-timezone"

const loadedAt = moment()

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
    startTime.innerHTML = `${time.format("ddd")} ${time.format("h:mm a z")}`
  })
})

window.addEventListener("focus", () => {
  if (moment().subtract(10, "minute").isAfter(loadedAt)) {
    location.reload()
  }
})
