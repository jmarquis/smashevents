import moment from "moment-timezone"
import { Turbo } from "@hotwired/turbo-rails"

import "../react-mounter"

Turbo.session.drive = false

const loadedAt = moment()
let tournamentsLoading = false

const localizeStartTimes = () => {
  const startTimes = document.querySelectorAll(".event-time")
  startTimes.forEach(startTime => {
    const time = moment
      .unix(parseInt(startTime.getAttribute("datetime") || ""))
      .tz(Intl.DateTimeFormat().resolvedOptions().timeZone)
    startTime.innerHTML = `${time.format("ddd")} ${time.format("h:mm a z")}`
  })
}

window.addEventListener("DOMContentLoaded", () => {
  // Game selector menu setup
  const toggle = document.querySelector("#menu-toggle") as HTMLInputElement
  const menuContainer = document.querySelector(".menu-container")
  if (toggle && menuContainer) {
    document.body.addEventListener("click", event => {
      if (menuContainer.contains(event.target as Node)) return
      toggle.checked = false
    })
  }

  // Event time localization
  localizeStartTimes()

  // Infinite scroll setup
  const tournamentLoader = document.querySelector(
    "#tournament-loader"
  ) as HTMLElement | null
  if (tournamentLoader) {
    const observer = new IntersectionObserver(
      entries => {
        entries.forEach(entry => {
          if (entry.isIntersecting && entry.target instanceof HTMLElement) {
            if (tournamentsLoading) return
            tournamentsLoading = true

            const paramsForm = document.querySelector(
              "form#params"
            ) as HTMLFormElement

            const requestData = new URLSearchParams(
              new FormData(paramsForm) as any
            )

            requestData.set(
              "last_tournament_id",
              entry.target.dataset["lastTournamentId"] || ""
            )

            fetch(`${paramsForm.action}?${requestData.toString()}`)
              .then(response => response.text())
              .then(data => {
                entry.target.outerHTML = data
                localizeStartTimes()

                const newTournamentLoader = document.querySelector(
                  "#tournament-loader"
                ) as HTMLElement

                if (newTournamentLoader) {
                  observer.observe(newTournamentLoader)
                }

                tournamentsLoading = false
              })
          }
        })
      },
      {
        root: null,
        rootMargin: "200px"
      }
    )

    observer.observe(
      document.querySelector("#tournament-loader") as HTMLElement
    )
  }
})

document.addEventListener("turbo:before-stream-render", ((
  event: CustomEvent
) => {
  const originalRender = event.detail.render
  event.detail.render = (streamElement: Element) => {
    originalRender(streamElement)
    localizeStartTimes()
  }
}) as EventListener)

window.addEventListener("focus", () => {
  if (moment().subtract(6, "hour").isAfter(loadedAt)) {
    location.reload()
  }
})
