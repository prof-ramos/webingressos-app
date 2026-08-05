import { describe, expect, it } from "vitest"

import { getSafeNextPath } from "./safe-navigation"

describe("safe navigation", () => {
  it("preserves a local destination with its query for post-login navigation", () => {
    expect(getSafeNextPath("/dashboard?tab=vendas", "http://localhost")).toBe(
      "/dashboard?tab=vendas",
    )
  })

  it("falls back when the destination points to another origin", () => {
    expect(getSafeNextPath("https://evil.example/dashboard", "http://localhost")).toBe("/dashboard")
  })
})
