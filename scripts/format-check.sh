#!/bin/bash
echo -e "[RUBOCOP] --> Init (wait a second)"

if (bundle exec rubocop -x 2>/dev/null | grep 'no offenses detected' >/dev/null) ; then
    echo -e "[RUBOCOP] --> 👍 approved."
    exit 0
else
    echo -e "[RUBOCOP] --> ✋ You've got some offenses - run "'`bundle exec rubocop -x`'
    exit 1
fi
