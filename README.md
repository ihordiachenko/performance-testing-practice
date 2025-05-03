# Performance Testing Practice

## Pre-requisites
- Docker
- Docker Compose
- JMeter

## Running Grafana

```bash
docker-compose up -d
```

## Accessing Grafana

Once the containers are running, you can access Grafana at:
- URL: http://localhost:4000
- Username: admin
- Password: admin123 (or the value set in GF_ADMIN_PASSWORD environment variable)

### Available Dashboards

The following dashboards are automatically provisioned:

1. **JMeter Dashboard** - A comprehensive dashboard for visualizing JMeter test results.
   This dashboard provides metrics for response times, throughput, errors, and more.

