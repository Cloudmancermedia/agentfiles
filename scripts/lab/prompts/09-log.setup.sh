#!/bin/bash
# A 6,000-line, 428KB log with a known answer: 400 ERROR lines, most common message
# "upstream timeout after 3000ms" (247). Too big to read raw without paying for it.
set -euo pipefail
mkdir -p logs
awk 'BEGIN {
  srand(7)
  e = 0; t = 0
  for (i = 1; i <= 6000; i++) {
    ts = sprintf("2026-10-28T%02d:%02d:%02dZ", int(i/3600)%24, int(i/60)%60, i%60)
    if (i % 15 == 0 && e < 412) {
      e++
      if (t < 247) { t++; msg = "upstream timeout after 3000ms" }
      else if (e % 2) msg = "config.retries is undefined"
      else msg = "ECONNRESET reading from cache"
      printf "%s ERROR req=%05d %s\n", ts, i, msg
    } else {
      printf "%s INFO req=%05d handled GET /api/items/%d in %dms\n", ts, i, int(rand()*900), int(rand()*400)
    }
  }
}' > logs/app.log
git add logs && git -c user.name=lab -c user.email=lab@localhost commit -qm "add log"
