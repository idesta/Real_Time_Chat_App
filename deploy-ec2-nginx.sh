#!/bin/bash

set -e

echo "===== Step 1: Launch EC2 ====="

AMI_ID=ami-0ec10929233384c7f
INSTANCE_TYPE="t2.micro"
KEY_NAME="EC2DeployKey"
SG_NAME="EC2DeploySG"

rm -f ${KEY_NAME}.pem
aws ec2 delete-key-pair --key-name $KEY_NAME || true

aws ec2 create-key-pair \
  --key-name $KEY_NAME \
  --query 'KeyMaterial' \
  --output text > ${KEY_NAME}.pem

chmod 400 ${KEY_NAME}.pem

SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=$SG_NAME \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
  VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)

  SG_ID=$(aws ec2 create-security-group \
    --group-name $SG_NAME \
    --description "Deploy SG" \
    --vpc-id $VPC_ID \
    --query 'GroupId' --output text)
fi

# Only allow SSH + HTTP (NO backend port!)
for PORT in 22 80; do
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port $PORT \
    --cidr 0.0.0.0/0 || true
done

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --query 'Instances[0].InstanceId' \
  --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "EC2 Public IP: $PUBLIC_IP"

echo "Waiting for SSH..."
while ! nc -z -w5 $PUBLIC_IP 22; do sleep 5; done

echo "===== Step 2: Setup App + Nginx ====="

ssh -o StrictHostKeyChecking=no -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP <<EOF
set -e

echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y curl git build-essential nginx

echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

sudo npm install -g pm2

mkdir -p ~/app && cd ~/app

git clone -b feature/aws-cli-and-sdk https://github.com/idesta/Real_Time_Chat_App.git
cd Real_Time_Chat_App

# =========================
# BACKEND SETUP
# =========================
cd backend

cat > .env <<EOL
MONGODB_URI=mongodb+srv://idesta705_db_user:dLx3WuW8wO149JyO@cluster0.2hfqb3a.mongodb.net/?appName=Cluster0
#sO3Qn9K3DlBjXutE
#kAEMMC0yDIkeT0SV
#dLx3WuW8wO149JyO

PORT=5001

JWT_SECRET=mysecretkey

NODE_ENV=development

CLOUDINARY_CLOUD_NAME=dtbyipqeg
CLOUDINARY_API_KEY=116845729211256
CLOUDINARY_API_SECRET=hsBQq69WlV9IIDT5o393ch055JI


#CLIENT_URL=http://localhost:5173
EOL

npm install

# FORCE backend to localhost (important!)
pm2 start npm --name backend -- run dev -- --host 127.0.0.1

# =========================
# FRONTEND SETUP
# =========================
cd ../frontend

cat > .env <<EOL
VITE_BACKEND_URL=/api
EOL

npm install
npm run build

# =========================
# NGINX CONFIG
# =========================
sudo rm -f /etc/nginx/sites-enabled/default

sudo tee /etc/nginx/sites-available/app <<NGINXCONF
server {
    listen 80;

    root /home/ubuntu/app/Real_Time_Chat_App/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5001/;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;

        proxy_cache_bypass $http_upgrade;
    }
}

NGINXCONF

sudo ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
sudo chmod -R 755 /home/ubuntu/app
sudo chmod o+x /home/ubuntu
sudo chmod o+x /home/ubuntu/app
sudo chmod o+x /home/ubuntu/app/Real_Time_Chat_App
sudo chmod o+x /home/ubuntu/app/Real_Time_Chat_App/frontend
sudo nginx -t
sudo systemctl restart nginx
pm2 restart backend

pm2 save
pm2 startup | grep sudo | bash

echo "===== DEPLOYMENT DONE ====="
EOF

echo "===================================="
echo "APP URL: http://$PUBLIC_IP"
echo "Backend is PRIVATE (secured)"
echo "===================================="