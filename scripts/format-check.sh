#!/bin/bash
echo -e "[RUBOCOP] --> Init (wait a second)"

# For now, only check Layout cops
# TODO: add other cops (and fix related issues), eg. Lint
if (bundle exec rubocop --only 'Layout' 2>/dev/null | grep 'no offenses detected' >/dev/null) ; then
    echo -e "[RUBOCOP] --> 👍 approved."
    exit 0
else
    bundle exec rubocop --only 'Layout'
    echo -e "[RUBOCOP] --> ✋ You've got some offenses."
    echo -e "Run \"bundle exec rubocop --only 'Layout' -a\" to fix them."
    exit 1
fi
