// Audiobook cover (square) — 3000x3000px (compile at --ppi 144: 1pt -> 2px).
// Same design as cover.typ, but square for Spotify and other audio stores.
// Run from repo root:
// quarto typst compile assets/cover-square.typ assets/cover-square.png --ppi 144
#set page(width: 1500pt, height: 1500pt, margin: 0pt, fill: rgb("#fbf9f4"))

#let teal = rgb("#0b7c72")
#let ink = rgb("#23262b")
#let muted = rgb("#555b64")

// Faint ledger rules across the whole cover (texture, nods to "the ledger").
#for i in range(0, 25) {
  place(top + left, dy: 140pt + i * 50pt,
    line(start: (110pt, 0pt), end: (1390pt, 0pt),
      stroke: 0.6pt + teal.transparentize(90%)))
}

// Double frame.
#place(top + left, dx: 70pt, dy: 70pt,
  rect(width: 1360pt, height: 1360pt, stroke: 2.5pt + teal))
#place(top + left, dx: 90pt, dy: 90pt,
  rect(width: 1320pt, height: 1320pt, stroke: 1pt + teal.transparentize(45%)))

// Title.
#place(top + left, dx: 160pt, dy: 250pt,
  block(width: 1200pt)[
    #set par(leading: 22pt)
    #text(font: "Didot", size: 160pt, weight: "bold", fill: ink)[Fintech\ Engineering\ Handbook]
  ])

// Accent rule.
#place(top + left, dx: 168pt, dy: 790pt,
  line(length: 340pt, stroke: 5pt + teal))

// Subtitle.
#place(top + left, dx: 166pt, dy: 850pt,
  block(width: 1180pt)[
    #set par(leading: 16pt)
    #text(font: "Baskerville", size: 60pt, style: "italic", fill: muted)[Patterns for building software that handles money]
  ])

// Author.
#place(bottom + left, dx: 166pt, dy: -200pt,
  text(font: "Avenir Next", size: 56pt, tracking: 3pt, weight: "medium", fill: ink)[Voytek Pitula])
