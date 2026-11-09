# UI rules

Moved from [AGENTS.md](../../AGENTS.md), which points here. Theme, color meanings, navigation and accessibility. These rules are binding when a task touches this area.

The canonical theme lives in `app/assets/tailwind/application.css`.

Brand meanings:

- Navy: structure and authority.
- Teal: movement, action, active, and selected states.
- Amber: waypoints, deadlines, focus, and guaranteed exposure.
- Red: destructive, invalid, cancelled, or overdue states.

Rules:

- Reuse `dd-` component classes and design tokens before creating one-off colors or spacing.
- Keep amber text dark; never use small white text on the logo amber.
- Amber is not the destructive color and is not the default active-navigation color.
- Never communicate status by color alone. Pair color with text and, when useful, an icon.
- Use visible horizontal separators in dense operational tables; avoid excessive vertical grid lines.
- Keep inputs neutral until interaction. Use teal for active interaction and amber for the keyboard focus ring.
- Maintain WCAG-conscious contrast and complete keyboard access.
- Keep the skip link and meaningful focus indicators functional.
- Disabled navigation placeholders must become real links only when corresponding authorized routes exist. Show Dashboard, My tasks for `use_tasks`, Clients for `view_client_directory`, Suppliers for `view_supplier_directory`, Departures for `view_departures`, and Administration for Agency Admins (`manage_agency_profile`). Do not show Directory, Travelers, or Accounting navigation.
- Do not introduce an external font, icon library, or JavaScript UI framework without an explicit product decision.
- Administration page, panel, button, and field anatomy is defined in [docs/ui/interface-contract.md](../ui/interface-contract.md). Reuse that contract before adding presentation classes.
