#!/bin/bash

if [[ -z "$WHITESOURCE_API_KEY" ]]; then
  echo "WHITESOURCE_API_KEY has not been set, please set it up in the project environment variables since its mandatory"
  exit 1
fi

echo apiKey="${WHITESOURCE_API_KEY}" >>scripts/whitesource/agent.config
echo scanComment="${BRANCH}-${GITHUB_RUN_ID}" >>scripts/whitesource/agent.config

if [[ -f install_commands.sh ]]; then
  echo "Executing file: install_commands.sh"
  echo ""
  chmod +x install_commands.sh
  ./install_commands.sh
fi

bash <(curl -s -L https://raw.githubusercontent.com/whitesource/unified-agent-distribution/master/standAlone/wss_agent_orb.sh) -apiKey "$WHITESOURCE_API_KEY" -c scripts/whitesource/agent.config -d .
