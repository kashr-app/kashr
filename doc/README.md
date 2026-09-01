# Developer notes

Conventions that are easy to get wrong and expensive to get wrong quietly.

## Date ranges are half-open

A date range is `[startInclusive, endExclusive)` — `>= start AND < end` — and
the parameter names say which end is which. Handing an inclusive value to
something called `endExclusive` then reads wrong at the call site, which is the
whole point of spelling it out.

Half-open is the default because periods tile: one period's `endExclusive` *is*
the next one's `startInclusive`. Navigating from one to the next can neither
skip a day nor count one twice, and nothing needs a `± 1 day` to line up.

`endInclusive` is legal where it genuinely reads better — the last day in a week
label, or the newest booking date a bank download asks for — but it is the
exception, and the name has to say so.

`DownloadRange` and `DownloadRequest` are the standing example. Both ends really
are inclusive there: comdirect's `min-bookingDate` / `max-bookingDate` include
the days they name, and the user picks both edges in a date range picker. So
they say `endInclusive`, and a reader never has to go and check.
