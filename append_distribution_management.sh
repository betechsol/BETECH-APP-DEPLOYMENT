#!/bin/bash
# filepath: ./append_distribution_management.sh

POM_FILE="betech-login-backend/pom.xml"

DISTRIBUTION_MANAGEMENT_TEMPLATE='
<distributionManagement>
    <repository>
      <id>nexus</id>
      <name>BETECH Solutions Releases Nexus Repository</name>
      <url>${NEXUS_URL}/repository/${NEXUS_REPOSITORY}-releases/</url>
    </repository>
    <snapshotRepository>
      <id>nexus</id>
      <name>BETECH Solutions Snapshot Nexus Repository</name>
      <url>${NEXUS_URL}/repository/${NEXUS_REPOSITORY}-snapshot/</url>
    </snapshotRepository>
</distributionManagement>
'

# Export variables for envsubst
export NEXUS_URL
export NEXUS_REPOSITORY

# Generate the section with envsubst
DISTRIBUTION_MANAGEMENT=$(echo "$DISTRIBUTION_MANAGEMENT_TEMPLATE" | envsubst)

# Insert after </dependencies>
awk -v dm="$DISTRIBUTION_MANAGEMENT" '
/<\/dependencies>/ && !x {print; print dm; x=1; next} 1
' "$POM_FILE" > "${POM_FILE}.tmp" && mv "${POM_FILE}.tmp" "$POM_FILE"