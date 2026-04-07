# Real_Time_Chat_App

## Deployment Instructions

1. **Run the deployment script**: Execute the `deploy-ec2-nginx.sh` script to set up the EC2 instance with Nginx and deploy the application.

   ```bash
   chmod +x deploy-ec2-nginx.sh
   ./deploy-ec2-nginx.sh
   ```

2. **Access the application**: Once the deployment is complete, you can access the chat application by navigating to the public IP address of your EC2 instance in a web browser.

   ```
   http://<EC2_PUBLIC_IP>
   ```

## Notes:

- The deployment script will set up the necessary security groups, install dependencies, and configure Nginx to serve the application.
- Ensure that you have the AWS CLI installed and configured with the appropriate permissions to create and manage EC2 instances and security groups.
- The backend server is configured to run on localhost (127.0.0.1) for security reasons, and only the frontend is exposed to the public.
- Make sure to replace `<EC2_PUBLIC_IP>` with the actual public IP address of your EC2 instance when accessing the application.
- The `.gitignore` file is configured to exclude sensitive files such as the EC2 deployment keys and the deployment scripts to prevent accidental commits of these files to the repository.
- Don't forget to clean up your EC2 resources after testing to avoid unnecessary costs.
