#!/bin/bash

# Porkbun API credentials
API_KEY="YOUR_API_KEY"
SECRET_KEY="YOUR_SECRET_KEY"

# File to store the last known IP
IP_FILE="/root/.last_known_ip"

# Log file
LOG_FILE="/var/log/porkbun_dns_update.log"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to validate API credentials
validate_credentials() {
    local response
    response=$(curl -s -X POST "https://api.porkbun.com/api/json/v3/ping" \
        -H "Content-Type: application/json" \
        -d '{
            "secretapikey": "'"$SECRET_KEY"'",
            "apikey": "'"$API_KEY"'"
        }')
    
    if [[ $(echo "$response" | jq -r '.status') == "SUCCESS" ]]; then
        log_message "INFO" "API credentials validated successfully"
        return 0
    else
        log_message "ERROR" "API credential validation failed: $(echo "$response" | jq -r '.message')"
        return 1
    fi
}

# Function to update DNS record
update_dns_record() {
    local domain="$1"
    local subdomain="$2"
    local new_ip="$3"

    local update_response
    update_response=$(curl -s -X POST "https://api.porkbun.com/api/json/v3/dns/editByNameType/$domain/A/$subdomain" \
        -H "Content-Type: application/json" \
        -d '{
            "secretapikey": "'"$SECRET_KEY"'",
            "apikey": "'"$API_KEY"'",
            "content": "'"$new_ip"'",
            "ttl": "600"
        }')

    log_message "DEBUG" "Update response for $subdomain.$domain:"
    log_message "DEBUG" "$update_response"

    if [ "$(echo "$update_response" | jq -r '.status')" == "SUCCESS" ]; then
        log_message "SUCCESS" "Updated $subdomain.$domain to $new_ip"
    else
        log_message "ERROR" "Failed to update $subdomain.$domain: $(echo "$update_response" | jq -r '.message')"
    fi
}

# Get the current public IP
CURRENT_IP=$(curl -s https://api.ipify.org)

# Check if the IP has changed
if [ ! -f "$IP_FILE" ] || [ "$CURRENT_IP" != "$(cat "$IP_FILE")" ]; then
    OLD_IP=$(cat "$IP_FILE" 2>/dev/null)
    log_message "INFO" "IP changed from $OLD_IP to $CURRENT_IP"

    # Validate API credentials
    if ! validate_credentials; then
        log_message "FATAL" "Exiting due to invalid API credentials"
        exit 1
    fi

    # Get list of all domains
    DOMAINS_RESPONSE=$(curl -s -X POST "https://api.porkbun.com/api/json/v3/domain/listAll" \
        -H "Content-Type: application/json" \
        -d '{
            "secretapikey": "'"$SECRET_KEY"'",
            "apikey": "'"$API_KEY"'"
        }')

    # Extract domains from the response
    DOMAINS=$(echo "$DOMAINS_RESPONSE" | jq -r '.domains[].domain')

    for DOMAIN in $DOMAINS; do
        log_message "INFO" "Checking domain: $DOMAIN"

        # Get all DNS records for the domain
        DNS_RECORDS=$(curl -s -X POST "https://api.porkbun.com/api/json/v3/dns/retrieve/$DOMAIN" \
            -H "Content-Type: application/json" \
            -d '{
                "secretapikey": "'"$SECRET_KEY"'",
                "apikey": "'"$API_KEY"'"
            }')

        log_message "DEBUG" "Raw API response for $DOMAIN:"
        log_message "DEBUG" "$DNS_RECORDS"

        if [ "$(echo "$DNS_RECORDS" | jq -r '.status')" != "SUCCESS" ]; then
            log_message "ERROR" "Failed to retrieve DNS records for $DOMAIN: $(echo "$DNS_RECORDS" | jq -r '.message')"
            continue
        fi

        # Find and update A records with the old IP
        echo "$DNS_RECORDS" | jq -c '.records[]' | while read -r RECORD; do
            RECORD_TYPE=$(echo "$RECORD" | jq -r '.type')
            RECORD_CONTENT=$(echo "$RECORD" | jq -r '.content')
            RECORD_NAME=$(echo "$RECORD" | jq -r '.name')

            if [ "$RECORD_TYPE" == "A" ] && [ "$RECORD_CONTENT" == "$OLD_IP" ]; then
                if [ "$RECORD_NAME" == "$DOMAIN" ]; then
                    SUBDOMAIN=""
                else
                    SUBDOMAIN="${RECORD_NAME%%.$DOMAIN}"
                fi
                log_message "INFO" "Updating record: $RECORD_NAME"
                update_dns_record "$DOMAIN" "$SUBDOMAIN" "$CURRENT_IP"
            fi
        done
    done

    # Store the new IP
    echo "$CURRENT_IP" > "$IP_FILE"
    log_message "INFO" "All matching records updated to $CURRENT_IP"
else
    log_message "INFO" "IP unchanged"
fi
