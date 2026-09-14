# mmd-preview

Live browser preview of a [Mermaid](https://mermaid.js.org) diagram with your own CSS.
Point it at a `.mmd` file, it opens a page and re-renders whenever you save — the
diagram or the stylesheet.

```sh
bin/mmd-preview docs/architecture.mmd theme.css
```

---

## Requirements

| | |
|---|---|
| Ruby | 4.0.5 (see `.ruby-version`) |
| `mmdc` | [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) |
| A browser | Chrome or Chromium, for `mmdc` to render in |

`mmd-preview` checks all three before it renders anything, and prints the exact
commands to fix whatever is missing. It only ever detects — it never installs.

## Install

```sh
bundle install
brew install mermaid-cli        # or: npm install -g @mermaid-js/mermaid-cli
```

### Giving mmdc a browser

`mmdc` drives a headless browser through puppeteer, and puppeteer will not find
an ordinary Chrome install on its own. If you already have Chrome, point it
there — create `~/.config/mmd-preview/puppeteer.json`:

```json
{
  "executablePath": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "headless": "new",
  "args": ["--font-render-hinting=none"]
}
```

Or let puppeteer fetch its own:

```sh
npx -y puppeteer browsers install chrome
```

`XDG_CONFIG_HOME` is honoured if set. The file is re-checked on every render, so
you can write it mid-session without restarting.

## Usage

```
usage: mmd-preview DIAGRAM.mmd [STYLE.css] [options]
    -c, --css FILE          stylesheet (same as the second positional argument)
    -t, --theme NAME        mermaid theme: default | forest | dark | neutral
    -b, --background COLOR  SVG background (default: transparent)
    -p, --port N            port to serve on (default: ephemeral)
    -B, --browser NAME      open in a specific app, e.g. "Google Chrome"
    -n, --no-open           don't open a browser, just print the URL
    -h, --help              show this message
```

The server is loopback-only and serves out of a temp directory that is removed
on exit. `Ctrl-C` stops it.

---

## Styling: how your CSS reaches the diagram

This is the part that surprises people, so it is worth reading once.

Your stylesheet is delivered through **two independent channels**, and which
selectors work depends on which channel can carry them.

### Channel 1 — into the SVG, as mermaid's `themeCSS`

Your file is written into a temporary mermaid config as `themeCSS`. Mermaid
prefixes **every selector with the diagram's id** and emits the result *after*
its own theme rules. So `.node rect { … }` becomes `#my-svg .node rect { … }`.

This is the channel that matters, because mermaid's own theme CSS is scoped the
same way:

```css
#my-svg .node rect, … { fill:#ECECFF; stroke:#9370DB; stroke-width:1px; }  /* theme */
#my-svg .node rect     { stroke-width: 2px; }                              /* yours */
```

Equal specificity, yours emitted later — so **yours wins, with no `!important`
needed**. A bare `.node rect` rule delivered any other way would lose: one id
beats any number of classes, whatever the order.

### Channel 2 — into the page, as a linked stylesheet

The same file is also served as `user.css` and linked by the preview page. The
SVG is inlined into that page, inside `<div class="stage mermaid">`.

This channel reaches everything *outside* the SVG, and it is where `:root` and
`@media` actually work.

### What works where

| What you write | Channel 1 (SVG) | Channel 2 (page) | Result |
|---|---|---|---|
| `.node rect { … }` | ✅ scoped, beats theme | applies but outranked | **works, no `!important`** |
| `:root { --tok: … }` | ✗ becomes `#my-svg :root`, matches nothing | ✅ | **declare tokens here** |
| `.mermaid .node rect { … }` | ✗ no `.mermaid` inside the SVG | ✅ | works, but needs `!important` |
| `body`, `.canvas`, `.bar` | ✗ outside the SVG | ✅ | styles the preview frame |
| `@media (prefers-color-scheme: dark)` | ✅ | ✅ | works |
| `@import url(…)` | ✗ rejected outright | ✅ | see *Fonts* below |

### The recommended recipe

Plain mermaid selectors, with tokens on `:root`. Custom properties inherit from
`<html>` down into the inlined SVG, so a token declared in channel 2 resolves
inside a rule delivered by channel 1:

```css
:root {
  --diagram-ink:  #201e1d;
  --diagram-fill: #eae7e7;
}
@media (prefers-color-scheme: dark) {
  :root { --diagram-ink: #bab6b6; --diagram-fill: #383535; }
}

.node rect {
  fill: var(--diagram-fill);
  stroke: var(--diagram-ink);
  stroke-width: 2px;
}
.edgePath .path, .flowchart-link { stroke: var(--diagram-ink); stroke-width: 2px; }
.cluster rect                    { fill: none; stroke: var(--diagram-ink); }
.nodeLabel, .edgeLabel           { font-family: "IBM Plex Sans", sans-serif; }
```

No `!important` anywhere.

### If you already have a browser-embed stylesheet

Most published "mermaid stylesheets" are written for mermaid running *in a
browser*, where `mermaid.initialize()` renders into `<div class="mermaid">`.
Every selector in them is `.mermaid`-prefixed:

```css
.mermaid g.node rect { fill: var(--x) !important; }
```

Those work here unchanged — the preview page puts `class="stage mermaid"` on the
diagram container precisely so they do. They rely on channel 2, which is why
they need their `!important` (they are competing with an id-scoped theme) and
why their `:root` tokens resolve normally.

You do **not** need to rewrite such a sheet. Just know that it styles the
preview, not the SVG that `mmdc` writes.

---

## Gotchas

**Fonts must be installed locally.** An `@import` of Google Fonts is rejected in
channel 1 (`@import rules are not allowed here` — mermaid injects themeCSS as a
constructed stylesheet, which forbids it). Even where it is honoured, `mmdc`
does not embed font files into the SVG. Install the family on the machine and
name it in `font-family`.

**Don't reuse the frame's token names.** The preview page declares
`--paper`, `--ink`, `--muted`, `--rule`, and `--fail` on `:root` for its own
chrome. A `:root { --ink: … }` in your sheet will recolour the toolbar along with
your diagram. Prefix your tokens.

**`-t base` is not available.** `mmdc` accepts only `default`, `forest`, `dark`,
and `neutral`. `base` — the theme meant to be overridden — can still be selected
from the diagram's own frontmatter:

```yaml
---
config:
  theme: base
---
```

**Frontmatter beats the flags.** A `config:` block in the diagram overrides `-t`.
A diagram declaring `theme: base` renders with `base` even under `-t dark`. Your
stylesheet is unaffected: `themeCSS` survives frontmatter and stays ordered after
the theme.

---

## Live reload

The diagram and the stylesheet are both watched. On any change:

- the diagram is re-rendered by `mmdc`, with your CSS re-read from disk each time
- the page polls `state.json`, notices the new revision, and re-fetches the SVG
- the linked stylesheet is re-requested as `user.css?rev=N`

That last step matters: a `<link>` is fetched once at page load and never again
on its own, so without the revision key a rule you *deleted* would keep applying
until a manual reload.

A render that fails leaves the last good diagram on screen, greyed out, with
`mmdc`'s output shown above it. The revision still advances, so a CSS-only edit
lands even while the diagram is broken.

---

## Development

```sh
bundle exec rake          # standard:fix, then the full suite
bundle exec rake test
bundle exec rake standard
```

Specs live in `test/`, one per class, and stub `Open3` so nothing shells out —
except `test/integration/styling_spec.rb`, which runs the **real** `mmdc` and
asserts that your CSS comes out scoped and ordered so it wins the cascade. That
one exists because a stubbed argv cannot tell you whether the resulting CSS
actually styles anything: an earlier version passed `mmdc -C` with a perfectly
correct command line and produced diagrams that ignored the stylesheet entirely.
It skips, rather than fails, when `mmdc` or its browser is unavailable.

## Known issues

**The watcher watches whole directories.** `Watcher#directories` hands each
file's parent to [listen](https://github.com/guard/listen), which watches
recursively. Keeping your stylesheet somewhere like `~/Downloads` makes it scan
that entire tree and log warnings:

```
** ERROR: directory is already being watched! **
Directory: …/Downloads/Some.app/Contents/Frameworks/…
```

Renders are unaffected. Scoping the listener with `only:` regexes for the two
filenames would fix it.
