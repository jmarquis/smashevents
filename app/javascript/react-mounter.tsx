import { createRoot } from "react-dom/client"

import * as components from "./components"

window.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".react-container").forEach(container => {
    if (container instanceof HTMLElement && container.dataset["component"]) {
      const Component =
        components[container.dataset["component"] as keyof typeof components]
      const root = createRoot(container)
      root.render(
        <Component {...JSON.parse(container.dataset["props"] || "{}")} />
      )
    }
  })
})
