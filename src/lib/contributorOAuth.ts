export type ContributorOAuthProvider = 'google' | 'linkedin_oidc'

const providerNames: Record<ContributorOAuthProvider, string> = {
  google: 'Google',
  linkedin_oidc: 'LinkedIn',
}

export const contributorOAuthProviderKey = 'expopulse.contributor.oauth-provider'

export function isContributorOAuthProvider(value: string | null): value is ContributorOAuthProvider {
  return value === 'google' || value === 'linkedin_oidc'
}

export function contributorOAuthErrorMessage(message: string, provider: ContributorOAuthProvider | null) {
  const normalized = message.trim()
  if (!/(daily|rate[ _-]?limit|too many requests|quota|429)/i.test(normalized)) return normalized

  if (!provider) {
    return 'A sign-in provider has reached its daily limit. Please try the other sign-in option.'
  }

  const alternative: ContributorOAuthProvider = provider === 'google' ? 'linkedin_oidc' : 'google'
  return `${providerNames[provider]} sign-in has reached its daily limit. Please continue with ${providerNames[alternative]} instead.`
}
