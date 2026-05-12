#!/bin/bash

ES_HOST="https://localhost:9200"
ES_USER="elastic"
ES_PASS="ydjkqbrIi3uCf9+aWfwk"
LOG_FILE="/tmp/restore_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "$1" | tee -a $LOG_FILE
}

log "${YELLOW}=== STARTING RESTORE PROCESS ===${NC}"
log "Log file: $LOG_FILE"

# Get list of unassigned indices
curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/_cat/shards/leopay-*" | \
grep UNASSIGNED | awk '{print $1}' | sort -u > /tmp/unassigned_list.txt

TOTAL=$(cat /tmp/unassigned_list.txt | wc -l)
log "${YELLOW}Found $TOTAL indices with unassigned shards${NC}"

if [ $TOTAL -eq 0 ]; then
    log "${GREEN}No unassigned shards found. Exiting.${NC}"
    exit 0
fi

log "${YELLOW}Indices to fix:${NC}"
cat /tmp/unassigned_list.txt | tee -a $LOG_FILE

read -p "Do you want to proceed with fix? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    log "${RED}Aborted by user${NC}"
    exit 1
fi

SUCCESS=0
FAILED=0

# Process each index
while read index; do
    log "\n${YELLOW}Processing: $index${NC}"
    
    # Check if index exists
    EXISTS=$(curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/$index" | jq -r '.status // "404"' 2>/dev/null)
    
    # Close index instead of delete (safer)
    log "  Closing index..."
    curl -k -u $ES_USER:$ES_PASS -s -X POST "$ES_HOST/$index/_close" > /dev/null 2>&1
    sleep 2
    
    # Restore from snapshot
    log "  Restoring from snapshot..."
    RESPONSE=$(curl -k -u $ES_USER:$ES_PASS -s -X POST "$ES_HOST/_snapshot/leopay_backup/final_combined_backup/_restore" \
    -H 'Content-Type: application/json' \
    -d "{
      \"indices\": \"$index\",
      \"ignore_unavailable\": true,
      \"include_global_state\": false
    }")
    
    if echo "$RESPONSE" | grep -q "error"; then
        log "${RED}  ERROR restoring $index${NC}"
        echo "$RESPONSE" | tee -a $LOG_FILE
        ((FAILED++))
    else
        log "${GREEN}  Successfully restored $index${NC}"
        ((SUCCESS++))
    fi
    
    # Open index
    log "  Opening index..."
    curl -k -u $ES_USER:$ES_PASS -s -X POST "$ES_HOST/$index/_open" > /dev/null 2>&1
    
    sleep 3
done < /tmp/unassigned_list.txt

log "\n${YELLOW}=== SUMMARY ===${NC}"
log "${GREEN}Successfully restored: $SUCCESS${NC}"
if [ $FAILED -gt 0 ]; then
    log "${RED}Failed: $FAILED${NC}"
fi

# Force reroute
log "\n${YELLOW}Forcing reroute...${NC}"
curl -k -u $ES_USER:$ES_PASS -X POST "$ES_HOST/_cluster/reroute?retry_failed=true&pretty" >> $LOG_FILE 2>&1

sleep 10

# Check final health
log "\n${YELLOW}Final cluster health:${NC}"
curl -k -u $ES_USER:$ES_PASS "$ES_HOST/_cluster/health?pretty" | tee -a $LOG_FILE

# Count remaining unassigned
REMAINING=$(curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/_cat/shards/leopay-*" | grep UNASSIGNED | wc -l)
log "\n${YELLOW}Remaining unassigned shards: $REMAINING${NC}"

if [ $REMAINING -eq 0 ]; then
    log "${GREEN}SUCCESS: All shards are assigned!${NC}"
else
    log "${RED}WARNING: Still have $REMAINING unassigned shards${NC}"
    curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/_cat/shards/leopay-*" | grep UNASSIGNED | awk '{print $1}' | sort -u | tee -a $LOG_FILE
fi

# Final counts
log "\n${GREEN}=== FINAL DOCUMENT COUNTS ===${NC}"
log "Cron indices:"
curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/leopay-cron-*/_count?pretty" | tee -a $LOG_FILE
log "\nOutput indices:"
curl -k -u $ES_USER:$ES_PASS -s "$ES_HOST/leopay-output-*/_count?pretty" | tee -a $LOG_FILE

log "\n${GREEN}Restore process completed. Check log: $LOG_FILE${NC}"