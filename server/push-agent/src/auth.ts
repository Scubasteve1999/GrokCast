/**
 * Constant-time string comparison. Written by hand rather than using the Workers
 * `crypto.subtle.timingSafeEqual` extension so the same code runs under `node --test`.
 *
 * Length is compared non-constant-time, which leaks only the secret's length —
 * the same tradeoff the standard library implementations make.
 */
export function secureCompare(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i += 1) {
    mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return mismatch === 0;
}

/** Extracts the token from an `Authorization: Bearer <token>` header. */
export function bearerToken(header: string | null): string | null {
  if (!header) return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}
