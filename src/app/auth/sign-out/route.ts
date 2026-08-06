import { NextResponse } from "next/server"

import { getSupabaseConfig } from "@/lib/supabase/config"
import { createClient } from "@/lib/supabase/server"

/**
 * A failed sign-out must not look like a successful one: if Supabase rejects or
 * is unreachable the session may still be valid, so the redirect carries an
 * error flag instead of quietly landing on a clean login screen.
 */
export async function POST(request: Request) {
  const origin = new URL(request.url).origin
  const destination = new URL("/login", origin)

  if (getSupabaseConfig()) {
    try {
      const supabase = await createClient()
      const { error } = await supabase.auth.signOut()

      if (error) {
        destination.searchParams.set("erro", "logout")
      }
    } catch {
      destination.searchParams.set("erro", "logout")
    }
  } else {
    destination.searchParams.set("erro", "logout")
  }

  // 303 so the browser turns the POST into a GET on the login screen.
  return NextResponse.redirect(destination, { status: 303 })
}
