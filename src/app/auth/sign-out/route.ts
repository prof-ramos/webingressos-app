import { NextResponse } from "next/server"

import { getSupabaseConfig } from "@/lib/supabase/config"
import { createClient } from "@/lib/supabase/server"

export async function POST(request: Request) {
  const origin = new URL(request.url).origin

  if (getSupabaseConfig()) {
    const supabase = await createClient()
    await supabase.auth.signOut()
  }

  // 303 so the browser turns the POST into a GET on the login screen.
  return NextResponse.redirect(new URL("/login", origin), { status: 303 })
}
