#!/bin/bash
#
# Bootstrap script for AnythingLLM in docker-ai-stack
# Reads the LiteLLM API key from the shared volume and starts AnythingLLM
#
# This file is part of Docker AI Stack, available at:
# https://github.com/hwdsl2/docker-ai-stack
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

# Read LiteLLM API key from shared volume (wait for it to be available)
if [ -d /var/lib/litellm-shared ]; then
  echo "Waiting for LiteLLM API key..."
  for i in $(seq 1 300); do
    if [ -r /var/lib/litellm-shared/.api_key ]; then
      KEY=$(cat /var/lib/litellm-shared/.api_key)
      case "$KEY" in
        sk-*)
          export GENERIC_OPEN_AI_API_KEY="$KEY"
          echo "LiteLLM API key loaded."
          break
          ;;
      esac
    fi
    sleep 2
  done
  if [ -z "$GENERIC_OPEN_AI_API_KEY" ]; then
    echo "Warning: LiteLLM API key not found or invalid after waiting. Proceeding without it."
  fi
fi

# Start AnythingLLM using the original entrypoint
exec /usr/local/bin/docker-entrypoint.sh
