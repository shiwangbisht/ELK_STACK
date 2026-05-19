ELK Reliability Enhancement: Filebeat Disk Queue & Logstash Persistent Queue

Overview
This document outlines the implementation of buffering mechanisms within the ELK logging pipeline to prevent log loss during temporary service outages.

> Current Flow
Application Logs
      ↓
   Filebeat
      ↓
   Logstash
      ↓
Elasticsearch
      ↓
   Kibana


> Enhanced Flow
Application Logs
      ↓
   Filebeat
      ↓
 Filebeat Disk Queue
      ↓
   Logstash
      ↓
Logstash Persistent Queue
      ↓
Elasticsearch
      ↓
   Kibana


1. Enable Filebeat Disk Queue
Purpose: Filebeat Disk Queue allows Filebeat to temporarily store events on local disk when Logstash becomes unavailable.

This prevents log loss during:
Logstash restarts
Network interruptions
ELK server maintenance
Temporary Logstash failures

Configuration:
Edit Filebeat configuration:
sudo vi /etc/filebeat/filebeat.yml

Add the following section:

queue.disk:
  path: "${path.data}/diskqueue"
  max_size: 500MB

Parameter Details
Parameter	    Description
path	        Location where Filebeat stores queued events
max_size	    Maximum disk space allocated for queue storage depends on resource

Apply Changes
Restart Filebeat:
sudo systemctl restart filebeat

Verify configuration:
sudo filebeat test config

Expected output:
Config OK

Validation
Check Filebeat service status:
sudo systemctl status filebeat

Verify queue directory creation:
sudo ls -lh /var/lib/filebeat/

You should see a directory similar to:
diskqueue/

Failure Scenario
When Logstash is Down
Application Logs
      ↓
   Filebeat
      ↓
 Disk Queue
      ↓
   (Waiting)

Events are safely stored on local disk until Logstash becomes available again.

Once Logstash recovers:

Disk Queue
      ↓
   Logstash
      ↓
Elasticsearch

Queued logs are automatically forwarded.


2. Enable Logstash Persistent Queue
Purpose

Logstash Persistent Queue (PQ) stores events on disk before forwarding them to Elasticsearch.

This prevents data loss when:

Elasticsearch is unavailable
Elasticsearch is restarting
Indexing is temporarily blocked
Cluster maintenance is in progress
Target Server
Server
leopay-elk-server
Configuration

Edit Logstash configuration:

sudo vi /etc/logstash/logstash.yml

Add the following parameters:

queue.type: persisted
queue.max_bytes: 5gb
queue.drain: true
Parameter Details
Parameter	Description
queue.type	Enables persistent disk-based queue
queue.max_bytes	Maximum queue storage size
queue.drain	Ensures queue is fully drained before shutdown
Apply Changes

Restart Logstash:

sudo systemctl restart logstash
Validation

Verify queue status:

curl localhost:9600/_node/stats/pipelines?pretty

Expected output:

"queue": {
  "type": "persisted"
}
Failure Scenario
When Elasticsearch is Down
Application Logs
      ↓
   Filebeat
      ↓
   Logstash
      ↓
Persistent Queue
      ↓
  (Waiting)

Events are written to Logstash disk storage until Elasticsearch becomes available again.

After Elasticsearch recovery:

Persistent Queue
      ↓
Elasticsearch

All queued events are automatically indexed.

End-to-End Protection

With both configurations enabled:

Application Logs
      ↓
   Filebeat
      ↓
 Filebeat Disk Queue
      ↓
   Logstash
      ↓
Logstash Persistent Queue
      ↓
Elasticsearch
Protection Coverage
Failure Scenario	Protection Layer
Logstash Down	Filebeat Disk Queue
Network Interruption	Filebeat Disk Queue
Elasticsearch Down	Logstash Persistent Queue
Elasticsearch Restart	Logstash Persistent Queue
Temporary Ingestion Backpressure	Both Queues