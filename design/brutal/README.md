# Brutal: a neo-brutalist Taskwise

## The idea

Taskwise looks like a desk covered in paper cards. Every block (a list of tasks, a button, a dialog) has a 2 px dark outline and a hard shadow with no blur, as if it were cut from card stock and laid on cream paper. Colour is flat and sparing. Five colours mark structure: yellow means "here" or "now" (the current tab, today, the selected chip), tomato means overdue, and lilac, mint and cobalt label the other sections. The task rows themselves stay plain, dark text on white, so a list of 50 tasks still reads calmly. Buttons sink into their shadow when you hover over them (halfway) and when you press them (all the way), in 150 ms.

Fonts: **Space Grotesk** for Latin text and **Alexandria** for Arabic. Both are geometric, both have a heavy bold, and both use the SIL Open Font License (`app/assets/fonts/OFL-*.txt`). They replace Noto Sans.

Colours, light: ink `#141414`, paper `#F7F0E1`, cards `#FFFDF8`, yellow `#FFD23F`, cobalt `#3355FF`, tomato `#FF6B4A`, mint `#3DDC97`, lilac `#C4B5FD`.
Dark mode ("warm charcoal", picked from three options) is the light mode at night: a warm brown-grey ground (`#3B342E`), cream text and lines (`#F1E8D7`), near-black hard shadows, and the same colour blocks outlined in dark ink. Buttons use a lighter blue (`#98ACFF`) so they read on the dark cards.

## What changed, screen by screen

**Navigation.** On desktop, a side rail with the Taskwise mark at the top; the current tab is a raised yellow block. On the phone, the bottom bar has an ink rule on top and the same yellow block for the current tab. The sync status icon is still at the bottom of the rail on desktop and next to the title on the phone.

**Tasks.** The title now carries two small labels: how many tasks are open and how many are overdue (they count what the current search and filters show). Quick add is the biggest control on the page, with a yellow "+" and, on desktop, a `Ctrl` `N` hint. Each group (Overdue, Today, Tomorrow...) gets a coloured, clickable label in capitals with its count; the group's tasks sit together in one white card. Rows have a square checkbox that fills mint with a check when done, a small square colour swatch for the category, and a coloured flag block for priority. Overdue dates are bold red. The selected task gets a thick bar on its leading edge. The sync banner is a lilac card with a yellow Connect button.

**Keyboard shortcuts (desktop).** `Ctrl+N` jumps to quick add, `Ctrl+F` to search, `Esc` closes the task panel. The empty task panel lists them.

**Empty states.** A big tilted yellow card with a check and a headline, "Your list is empty", above the old sentence. The "no results" and "select a task" states use the same tilted card in lilac.

**Task detail.** Close, done and delete are square buttons at the top. The title is large and bold. Date, time and repeat sit together in one card, each with a coloured icon block (yellow, lilac, mint). Reminders, priority, category, tags, notes and subtasks have small capital labels. Chips stand up from the page; a selected chip is pressed flat and turns yellow.

**Calendar.** A large month title with a yellow "This week" / "This month" label (or a Today button when you have moved away). Mode switch and arrows are square buttons. In the week view today's column is a raised card with a yellow header; task chips have a thin outline and a coloured edge. The month grid sits in one outlined card; today's number is a yellow square, and on phones the task dots are small squares.

**Settings.** Each section starts with a coloured label on a full-width ink rule. Selected options are solid cobalt with white text, as before.

**Dialogs, menus, sheets, date and time pickers, snackbars, the map picker.** All use the same outline and hard shadow. The Undo snackbar is ink with a yellow outline.

**App icon.** A yellow block with a heavy check and a hard shadow, the same as the mark in the rail. Updated for iOS, Windows (`app_icon.ico`), the Linux package and the tray.

**Arabic.** Layout mirrors as before. Shadows fall down and to the left in Arabic, instead of down and to the right, so the light still comes from the reading side. Long Arabic weekday names shrink to fit the narrow phone calendar columns.

## Why

- Thick outlines and colour blocks make the structure visible at a glance: where a group starts, which tab is open, what is selected. The rows stay quiet, so the bold parts don't compete with your tasks.
- The press-into-shadow motion gives a subtle hover animation, and it is clear on touch screens too.
- One accent per meaning (yellow = now/selected, tomato = overdue) means colour carries information instead of decoration.
- Square, bordered controls are large and easy to hit at 390 × 844.

## How it is built

- `app/lib/ui/designs/brutal/theme/brutal.dart`: the palette (`BrutalTheme`) and `BrutalBorder`, a shape that draws the outline and the hard shadow. The theme gives it to cards, buttons, chips, menus and dialogs, so standard Flutter widgets pick up the look, and Flutter's shape animation gives the press effect.
- `app/lib/ui/designs/brutal/common/brutal_widgets.dart`: raised boxes, the press-able block, square icon buttons, labels ("stickers"), key caps, and `CardSlice`, which draws one card across many list rows, so long lists are still built lazily.
- No new packages. The fonts are static weights (400, 500, 700) cut from the Google Fonts variable files with fontTools.

## Tests I changed

- `test/widget/app_test.dart`: the navigation finders now look for `BrutalNavRail` / `BrutalNavBar` instead of Material's `NavigationRail` / `NavigationBar`, and the group-header finders look for the capitalised names ("TODAY", "NO DATE", "COMPLETED"). The checks themselves are unchanged.
- The Settings list now builds rows only once they are on screen, and the "Saved places" row and the default radius chips are one list item. The location integration test taps rows straight after scrolling, before the next frame, so it needs the row on screen when it is first found.

## Not finished

- The pages behind Settings (categories, saved places, devices, sign-in, location debug) only pick up the theme; I didn't redesign their layouts.
- The category colour choices are still the old mid-tone palette, so existing categories keep their colours.
- The press animation on standard Material buttons (Connect, Save, chips) always takes 150 ms; it does not follow the system "reduce motion" setting. The custom blocks (navigation, icon buttons, group labels) do follow it.
- In the phone week view, columns are about 50 px wide, so long task titles still break mid-word, as before.
