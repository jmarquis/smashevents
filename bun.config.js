import path from "path"
import fs from "fs"
import { Glob } from "bun"
import { compile } from "sass"

const build = async () => {
  const entrypoints = []
  for await (const entrypoint of new Glob("*.ts").scan("app/ui/entrypoints")) {
    entrypoints.push(`app/ui/entrypoints/${entrypoint}`)
  }

  const result = await Bun.build({
    sourcemap: "external",
    entrypoints,
    outdir: path.join(process.cwd(), "app/assets/builds")
  })

  if (!result.success) {
    if (process.argv.includes("--watch")) {
      console.error("Build failed")
      for (const message of result.logs) {
        console.error(message)
      }
      return
    } else {
      throw new AggregateError(result.logs, "Build failed")
    }
  }
}

;(async () => {
  await build()

  if (process.argv.includes("--watch")) {
    fs.watch(
      path.join(process.cwd(), "app/ui"),
      { recursive: true },
      (eventType, filename) => {
        console.log(`File changed: ${filename}. Rebuilding...`)
        build()
      }
    )
  } else {
    process.exit(0)
  }
})()
