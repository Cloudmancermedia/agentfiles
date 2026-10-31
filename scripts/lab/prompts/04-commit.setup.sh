#!/bin/bash
set -euo pipefail
# Stage a change for the commit-message prompt.
perl -pi -e 's/retries: 3,/retries: 5,/' src/config.js
perl -pi -e 's/retries, 3\)/retries, 5)/' test/report.test.js
git add -A
