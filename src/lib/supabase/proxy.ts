import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"

import { getSupabaseConfig } from "@/lib/supabase/config"
import { getLoginErrorUrl } from "@/lib/safe-navigation"

export async function updateSession(request: NextRequest) {
  const config = getSupabaseConfig()
  const isPublicRoute =
    request.nextUrl.pathname === "/login" || request.nextUrl.pathname.startsWith("/auth")

  if (!config) {
    if (isPublicRoute) {
      return NextResponse.next({ request })
    }

    return NextResponse.redirect(
      getLoginErrorUrl(
        request.nextUrl.origin,
        "supabase_not_configured",
        `${request.nextUrl.pathname}${request.nextUrl.search}`
      )
    )
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
    const redirectUrl = new URL("/login", request.nextUrl.origin)
    redirectUrl.searchParams.set(
      "next",
      `${request.nextUrl.pathname}${request.nextUrl.search}`
    )
    return NextResponse.redirect(redirectUrl)
  }

  return response
}
