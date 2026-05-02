----------------------------------------
- Docker-Build
----------------------------------------

-  Create the application directory structure
---------------------------------------------------------------
mkdir -p application/src

- Navigate to the source directory

cd application/src

cat << EOF > index.php
<?php
echo "Hello, It's a Test Demo !";
?>
EOF

cd application

cat << EOF > Dockerfile
FROM php:7.4-apache
COPY src/ /var/www/html/
EXPOSE 80
EOF

# tree application
.
├── Dockerfile
└── src
    └── index.php

- Build the Docker image
---------------------------------------------------------------
cd application
docker build -t test-demo .

docker build -t test-demo .

docker run -d -p 8080:80 test-demo

---------------------------------------------------------------
- Create a local registry
---------------------------------------------------------------
  docker run -d -p 5000:5000 --name registry registry:2

---------------------------------------------------------------
- Access the local registry
---------------------------------------------------------------
echo "Local registry is running at http://localhost:5000"

docker tag test-demo localhost:5000/test-demo

---------------------------------------------------------------
- Push the image to the local registry
---------------------------------------------------------------
docker push localhost:5000/test-demo

---------------------------------------------------------------
- List all Docker images
---------------------------------------------------------------
docker images

---------------------------------------------------------------
- Deploy the application using Kubernetes
---------------------------------------------------------------

kubectl create deployment test-demo --image=localhost:5000/test-demo
kubectl get pods
kubectl expose deployment test-demo --port=80 --type=NodePort --target-port=80 --name=test-demo-service
kubectl get services

---------------------------------------------------------------
- Check from the browser
---------------------------------------------------------------
http://NodePort:Port

kubectl scale deployment test-demo --replicas=3
kubectl get pods
kubectl describe deployment test-demo

---------------------------------------------------------------
- To make changes
---------------------------------------------------------------
kubectl edit deployment test-demo

---------------------------------------------------------------
- To delete deployment
---------------------------------------------------------------
kubectl delete deployment test-demo
kubectl delete service test-demo-service
