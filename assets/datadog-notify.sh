#!/bin/bash
#
# Based on the code from https://github.com/dvmtn/datadog-notify by
# Developer Mountain https://github.com/dvmtn
#

function usage(){
  echo "Usage:" >&2
  echo "$0 title message [error|warning|info|success] [tags...]" >&2
  echo "  title:   The title of this event            ie. 'Foo Restated'" >&2
  echo "  message: The message for this event         ie. 'Foo was restarted by monit'" >&2
  echo "  type:    The event type, one of 'info', 'error', 'warning' or 'success'" >&2
  echo "  tags:    Optional tags in key:vaule format  ie. 'app:foo group:bar" >&2
  echo >&2
  echo "Examples:" >&2
  echo "$0 'Test Event' 'This event is just for testing' 'test:true foo:bar'" >&2
  echo "$0 'Another Event' 'This event is just for testing'" >&2
  exit 1
}

set -e -u -o pipefail

title="${1:-}"
message="${2:-}"
alert_type="${3:-}"
tags="${4:-}"

dd_config='/etc/dd-agent/datadog.conf'

api_key=""

if [[ -n "$DATADOG_API_KEY" ]]; then
  api_key="$DATADOG_API_KEY"
else
  api_key=$(grep '^api_key:' $dd_config | cut -d' ' -f2)
fi

if [[ -z "$api_key" ]]; then
  echo "Could not find Datadog API key in either ${dd_config} or DATADOG_API_KEY environment variable." >&2
  echo "Please provide your API key in one of these locations" >&2
  usage
fi

if [[ -z "$title" || -z "$message" ]]; then
  usage
fi

if [[ -z "$alert_type" ]]; then
  echo "No level set, assuming 'info'" >&2
  alert_type='info'
fi

case "$alert_type" in
  ""|error|warning|info|success)
  ;;
  *)
    echo "Failed: alert_type was '$alert_type', needs to be one of 'success', 'info', 'error' or 'warning'" >&2
    echo >&2
    usage
  ;;
esac

tags=$(echo "$tags" | sed 's/\s\+/\",\"/g;s/^/\"/;s/$/"/'  )

api="https://app.datadoghq.com/api/v1"
datadog="${api}/events?api_key=${api_key}"

payload=$(cat <<-EOJ
  {
    "title": "$title",
    "text": "$message",
    "tags": [$tags],
    "alert_type": "$alert_type"
  }
EOJ
)

curl -s -X POST -H "Content-type: application/json" -d "$payload" "$datadog"
