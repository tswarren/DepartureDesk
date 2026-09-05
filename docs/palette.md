## Core brand palette

These values closely reflect the generated logo:

| Token | Color | Role |
| :---- | :---- | :---- |
| Departure Navy | `#002340` | Brand foundation, navigation, headings |
| Route Teal | `#007080` | Primary interaction and active state |
| Action Teal | `#006270` | Buttons and links requiring stronger contrast |
| Waypoint Amber | `#F49A00` | Milestones, deadlines, selected data points |
| Deep Ink | `#17212B` | Primary body text |
| Slate | `#52616D` | Secondary text |
| Cloud | `#F6F7F5` | Application background |
| White | `#FFFFFF` | Primary surfaces |

The three logo colors should retain consistent meaning:

* **Navy:** structure and authority  
* **Teal:** movement and action  
* **Amber:** a significant waypoint or item requiring notice

## Application neutrals

A slightly warm-neutral background keeps the product from feeling like a generic blue-gray enterprise application.

| Token | Value | Suggested use |
| :---- | :---- | :---- |
| `background` | `#F6F7F5` | Main workspace |
| `surface` | `#FFFFFF` | Panels, cards, dialogs |
| `surface-subtle` | `#EEF2F1` | Secondary regions and table groups |
| `surface-emphasis` | `#E2EBEA` | Selected or emphasized sections |
| `border` | `#D4DEDF` | Standard borders |
| `border-strong` | `#AABABD` | Inputs and stronger divisions |
| `text` | `#17212B` | Primary text |
| `text-muted` | `#52616D` | Supporting text |
| `text-faint` | `#71808A` | Metadata and placeholders |
| `text-on-dark` | `#FFFFFF` | Text on navy or dark teal |

Avoid extremely pale borders. DepartureDesk will contain dense tables and financial records; boundaries need to remain visible without turning every screen into a spreadsheet grid.

## Primary application chrome

I would use navy for the persistent application frame:

* Navy header or left navigation  
* White primary navigation labels  
* Teal active indicator  
* Amber only for a genuinely important alert or deadline  
* Cloud-colored workspace behind white content surfaces

This makes the frame feel stable while allowing the departure itself to remain the visual focus.

### Suggested navigation treatment

| State | Treatment |
| :---- | :---- |
| Default item | Soft blue-white text on navy |
| Hover | Slightly lighter navy background |
| Active | Teal edge or underline plus white text |
| Keyboard focus | Amber outer focus ring |
| Notification | Small amber badge |
| Destructive warning | Red badge, not amber |

Amber should not indicate the current navigation item; teal already owns active and selected states.

## Interactive colors

| Token | Value | Role |
| :---- | :---- | :---- |
| `action-primary` | `#006270` | Primary buttons |
| `action-primary-hover` | `#004F5B` | Primary-button hover |
| `action-primary-active` | `#003F49` | Pressed state |
| `action-secondary` | `#002340` | Secondary strong action |
| `link` | `#006270` | Inline links |
| `link-hover` | `#004B57` | Link hover |
| `focus` | `#F49A00` | Focus outline |
| `selection-bg` | `#D7EFF0` | Selected rows and controls |
| `selection-text` | `#003C45` | Text on selected surfaces |

Both navy and dark teal support white button text comfortably. The logo teal `#007080` is suitable for links and larger controls, but `#006270` gives primary buttons stronger contrast.

## Amber usage

Waypoint Amber is distinctive, but it is not dark enough for small text on white. Use it for:

* Focus rings  
* Timeline milestones  
* Deadline markers  
* Small indicator fills  
* Chart highlights  
* Progress waypoints  
* Icons paired with a dark label

For amber callouts, use dark text:

| Token | Value |
| :---- | :---- |
| Amber surface | `#FFF2D6` |
| Amber border | `#E6A52E` |
| Amber text | `#694400` |
| Amber icon | `#8A5A00` |

Do not use white text on the logo amber.

## Semantic colors

Brand colors should not carry all status meaning. Operational states need conventional semantic colors.

| Meaning | Strong | Surface | Text |
| :---- | :---- | :---- | :---- |
| Success/confirmed | `#2F6B4F` | `#E6F3EB` | `#24523D` |
| Warning/attention | `#B87800` | `#FFF2D6` | `#694400` |
| Error/overdue | `#B5473D` | `#FBE9E7` | `#84332D` |
| Information | `#326A8A` | `#E7F1F7` | `#264F67` |
| Neutral/inactive | `#65727B` | `#EDF0F2` | `#46525A` |

Use both color and text or iconography:

* Green check \+ **Confirmed**  
* Amber clock \+ **Due soon**  
* Red alert \+ **Overdue**  
* Gray pause \+ **Option held**

Color alone should never communicate status.

