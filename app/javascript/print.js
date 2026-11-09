// Opens every disclosure for printing and closes the ones that were closed
// afterwards (UX audit E4), for browsers whose print styles can't.
const opened = []

window.addEventListener("beforeprint", () => {
  document.querySelectorAll("details:not([open])").forEach((details) => {
    details.open = true
    opened.push(details)
  })
})

window.addEventListener("afterprint", () => {
  opened.splice(0).forEach((details) => { details.open = false })
})
