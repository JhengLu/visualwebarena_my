#!/bin/bash
set -e  # Exit on error

# Get the IP address (default to 130.127.133.221, or pass as argument)
IP_ADDRESS="${1:-130.127.133.221}"

echo "Generating SSL certificate for IP: $IP_ADDRESS"

# Create OpenSSL configuration file
cat > openssl.cnf << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = Organization
CN = $IP_ADDRESS

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $IP_ADDRESS
EOF

# Generate the certificate
echo "Generating certificate and private key..."
openssl req -x509 -newkey rsa:4096 -nodes \
    -out cert.pem \
    -keyout key.pem \
    -days 365 \
    -config openssl.cnf

# Verify the certificate
echo ""
echo "Certificate generated successfully!"
echo "Certificate details:"
openssl x509 -in cert.pem -text -noout | grep -A 1 "Subject:"
openssl x509 -in cert.pem -text -noout | grep -A 2 "Subject Alternative Name"

# Clean up config file
rm openssl.cnf

echo ""
echo "Files created:"
echo "  - cert.pem (certificate - safe to share)"
echo "  - key.pem (private key - keep secret!)"
echo ""
echo "To use with Flask:"
echo "  flask run --host=0.0.0.0 --port=4399 --cert=cert.pem --key=key.pem"
