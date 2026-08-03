import { afterEach, describe, expect, it, vi } from "vitest"

import { getSupabaseConfig, requireSupabaseConfig } from "./config"

afterEach(() => {
  vi.unstubAllEnvs()
})

describe("Supabase configuration", () => {
  it("returns null when both public variables are missing", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "")

    expect(getSupabaseConfig()).toBeNull()
  })

  it("returns null when only one public variable is present", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "")

    expect(getSupabaseConfig()).toBeNull()
  })

  it("returns both public values when configured", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "publishable-key")

    expect(getSupabaseConfig()).toEqual({
      url: "https://example.supabase.co",
      publishableKey: "publishable-key",
    })
  })

  it("throws the documented error when required configuration is absent", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "")

    expect(() => requireSupabaseConfig()).toThrow(
      "Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY."
    )
  })

  it("returns the configured values from the required helper", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "publishable-key")

    expect(requireSupabaseConfig()).toEqual({
      url: "https://example.supabase.co",
      publishableKey: "publishable-key",
    })
  })
})
