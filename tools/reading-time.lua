--[[
Put an automatic "Length" field in the title block, next to Author and Modified.

Counts the words a reader actually reads -- the markdown prose plus the text
inside any {=html} fences -- and exposes the result as a `reading-time`
metadata field, rendered by _includes/title-metadata.html.

The default rate sits below the 230-250 wpm usually quoted for non-fiction:
this is dense technical prose, and most bullets are a separate idea the
reader stops on. Override it in _quarto.yml with `reading-time-wpm`.
--]]

local DEFAULT_WPM = 200

-- Only tokens with an alphanumeric in them count, so stray em dashes and
-- bullets don't inflate the total.
local function count_words(text)
  local n = 0
  for token in text:gmatch("%S+") do
    if token:find("%w") then n = n + 1 end
  end
  return n
end

-- Strip an HTML fragment down to the prose the reader sees.
local function html_text(html)
  html = html:gsub("<!%-%-.-%-%->", " ")
  html = html:gsub("<%s*[sS][cC][rR][iI][pP][tT].-<%s*/%s*[sS][cC][rR][iI][pP][tT]%s*>", " ")
  html = html:gsub("<%s*[sS][tT][yY][lL][eE].-<%s*/%s*[sS][tT][yY][lL][eE]%s*>", " ")
  html = html:gsub("<[^>]*>", " ")
  html = html:gsub("&nbsp;", " ")
  -- Other entities (&rsquo; and friends) sit inside a word; dropping them
  -- keeps "don&rsquo;t" one word instead of two.
  html = html:gsub("&#?%w+;", "")
  return html
end

local function round_to(value, step)
  return math.floor(value / step + 0.5) * step
end

local function commas(n)
  local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,")
  s = s:reverse():gsub("^,", "")
  return s
end

local function duration(minutes)
  if minutes < 75 then
    return string.format("%d-minute read", math.max(5, round_to(minutes, 5)))
  end
  local half_hours = math.max(2, round_to(minutes / 30, 1))
  local hours = math.floor(half_hours / 2)
  if half_hours % 2 == 1 then
    return string.format("%d\u{00BD}-hour read", hours)
  end
  return string.format("%d-hour read", hours)
end

function Pandoc(doc)
  local words = 0
  local count = {
    Str = function(el)
      if el.text:find("%w") then words = words + 1 end
    end,
    -- Inline code is short prose here ("the `id` field"), so it reads like
    -- the sentence around it. Code *blocks* hold no Str and never reach this.
    Code = function(el)
      words = words + count_words(el.text)
    end,
    RawBlock = function(el)
      if el.format:find("html") then
        words = words + count_words(html_text(el.text))
      end
    end,
  }
  pandoc.walk_block(pandoc.Div(doc.blocks), count)

  local wpm = DEFAULT_WPM
  local configured = doc.meta["reading-time-wpm"]
  if configured then
    wpm = tonumber(pandoc.utils.stringify(configured)) or DEFAULT_WPM
  end

  doc.meta["reading-time"] = pandoc.MetaInlines{
    pandoc.Str(string.format("~%s words \u{00B7} %s",
                             commas(round_to(words, 1000)),
                             duration(words / wpm)))
  }
  return doc
end
