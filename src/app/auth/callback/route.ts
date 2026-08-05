import { type NextRequest, NextResponse } from "next/server"

import { getLoginErrorUrl, getSafeNextPath } from "@/lib/safe-navigation"
import { getSupabaseConfig } from "@/lib/supabase/config"
import { createClient } from "@/lib/supabase/server"

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code")
  const requestedNext = request.nextUrl.searchParams.get("next")
  const next = getSafeNextPath(requestedNext, request.nextUrl.origin)

  if (!code) {
    return NextResponse.redirect(
      getLoginErrorUrl(request.nextUrl.origin, "auth_callback_failed", next)
    )
  }

  if (!getSupabaseConfig()) {
    return NextResponse.redirect(
      getLoginErrorUrl(request.nextUrl.origin, "supabase_not_configured", next)
    )
  }

  try {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)

    if (error) {
      return NextResponse.redirect(
        getLoginErrorUrl(request.nextUrl.origin, "auth_callback_failed", next)
      )
    }
  } catch {
    return NextResponse.redirect(
      getLoginErrorUrl(request.nextUrl.origin, "auth_callback_failed", next)
    )
  }

  return NextResponse.redirect(new URL(next, request.nextUrl.origin))
}
