// Formatting shared by the form summaries and the amount splitter (UX audit
// E3), so each sentence reads amounts, dates and times the same way the
// server's helpers do.

// "1,234.50" or "1234.5" as a number, or null when blank or not a number.
export function parseAmount(text) {
  const value = String(text ?? "").replace(/,/g, "").trim()
  if (!value) return null
  const amount = Number(value)
  return Number.isFinite(amount) ? amount : null
}

// An amount as whole cents; blank or unreadable is zero.
export function cents(text) {
  const amount = parseAmount(text)
  return amount === null ? 0 : Math.round(amount * 100)
}

// Cents back to the plain form staff type, "1234.50".
export function plainAmount(centsValue) {
  return (centsValue / 100).toFixed(2)
}

// An amount with its currency, "$1,234.50", or null when blank.
export function money(text, currency) {
  const amount = parseAmount(text)
  if (amount === null) return null
  try {
    return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amount)
  } catch {
    return `${amount} ${currency}`
  }
}

// An ISO date, "2027-07-09", as "Jul 9, 2027", or null when blank.
export function longDate(iso) {
  if (!iso) return null
  const [year, month, day] = iso.split("-").map(Number)
  return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" })
}

// A 24-hour "13:05" as "1:05 p.m.".
export function clockTime(value) {
  const [hours, minutes] = value.split(":").map(Number)
  const suffix = hours >= 12 ? "p.m." : "a.m."
  return `${((hours + 11) % 12) + 1}:${String(minutes).padStart(2, "0")} ${suffix}`
}
