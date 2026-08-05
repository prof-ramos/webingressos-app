import { after, before, test } from "node:test"
import assert from "node:assert/strict"
import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const port = 3100 + (process.pid % 500)
const baseUrl = `http://127.0.0.1:${port}`

let server

async function waitForServer() {
  const deadline = Date.now() + 10_000

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${baseUrl}/login`, { redirect: "manual" })

      if (response.status === 200) {
        return
      }
    } catch {
      // The production server is still starting.
    }

    await new Promise((resolve) => setTimeout(resolve, 100))
  }

  throw new Error("Next.js production server did not become ready in time")
}

before(async () => {
  assert.ok(
    existsSync(resolve(repositoryRoot, ".next")),
    "Run pnpm build before the HTTP integration tests"
  )

  server = spawn("pnpm", ["exec", "next", "start", "-p", String(port)], {
    cwd: repositoryRoot,
    env: {
      ...process.env,
      NEXT_PUBLIC_SUPABASE_URL: "",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "",
      NEXT_TELEMETRY_DISABLED: "1",
      PORT: String(port),
    },
    stdio: "ignore",
  })

  await waitForServer()
})

after(() => {
  server?.kill("SIGTERM")
})

test("rota protegida falha fechada sem configuração e preserva o destino", async () => {
  const response = await fetch(`${baseUrl}/dashboard?tab=vendas`, { redirect: "manual" })

  assert.equal(response.status, 307)
  const location = new URL(response.headers.get("location"), baseUrl)
  assert.equal(location.pathname, "/login")
  assert.equal(location.searchParams.get("error"), "supabase_not_configured")
  assert.equal(location.searchParams.get("next"), "/dashboard?tab=vendas")
})

test("login permanece público quando o Supabase não está configurado", async () => {
  const response = await fetch(`${baseUrl}/login`, { redirect: "manual" })

  assert.equal(response.status, 200)
})

test("callback sem código informa falha e preserva o destino seguro", async () => {
  const response = await fetch(`${baseUrl}/auth/callback?next=%2Flogin`, {
    redirect: "manual",
  })

  assert.equal(response.status, 307)
  const location = new URL(response.headers.get("location"))
  assert.equal(location.pathname, "/login")
  assert.equal(location.searchParams.get("error"), "auth_callback_failed")
  assert.equal(location.searchParams.get("next"), "/login")
})

test("callback rejeita destino externo em uma falha de autenticação", async () => {
  const response = await fetch(`${baseUrl}/auth/callback?next=%2F%2Fevil.example`, {
    redirect: "manual",
  })

  assert.equal(response.status, 307)
  const location = new URL(response.headers.get("location"))
  assert.equal(location.pathname, "/login")
  assert.equal(location.searchParams.get("error"), "auth_callback_failed")
  assert.equal(location.searchParams.get("next"), "/dashboard")
})

test("callback trata falha na troca do código como erro de autenticação", async () => {
  const response = await fetch(`${baseUrl}/auth/callback?code=invalido&next=%2Fdashboard`, {
    redirect: "manual",
  })

  assert.equal(response.status, 307)
  const location = new URL(response.headers.get("location"))
  assert.equal(location.pathname, "/login")
  assert.equal(location.searchParams.get("error"), "auth_callback_failed")
  assert.equal(location.searchParams.get("next"), "/dashboard")
})
