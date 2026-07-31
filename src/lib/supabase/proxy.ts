import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"

import { getSupabaseConfig } from "@/lib/supabase/config"

export async function updateSession(request: NextRequest) {
  const config = getSupabaseConfig()
  const isPublicRoute =
    request.nextUrl.pathname === "/login" || request.nextUrl.pathname.startsWith("/auth")

  if (!config) {
    if (isPublicRoute) {
      return NextResponse.next({ request })
    }

    const redirectUrl = request.nextUrl.clone()
    redirectUrl.pathname = "/login"
    redirectUrl.searchParams.set("error", "supabase_not_configured")
    return NextResponse.redirect(redirectUrl)
  }

  let response = NextResponse.next({ request })
  const supabase = createServerClient(config.url, config.publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options)
        })
      },
    },
  })

  const { data } = await supabase.auth.getClaims()
  if (!data?.claims && !isPublicRoute) {
    const redirectUrl = request.nextUrl.clone()
    redirectUrl.pathname = "/login"
    redirectUrl.searchParams.set(
      "next",
      `${request.nextUrl.pathname}${request.nextUrl.search}`
    )
    return NextResponse.redirect(redirectUrl)
  }

  return response
}
