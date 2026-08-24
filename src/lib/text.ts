export function companyInitials(companyName: string) {
  const words = companyName
    .split(/\s+/)
    .map(word => word.replace(/[^A-Za-z0-9]/g, ''))
    .filter(Boolean)
  if (words.length === 0) return '?'
  const first = words[0]!
  if (words.length > 1) return `${Array.from(first)[0]}${Array.from(words[1]!)[0]}`.toUpperCase()
  return Array.from(first).slice(0, 2).join('').toUpperCase()
}
