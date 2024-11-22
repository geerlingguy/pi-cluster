#!/bin/bash
set -e

# wrk and ab load test script
#
# Usage:
#   # Make sure wrk and ab are installed.
#   $ brew install wrk
#
#   # Grab the authenticated session cookie from a logged-in window:
#   1. Open browser's dev console.
#   2. Navigate to storage/cookies.
#   3. Right-click on the 'SESSxxxx' cookie and copy it.
#   4. Paste the cookie in `AUTHENTICATED_SESSION_COOKIE` before running script.
#
#   # Run the load tests.
#   $ ./drupal-benchmark.sh
#
# Author: Jeff Geerling, 2023

printf "\n"
printf "Drupal benchmarks.\n"

# Variables. Best to use IP address to prevent `ab` errors.
DRUPAL_URL="http://10.0.2.61/"
AUTHENTICATED_SESSION_COOKIE="SESS3747f176b3220dbe6938dbbc37681fd0=VsCYFTA3-5A16oYGR%2Cer%2C7-wm53P3wLnN8ZKIlVmnyHqfR2D"
# Install dependencies.
if [ ! `which ab` ]; then
  printf "Please install apachebench (ab) and try again.\n\n"
fi
if [ ! `which wrk` ]; then
  printf "Please install wrk (wrk) and try again.\n\n"
fi

# Run benchmarks.
printf "Running wrk anonymous page load benchmark...\n"
curl -s -o /dev/null $DRUPAL_URL # Load once to fill caches.
sleep 2
wrk -t4 -c100 -d30 --timeout 10s $DRUPAL_URL
printf "\n"

printf "Running ab authenticated page load benchmark...\n"
ab -n 1 -c 1 -C "SESSxyz=XYZ" $DRUPAL_URL >/dev/null # Load once to fill caches.
sleep 2
ab -n 700 -c 10 -C "$AUTHENTICATED_SESSION_COOKIE" $DRUPAL_URL
printf "\n"

printf "Drupal benchmark complete!\n\n"