## Departure status treatments

| Departure status | Treatment |
| :---- | :---- |
| Draft | Neutral gray |
| Planning | Information blue |
| Open for sale | Teal |
| Confirmed | Green |
| Closed for sale | Navy |
| In operation | Teal with an activity indicator |
| Completed | Navy-gray |
| Reconciliation | Amber |
| Closed | Deep neutral |
| Cancelled | Red outline or soft red |

“Cancelled” should not use a solid red badge everywhere; a restrained red outline is easier to scan in dense tables.

## Financial presentation

DepartureDesk will need to distinguish money types without making accounting screens visually noisy.

| Financial meaning | Suggested treatment |
| :---- | :---- |
| Client revenue/charges | Navy |
| Client receipts | Teal |
| Supplier obligations | Muted plum or slate |
| Supplier payments | Blue |
| Projected margin | Navy |
| Positive actual margin | Green |
| Negative margin/exposure | Red |
| Uncommitted estimate | Dashed border or muted text |
| Guaranteed exposure | Amber |
| Overdue balance | Red |

Use symbols and labels alongside color. A negative amount should retain a minus sign or parentheses.

## Tables

Tables will be central to the product. I’d use:

* White table background  
* Navy column headings  
* `#EEF2F1` header fill  
* `#D4DEDF` horizontal separators  
* Minimal vertical rules  
* Pale teal selected rows  
* Pale amber rows requiring attention  
* A narrow semantic indicator at the left edge when needed

Recommended row states:

| State | Background |
| :---- | :---- |
| Default | `#FFFFFF` |
| Hover | `#F1F7F6` |
| Selected | `#D7EFF0` |
| Attention | `#FFF7E7` |
| Error | `#FDF0EE` |
| Inactive | `#F3F4F4` |

## Forms

Inputs should remain mostly neutral so teal retains meaning as interaction:

* White field background  
* Strong neutral border  
* Navy or ink text  
* Teal border on focus  
* Amber outer focus ring for keyboard visibility  
* Red border and accompanying message for validation errors

Required fields should be identified textually or with a conventional marker—not by amber alone.

## Dashboards and data visualization

A coordinated chart palette could be:

1. Navy — `#002F54`  
2. Teal — `#007D87`  
3. Amber — `#F49A00`  
4. Blue — `#4C78A8`  
5. Green — `#4D8061`  
6. Plum — `#765A78`  
7. Coral — `#C66555`  
8. Slate — `#687980`

For projected versus actual values:

* Projected: lighter fill or dashed line  
* Confirmed: full brand color  
* Actual: darker full-strength color

Do not communicate projected versus actual merely by changing hue.

## Visual character

The application should feel:

* Operational, but not industrial  
* Financially trustworthy, but not like accounting software  
* Travel-oriented, but not recreational  
* Information-dense, but calm  
* Modern, but not overly minimalist

I would use:

* Modest corner radii around `6–8px`  
* Very restrained shadows  
* Clear section borders  
* Generous internal spacing  
* Compact but readable tables  
* Navy headings  
* Teal controls  
* Amber waypoint markers  
* Line icons with rounded geometry similar to the logo paths

## Initial design tokens

```css
:root {
  /* Brand */
  --dd-navy: #002340;
  --dd-teal: #007080;
  --dd-teal-action: #006270;
  --dd-amber: #f49a00;

  /* Surfaces */
  --dd-background: #f6f7f5;
  --dd-surface: #ffffff;
  --dd-surface-subtle: #eef2f1;
  --dd-surface-emphasis: #e2ebea;

  /* Text */
  --dd-text: #17212b;
  --dd-text-muted: #52616d;
  --dd-text-faint: #71808a;
  --dd-text-on-dark: #ffffff;

  /* Structure */
  --dd-border: #d4dedf;
  --dd-border-strong: #aababd;

  /* Interaction */
  --dd-action: #006270;
  --dd-action-hover: #004f5b;
  --dd-action-active: #003f49;
  --dd-focus: #f49a00;
  --dd-selection: #d7eff0;

  /* Semantic */
  --dd-success: #2f6b4f;
  --dd-success-surface: #e6f3eb;
  --dd-warning: #8a5a00;
  --dd-warning-surface: #fff2d6;
  --dd-danger: #b5473d;
  --dd-danger-surface: #fbe9e7;
  --dd-info: #326a8a;
  --dd-info-surface: #e7f1f7;

  /* Geometry */
  --dd-radius-sm: 4px;
  --dd-radius-md: 7px;
  --dd-radius-lg: 10px;
}
```

My recommended default appearance is a navy application frame surrounding a warm-cloud workspace, with white operational surfaces, teal actions, and tightly controlled amber waypoints. That would feel directly related to the logo without saturating every screen in brand color.  
