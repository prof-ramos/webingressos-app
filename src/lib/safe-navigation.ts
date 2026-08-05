const FALLBACK_PATH = "/dashboard"

export type AuthErrorCode = "supabase_not_configured" | "auth_callback_failed"

const AUTH_ERROR_MESSAGES: Record<AuthErrorCode, string> = {
  supabase_not_configured: "A autenticação ainda não está configurada neste ambiente.",
  auth_callback_failed: "Não foi possível concluir a autenticação. Tente entrar novamente.",
}

export function getSafeNextPath(value: string | null, origin: string) {
  if (!value || !value.startsWith("/") || value.startsWith("//")) {
    return FALLBACK_PATH
  }

  try {
    const candidate = new URL(value, origin)

    if (candidate.origin !== origin) {
      return FALLBACK_PATH
    }

    return `${candidate.pathname}${candidate.search}${candidate.hash}`
  } catch {
    return FALLBACK_PATH
  }
}

export function getAuthErrorMessage(value: string | string[] | undefined) {
  if (typeof value !== "string" || !Object.hasOwn(AUTH_ERROR_MESSAGES, value)) {
    return null
  }

  return AUTH_ERROR_MESSAGES[value as AuthErrorCode]
}

export function getLoginErrorUrl(origin: string, error: AuthErrorCode, next: string | null) {
  const url = new URL("/login", origin)
  url.searchParams.set("error", error)
  url.searchParams.set("next", getSafeNextPath(next, origin))
  return url
}
