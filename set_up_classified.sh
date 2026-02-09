pip install --upgrade gdown
gdown https://drive.google.com/uc?id=1m79lp84yXfqdTBHr6IS7_1KkL4sDSemR

unzip -o classifieds_docker_compose.zip
cd classifieds_docker_compose

# Auto-detect public IP if SERVER_HOSTNAME is not set
if [ -z "$SERVER_HOSTNAME" ]; then
    echo "Detecting public IP address..."
    SERVER_HOSTNAME=$(curl -s ip.sb)

    if [ -z "$SERVER_HOSTNAME" ]; then
        echo "Warning: Failed to auto-detect IP. Defaulting to 127.0.0.1"
        SERVER_HOSTNAME="127.0.0.1"
    else
        echo "Detected IP: $SERVER_HOSTNAME"
    fi
fi

# Set CLASSIFIEDS to your site url
sed -i "s|CLASSIFIEDS=.*|CLASSIFIEDS=https://${SERVER_HOSTNAME}:9980/|" docker-compose.yml
echo "CLASSIFIEDS set to: https://${SERVER_HOSTNAME}:9980/"

# Optional: change reset token if needed
# RESET_TOKEN="${RESET_TOKEN:-4b61655535e7ed388f0d40a93600254c}"
# sed -i "s|RESET_TOKEN=.*|RESET_TOKEN=${RESET_TOKEN}|" docker-compose.yml

docker compose up --build -d

# Wait for compose up to finish. This may take a while on the first launch as it downloads several large images from dockerhub.
echo "Waiting for database to be ready..."
sleep 30

# Wait for MySQL to be ready to accept connections
until docker exec classifieds_db mysqladmin ping -u root -ppassword --silent 2>/dev/null; do
    echo "Waiting for MySQL to be ready..."
    sleep 5
done

echo "Database is ready. Populating with content..."
docker exec classifieds_db mysql -u root -ppassword osclass -e 'source docker-entrypoint-initdb.d/osclass_craigslist.sql'  # Populate DB with content