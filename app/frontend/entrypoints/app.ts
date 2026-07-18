import moment from "moment-timezone"
import { Turbo } from "@hotwired/turbo-rails"

import "../react-mounter"

Turbo.session.drive = false

let refreshedAt = moment()
let tournamentsLoading = false

const localizeStartTimes = () => {
  const startTimes = document.querySelectorAll("time.event-time")
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

let refreshDebounce: ReturnType<typeof setTimeout> | null = null

const refreshTournaments = () => {
  const ids = Array.from(document.querySelectorAll("article.tournament"))
    .map(tournament => tournament.id.replace("tournament_", ""))
    .filter(Boolean)

  if (!ids.length) return

  const params = new URLSearchParams()
  ids.forEach(id => params.append("ids[]", id))

  fetch(`/tournaments?${params.toString()}`, {
    headers: { Accept: "text/vnd.turbo-stream.html" }
  })
    .then(response => response.text())
    .then(html => Turbo.renderStreamMessage(html))

  refreshedAt = moment()
}

window.addEventListener("DOMContentLoaded", () => {
  setTimeout(() => {
    new MutationObserver(() => {
      if (refreshDebounce) clearTimeout(refreshDebounce)
      refreshDebounce = setTimeout(refreshTournaments, 300)
    }).observe(document.body, {
      subtree: true,
      attributeFilter: ["connected"]
    })

    const refreshIfStale = () => {
      if (document.visibilityState !== "visible") return
      if (moment().subtract(5, "minute").isAfter(refreshedAt)) {
        if (refreshDebounce) clearTimeout(refreshDebounce)
        refreshDebounce = setTimeout(refreshTournaments, 300)
      }
    }

    window.addEventListener("focus", refreshIfStale)
    document.addEventListener("visibilitychange", refreshIfStale)
    window.addEventListener("pageshow", refreshIfStale)
  }, 3000)
})
