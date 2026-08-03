import { NextResponse } from "next/server"

import { createClient } from "@/lib/supabase/server"

function getSafeRedirect(next: string | null, origin: string) {
  if (!next || !next.startsWith("/") || next.startsWith("//")) {
    return new URL("/dashboard", origin)
  }

  const destination = new URL(next, origin)
  return destination.origin === origin ? destination : new URL("/dashboard", origin)
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get("code")

  if (code) {
    const supabase = await createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(getSafeRedirect(url.searchParams.get("next"), url.origin))
}
