import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import test from "node:test"

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..")

test("login não carrega provider de queries remotas sem queries cadastradas", () => {
  const manifestPath = resolve(
    repositoryRoot,
    ".next/server/app/(auth)/login/page_client-reference-manifest.js"
  )
  const manifest = readFileSync(manifestPath, "utf8")

  assert.equal(manifest.includes("src/components/providers/query-provider.tsx"), false)
})

test("shell estrutural permanece Server Component", () => {
  const appShellPath = resolve(repositoryRoot, "src/components/layout/app-shell.tsx")
  const source = readFileSync(appShellPath, "utf8")

  assert.doesNotMatch(source, /^["']use client["']/m)
  assert.doesNotMatch(source, /href=["']\/configuracoes["']/)
})

test("desktop e mobile compartilham os mesmos destinos de navegação", () => {
  const navigationSource = readFileSync(
    resolve(repositoryRoot, "src/components/layout/navigation-links.tsx"),
    "utf8"
  )
  const mobileSource = readFileSync(
    resolve(repositoryRoot, "src/components/layout/mobile-navigation.tsx"),
    "utf8"
  )

  assert.match(navigationSource, /href: ["']\/configuracoes["']/)
  assert.match(navigationSource, /Navegação principal/)
  assert.match(navigationSource, /Navegação utilitária/)
  assert.match(mobileSource, /section=["']all["']/)
})
