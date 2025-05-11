#!/bin/bash
set -e

# Wait for InfluxDB to be available
echo "Waiting for InfluxDB to start..."
until curl -s http://localhost:8086/ping > /dev/null; do
  sleep 1
done
echo "InfluxDB is up and running"

# Read variables from environment or use defaults
INFLUX_HOST=${DOCKER_INFLUXDB_INIT_HOST:-http://localhost:8086}
INFLUX_ORG=${DOCKER_INFLUXDB_INIT_ORG:-my-org}
INFLUX_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-super-secret-token}

# Array of project names to create
PROJECTS=("performance-test-project" "load-test-project" "stress-test-project")

# Create buckets for each project
for project in "${PROJECTS[@]}"; do
  echo "Creating bucket/project: $project"

  # Check if bucket already exists
  if influx bucket list --token $INFLUX_TOKEN --host $INFLUX_HOST | grep -q "$project"; then
    echo "Bucket '$project' already exists - skipping creation"
  else
    # Create the bucket with 30d retention
    influx bucket create --token $INFLUX_TOKEN --host $INFLUX_HOST --org $INFLUX_ORG --name "$project" --retention 30d
    echo "Created bucket '$project'"

    # Configure appropriate permissions for the token to write to this bucket
    BUCKET_ID=$(influx bucket list --name "$project" --token $INFLUX_TOKEN --host $INFLUX_HOST -o $INFLUX_ORG | grep "$project" | awk '{print $1}')

    if [ ! -z "$BUCKET_ID" ]; then
      echo "Granting write access to bucket '$project' for the admin token"
      influx auth create --token $INFLUX_TOKEN --host $INFLUX_HOST \
        --org $INFLUX_ORG \
        --description "JMeter integration token for $project" \
        --write-bucket $BUCKET_ID
    else
      echo "Warning: Could not find bucket ID for '$project'"
    fi
  fi
done

# Create specific JMeter configuration for the performance project
echo "Setting up JMeter configuration for performance testing project..."
cat > /tmp/jmeter-example.json << 'EOL'
{
  "name": "jmeter-backend-listener",
  "description": "JMeter Backend Listener Configuration",
  "project": "performance-test-project",
  "measurement": "jmeter",
  "fields": {
    "count": "# of samples",
    "avg": "Average response time",
    "min": "Min response time",
    "max": "Max response time",
    "pct90.0": "90th percentile",
    "pct95.0": "95th percentile",
    "pct99.0": "99th percentile",
    "hit_rate": "Hits per second",
    "error_rate": "Errors per second"
  },
  "tags": {
    "application": "The application name",
    "transaction": "The transaction name",
    "status": "ok or ko"
  }
}
EOL

echo "All projects (buckets) have been created successfully!"
echo "JMeter configuration template created in /tmp/jmeter-example.json"
echo ""
echo "===== INSTRUCTIONS FOR JMETER INTEGRATION ====="
echo "To use with JMeter, configure the Backend Listener:"
echo "1. Add a Backend Listener to your JMeter test plan"
echo "2. Select 'org.influxdb.jmeter.InfluxdbBackendListenerClient'"
echo "3. Configure parameters:"
echo "   - influxdbUrl: http://localhost:8086/api/v2/write"
echo "   - influxdbToken: $INFLUX_TOKEN"
echo "   - influxdbOrg: $INFLUX_ORG"
echo "   - influxdbBucket: [select one of: ${PROJECTS[*]}]"
echo "   - application: YourApplicationName"
echo "   - measurement: jmeter"
echo "===== END INSTRUCTIONS ====="
