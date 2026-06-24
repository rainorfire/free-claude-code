import { useCallback, useState } from 'react'
import {
  getAnthropicApiKeyWithSource,
  getAuthTokenSource,
  isAnthropicAuthEnabled,
  isClaudeAISubscriber,
} from '../utils/auth.js'

export type VerificationStatus =
  | 'loading'
  | 'valid'
  | 'invalid'
  | 'missing'
  | 'error'

export type ApiKeyVerificationResult = {
  status: VerificationStatus
  reverify: () => Promise<void>
  error: Error | null
}

// Login-restriction removed: any configured credential (env API key, bearer
// token, apiKeyHelper, OAuth token, or 3P provider) counts as authorized. We no
// longer block the REPL on a network verifyApiKey() round-trip, which would
// otherwise misreport custom/proxy endpoints as invalid.
function hasAnyCredential(): boolean {
  if (!isAnthropicAuthEnabled() || isClaudeAISubscriber()) {
    return true
  }
  const { key, source } = getAnthropicApiKeyWithSource({
    skipRetrievingKeyFromApiKeyHelper: true,
  })
  if (key || source === 'apiKeyHelper') {
    return true
  }
  return getAuthTokenSource().hasToken
}

export function useApiKeyVerification(): ApiKeyVerificationResult {
  const [status, setStatus] = useState<VerificationStatus>(() =>
    hasAnyCredential() ? 'valid' : 'missing',
  )
  const [error] = useState<Error | null>(null)

  const verify = useCallback(async (): Promise<void> => {
    setStatus(hasAnyCredential() ? 'valid' : 'missing')
  }, [])

  return {
    status,
    reverify: verify,
    error,
  }
}
