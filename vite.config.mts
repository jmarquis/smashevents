import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"
import svgr from "vite-plugin-svgr"

export default defineConfig({
  server: {
    allowedHosts: true
  },
  plugins: [RubyPlugin(), svgr()]
})
