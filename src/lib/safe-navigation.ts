const FALLBACK_PATH = "/dashboard"

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
