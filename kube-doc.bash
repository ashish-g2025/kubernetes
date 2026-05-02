- Deployment Resources
    Prerequisites
  A. Control Plane: 1(mininum)
  B. Worker Nodes:  2 or more

----------------------------------------------------
- Control Plane
----------------------------------------------------
	Control Plane - Manages the Kubernetes cluster, including scheduling, monitoring, and control of worker nodes
	Kublet  - Kubernetes agent that runs on each worker node
	Kubeadm - Tool for bootstrapping Kubernetes clusters
	etcd - Distributed key-value store for storing cluster state
	kubeproxy - Kubernetes proxy that handles network traffic to and from the cluster
	kubectl - Command-line tool for interacting with Kubernetes clusters

    Hirerachy is as follows:
    Control Plane
    |--- Kublet
    |--- Kubeadm
    |--- etcd
    |--- kubeproxy
    |--- kubectl
    Worker Nodes
    |--- Kublet
    |--- Pods
    |--- Containers


----------------------------------------------------
- Key Components:
----------------------------------------------------
	Helm - Package manager for Kubernetes use to deploy charts
	Charts - Collection of templates and values used to deploy applications
	Releases : Instance of a chart running in cluster
	CRI - Contaier Runtime Interface for running containers in Kubernetes
	CNI - Container Network Interface for networking containers
	CSI - Container Storage Interface for storage of container data
	CRD - Custom Resource Definition for extending Kubernetes
	API - Application Programming Interface for interacting with custom resources
	Ingress - API for routing external traffic to internal services



---------------------------------------------------------------------------------------------------
1. Steps for Deploying Kubernetes Cluster
------------------------------------------------------------------------------------------------
a. Disable the swap (in both control plane and worker nodes)
    # sudo swapoff -a
b. Configure the containerd
    # sudo apt-get update && sudo apt-get install -y containerd
    # sudo mkdir -p /etc/containerd
    # sudo containerd config default | sudo tee /etc/containerd/config.toml
    # sudo systemctl restart containerd
     or

     load the modules in /etc/modules-load.d/containerd.conf
     echo "overlay" | sudo tee /etc/modules-load.d/containerd.conf
     echo "br_netfilter" | sudo tee -a /etc/modules-load.d/containerd.conf
     sudo modprobe overlay
     sudo modprobe br_netfilter

     Also
     configure the cotainerd to set SystemdCgroup = true
     ----------------------------------------------------
     sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
     sudo systemctl restart containerd

---------------------------------------------------------------------------------------------------
2. Configure the CNI (Container Network Interface)
---------------------------------------------------------------------------------------------------
    # sudo apt-get update && sudo apt-get install -y

    Also

    echo "net.bridge.bridge-nf-call-iptables  = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
    echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
    echo "net.ipv4.ip_forward                 = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
    sudo sysctl --system

------------------------------------------------------------------------------------------------
3. Add Kubernetes repository and install kubeadm, kubelet, and kubectl
------------------------------------------------------------------------------------------------
    # echo deb http://apt.kubernetes.io/ kubernetes-xenial main | sudo tee /etc/apt/sources.list.d/kubernetes.list
    # sudo apt-get update && sudo apt-get install -y kubeadm kubelet kubectl
    # sudo systemctl enable kubelet
    # sudo systemctl start kubelet

    Add DNS entries to /etc/hosts
    echo "127.0.0.1  localhost" | sudo tee -a /etc/hosts
    echo "control-plan1    192.168.120.1" | sudo tee -a /etc/hosts
    echo "worker-node1     192.168.120.11" | sudo tee -a /etc/hosts
    echo "control-plane2   192.168.120.2" | sudo tee -a /etc/hosts

---------------------------------------------------------------------------------------------------
4.   Initialize the control plane
---------------------------------------------------------------------------------------------------
    sudo kubeadm init --pod-network-cidr= 10.0.0.0/16 --control-plane-endpoint=<load-balancer-ip>

    Get the join command for worker nodes
    kubeadm token create --print-join-command

    To join a worker node to the cluster, run the following command on the worker node:
    kubeadm join <control-plane-endpoint>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>


    Get the join command for control plane nodes
    kubeadm token create --print-join-command --description "control-plane"

    To join a control plane node to the cluster, run the following command on the control plane node:
    kubeadm join <control-plane-endpoint>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --control-plane

---------------------------------------------------------------------------------------------------
5. Configure the environment
---------------------------------------------------------------------------------------------------
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

   Check the cluster status
   ----------------------------
   kubectl cluster-info
   kubectl get nodes



---------------------------------------------------------------------------------------------------
6. Install a pod network add-on CNI plugin (Calico/Flannel)
---------------------------------------------------------------------------------------------------
    Calico is the default CNI plugin for Kubernetes.
    --------------------------------------------------
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

    Flannel is an alternative CNI plugin for Kubernetes.
    ---------------------------------------------------
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


    Deploy and test workloads for CNI plugin
    ----------------------------------------
    kubectl run nginx   --image=nginx --port=80 --expose=true --type=NodePort
    kubectl get svc nginx


    Alternative : MetalLB (LoadBalancer implementation for bare metal)
    ---------------------------------------------------------------
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.8/config/manifests/metallb-native.yaml
    kubectl get pods -n metallb-system


    Implement MetalLB with a config file and reserved IP range
    ----------------------------------------------------------
    cat <<EOF | kubectl apply -f -
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: pool
      namespace: metallb-system
    spec:
      addresses:
      - 192.168.0.100-192.168.0.200
    EOF

    kubectl get ipaddresspool -n metallb-system

---------------------------------------------------------------------------------------------------
7. Check for the status of control plane components
---------------------------------------------------------------------------------------------------
    kubectl get pods -n kube-system
    kubectl get nodes


8. Creating Service User Roles
---------------------------------------------------------
kubectl create serviceaccount dev-user -n rbac-test
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n rbac-test
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=dev-user -n rbac-test

kubectl create token dev-user -n rbac-test
kubectl get serviceaccount dev-user -n rbac-test


Create a kubeconfig for the dev-user
---------------------------------------------------------
kubectl config set-credentials dev-user --token=$(kubectl create token dev-user -n rbac-test)
kubectl config set-context dev-user-context --cluster=<cluster-name> --user=dev-user
kubectl config use-context dev-user-context


Check for the permission
---------------------------------------------------------
kubectl auth can-i get pods -n rbac-test --as dev-user


OR
---------------------------------------------------------
- Create a role and rolebinding.
---------------------------------------------------------
# cat <<EOF >  role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata :
    namespace : rbac-test
    name: pod-reader
rules :
- apiGroups:  [""] # The empty stringrefers to the core Kubernetes API group
   resources : [" pods "]
   verbs: ["get" ,"list", "watch"]
EOF


---------------------------------------------------------
- Create a rolebinding (rolebinding.yaml)
---------------------------------------------------------
# cat <<EOF > rolebinding.yaml
#rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata :
    name: read-pods
    namespace: rbac-test
subjects :
-  kind: ServiceAccount
    name: dev-user
    namespace: rbac-test
roleRef:
    kind: Role
    name: pod-reader
    apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f role.yaml

kubectl apply -f rolebinding.yaml

kubectl auth can-i list pods --as-system: serviceaccount: rbac-test :dev-user -n rbac-test

kubectl auth can-i delete pods --as=system:serviceaccount:rbac-test:dev-user -n rbac-test

-----------------------------------------------------------------------------------
- Installing  Helm (Helm is a package manager for Kubernetes that allows you to define, install, and upgrade applications.)
-----------------------------------------------------------------------------------

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sh get_helm.sh

helm version

# Add the Bitnami Helm repository or any other Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
OR
helm repo add continue https://charts.continue.dev/

helm repo update

helm install my-nginx  bitnami/nginx --set service.type=NodePort

# Manage the life-cycle with helm
Helm - Templating
    (Go  templates with variables)
Kustomization
    - Patching overlays changes on yaml

--------------------------------------------------------------
- Architecture of using Helm and Kustomization is as follows:
--------------------------------------------------------------
 base/
|-- deployment.yaml
|-- service.yaml
|-- kustomization.yaml

overlay/
|-- dev/
|   |-- kustomization.yaml
|-- prod/
|   |-- kustomization.yaml


- base is the base configuration for the application, including deployment and service definitions.
- overlay is the overlay configuration for the application, including kustomization.yaml files for dev and prod environments.

mkdir -p my-app/base
mkdir -p my-app/overlays/production/

 cat <<EOF >  my-app/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: my-app
spec :
    replicas: 1
    selector :
    matchLabels :
        app: my-app
    template:
    metadata:
    labels:
        app: my-app
spec :
containers :
- name: nginx
image: nginx:1.25.O
EOF

cat <<EOF > my-app/base/kustomization.yaml
resources :
- deployment.yaml
EOF

cat <<EOF > my-app/base/overlays/production/patch.yaml
apiVersion: apps/v1
kind:Deployment
metadata:
	name: my-app
spec:
    replicas: 3
EOF

cat <<EOF > my-app/base/overlays/production/kustomization.yaml
resources:
- ../../base
patches:
- path: patches.yaml
EOF

kubectl apply -k my-app/base/overlays/production

--------------------------------------------------
- Rolling Deployment Update / Rollback
--------------------------------------------------

 cat <<EOF > deployment.yaml
#deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: nginx-deployment
spec :
	replicas: 3
	selector :
	matchLabels:
		app: nginx
	template :
        metadata:
	    labels:
		app: nginx
spec:
containers :
- name: nginx
  image: nginx:1.24.0
ports:
EOF

kubectl apply -f deployment.yaml

kubectl set image deployment/nginx-deployment nginx=nginx:1.25.0

kubectl rollout status deployment/nginx-deployment

-------------------------------------------------
- For Rollback  check the revision history
-------------------------------------------------

kubectl rollout history deployment/nginx-deployment

kubectl  rollout undo deployment/nginx-deployment
OR
kubectl  rollout undo deployment/nginx-deployment --to-revision=1

-------------------------------------------------
- Decouple application code from configuration
-------------------------------------------------
    ConfigMaps :  For non-sensetive data in key-value pairs .
    Secrets: For sensetive data like passwords , API keys or TLS certitficate
    Encryption at REST: Enabling encryption at REST in etcd and using rbac to restrict access to the secret objects.
-------------------------------------------------
- Create ConfigMaps
-------------------------------------------------
echo " retires = 3" > config.properties
kubectl create configmap app-config-file --from-file=config.properties

OR {declarative}
cat <<  EOF > configmap.yaml
apiVersion: v1
kind: configmap
metadata:
	name: app-config-declarative
data:
	databaseurl: "jdbc:mysql://db.example.com:3306/mydb"
	ui.theme: " dark"
EOF

kubectl apply -f configmap.yaml

-------------------------------------------------
- Create Secret
-------------------------------------------------
kubectl create secret generic db-credentials --from-literal=username=admin --from-literal=password='s3cr3t'

OR {declarative}

cat << EOF > secret.yaml
#secret.yaml
apiVersion: v1
kind: secret
metadata:
	name: api-key
type: Opaque
stringData:  # Use stringData for plain text!
	key: "my-super-secret-api-key:
EOF

-------------------------------------------------
- Sample Example
-------------------------------------------------
cat << EOF > pod-config.yaml
apiVersion: v1
 kind: Pod
 metadata:
	name: config-demo-pod
spec:
	containers:
	- name : demo-Container
	   image: busybox
	   command: [" /bin/sh", "-c"  ,"env && sleep 3600"]
	   env:
	   # Inject a value from our ConfigMap
		- name: THEME
		   valueFrom:
			configMapKeyRef:
				name: app-config-declarative
				key: ui.theme
	  # Inject a value from our secret
	    - name:  DB_PASSWORD
	       valueFrom:
			secretKeyRef:
				name: db-credentials
				key: password
      restartPolicy: Never
EOF

-------------------------------------------------
- Accessing Configmap and secrets from  a volume
-------------------------------------------------
cat << EOF > pod-volume.yaml
apiVersion: v1
kind: Pod
metadata:
	name: config-demo-pod
spec:
	containers:
	- name : demo-Container
	  image: busybox
	   command: [" /bin/sh", "-c"  ,"env && sleep 3600"]
	  volumeMounts:
	  - name: config-volume
	     mountPath: /etc/config
	volumes:
	- name: config-volume
	   configMap:
		name: app-config-file
	restartPolicy: Never
EOF

 kubectl logs config-demo-pod
-----------------------------------------------------------------------------------------------------------------
- HorizontalPodAutoscaler ( HPA)
- Implemeting Worload Autoscaling
HorizontalPodAutoscaler (HPA) is used to automatically scale the number of pods in a deployment based on CPU or memory usage.
Note: Metrics collector a metric server need to be deployed to collect metrics for HPA to work.
-----------------------------------------------------------------------------------------------------------------
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml

kubectl top nodes
# If not output is dispalyed edit the config and add lines

kubectl edit depolyment metrics-server -n kube-system

# Go to args module and add below lines and wait for the metrics server to start
 --kubelet-insecure-tls

kubectl get pods -n kube-system
kubectl top nodes
kubectl top pods


----------------------------------------------------
Create a ConfigMap
----------------------------------------------------
kubectl create configmap php-index --from-literal=index.php='<?php $x = 0.0001; for ($i = 0; $i <= 1000000; $i++) {$x += sqrt($x); } echo "OK"; ?>'


echo << EOF > hpa-demo-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
	name: php-apache
spec:
	selector:
		matchLabels:
		run: php-apache
	replicas: 1
	template:
	metadata:
	labels:
		run: php-apache
	spec:
		containers:
		- name: php-apache
		# This image is designed to consume CPU
		image: registry.k8s.io/hpa-example
		ports:
			- containerPort: 80
		resources:
		requests:
			cpu: 200m # 'm' stands for millicores and 200m is 20% of once CPU core
		volumeMounts"
		- name: php-code
		  mountPath: /var/www/html
	 volumes:
	 - name: php-code
	 configMap:
		name: php-index
EOF

kubectl apply -f hpa-demo-deployment.yaml
kubectl expose deployment php-apache --port=80
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

----------------------------------------------------
- Run the load generator
----------------------------------------------------
kubectl run -it --rm load-generator --image=busybox  -- / bin/sh -c "whille true ; do wget -q -O- http://php-apache; done"

kubectl get hpa -w


--------------------------------------------------------------------------------------------------------
- Health Probes
- Liveness Probe: Is the container running ? If fails kubelet kills and restart the container, recovers from deadlocks.
- Readiness Probe: Is the container ready to serve the traffic ? If it fails the pod is removed from service endpoints.
	Prevents traffic to start /overlaod app.
- Startup Probe: Has the container started sucessfully ? Disable readiness checks until it succeeds.
	Protects slow-starting apps.
--------------------------------------------------------------------------------------------------------

cat << EOF > pod-probes.yaml
# pod-probes.yaml
apiVersion: v1
kind: Pod
metadata:
	name: probe-demo
spec:
	containers:
	- name: nginx
	  image: nginx
	  ports:
	  - containerPort: 80
	  readinessProbe:
	    httpGet:
		 path:  /
		 port: 80
	    intialDelaySeconds: 5
	    periodSeconds: 10
	   livenessProbe:
		tcpSocket:
			port: 80
	   initalDelaySeconds: 15
	   periodSeconds: 20
EOF

kubectl apply -f pod-probes.yaml

kubectl describe pod probe-demo

----------------------------------------------------
- Check liveness with bad syntax
----------------------------------------------------
kubectl delete pod probe-demo


# Change the settings in pod-probes.yaml file with /bad in url curl path
# Apply the updated pod-probes.yaml file
# Check for the failed in Probe liveness

kubectl apply -f pod-probes.yaml

- Check for the failed in Probe liveness
kubectl get pod probe-demo -w


---------------------------------------------
- Resource Request and Limits
---------------------------------------------
- Advance Scheduling
- Node Affinity i.requiredDuringScheduling
-               ii.prefreredDuringScheduling

- Labels a node to work pods on the specific node meaning it will only run pods with matching labels
----------------------------------------------------------------------------------------------------
kubectl label node k8-worker disktype=ssd

cat << EOF > appfinity-pod.yaml
# affinity-pod.yaml
apiVersion: v1
kind: pod
metadata:
    name: ssd-Pod
spec:
  containers:
  - name: ngnix
    image: ngnix
  affinity:
    nodeAffinity:
        requiredDuringSchedulingIgnoreDuringExection:
            nodeSelectorTerms:
            -   matchExpressions:
                -   key: disktype
                    operator: In
                    values:
                    - ssd
EOF


kubectl apply -f affinity-pod.yaml

kubectl get pods -o wide


---------------------------------------------
- Taint and Tolerance

Taint:applied on node, repels pods
Tolerance: applied on pod , scheduled on
            node with matching Taint

- Effects: NoSchedule - No new pods schedule.
          PreferNoSchedule- Scheduler will try to avoid node.
          NoExecute - Evicts running pod that dont have toleration.
---------------------------------------------

kubectl taint node k8-worker app=gpu:NoSchedule
(No new pods will run will be in pending started)

---------------------------------------------
- Toleration Pod
---------------------------------------------

cat << EOF > toleration-pod.yaml
# toleration-pod.yaml
apiVersion : v1
kind: Pod
metadata:
    name: gpu-Pod
spec:
    containers:
    -   name: ngnix
        images: ngnix
    tolerations:
    -   key: "app"
        operator: "Equal"
        value: "gpu"
        effect: "NoSchedule"
EOF

kubectl apply -f toleration-pod.yaml

kubectl get pods -o wide



---------------------------------------------
- Networking
---------------------------------------------
Fundamental Model: Each pod gets its unique IP address.
Each pod can communicate with other pod without NAT.
Flat networking model is implemented by CNI (fannel/Callico).
Pods are ephemeral, IPs are unreliable.
---------------------------------------------
- Service
---------------------------------------------
Service provides stable abstraction over set of Pods.
Stable VIP(Cluster IP) and DNS name.
---------------------------------------------
- Selector
---------------------------------------------
Selector to identify backend Pods.
---------------------------------------------
- Service Types
---------------------------------------------
ClusterIP:
     - default service type.
     - exposes the service on a cluster-internal IP.
     - Makes service reachable only within cluseter.
     - Standard for communication between microservices.
---------------------------------------------

kubectl create deployment my-app --image=nginx --replicas=2

---------------------------------------------
- Create the Cluster Service
---------------------------------------------

cat << EOF > clusterip-service.yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
    name: my-app-service
spec:
    type: ClusterIP
    selector:
        app: my-app  #This is the critical link!
    ports:
    -   protocal: TCP
        port: 80
        targerPort: 80
EOF

kubectl apply -f clusterip-service.yaml

kubectl run tmp-shell -rm -it --image=busybox -- /bin/sh

Check with below
# wget -O-  my-app-service

---------------------------------------------
- Service Types: NodePort ( Dev/Non-loadbalacer)
---------------------------------------------

    - Expose service on static port on each nodeIP
    - Creates a clusterIP service that it routes traffic to.
    - Useful for external load balanacer isnot avaialabe.
    - Port range 30000-32767


---------------------------------------------
- NodePort Service
---------------------------------------------

    - Expose service on static port on each nodeIP
    - Creates a clusterIP service that it routes traffic to.
    - Useful for external load balanacer isnot avaialabe.
    - Port range 30000-32767



kubectl apply -f nodeport-service.yaml

---------------------------------------------
- Check for the service port mapping
---------------------------------------------
kubectl get service my-app-nodeport
kubectl get nodes -o wide
curl http://<nodeip>:<nodeport>

-----------------------------------------------------
- Service Types: LoadBalancer
-----------------------------------------------------
    - Exposes sevice externally using a cloud provider load balanacer.
    - Standard way to expose a service to the internet /cloud environment.
    - Automatically creater NodePort and ClusterIP services.
    - Cloud provider provisions a load balancer and assign external IP .

-----------------------------------------------------
- Ingress and GatewayAPI
-----------------------------------------------------
    -  Manage external access more effeciently than LoadBalancer services.
    -  Provide layer7 (HTTP/HTTPS) routing.


-----------------------------------------------------
- INGRESS CONTROLLER
-----------------------------------------------------
- Manage external access,providing load balancing ,SSL termination
    and name-based virtual routing.
- Requires an Ingress Controller (NGNIX/HAProxy)to be running in
    the cluster.
- Controller watches ingress resources and configures the proxy.


-----------------------------------------------------
- Install Ingress Controller
-----------------------------------------------------
- Run the following command to install the NGINX Ingress Controller:

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-ngnix/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

-----------------------------------------------------
# Example
-----------------------------------------------------

    kubectl create Deployment app-one --image=registry.k8s.io/echoserver:1.4
    kubectl expose deployment app-one --port=8080

    kubectl create Deployment app-two --image=registry.k8s.io/echoserver:1.4
    kubectl expose deployment app-two --port=8080



-----------------------------------------------------
- Create Ingress Yaml file
-----------------------------------------------------

    cat << EOF > ingress.yaml
    # ingress.yaml
    apiversion: networking.k8s.io/v1
    kind: Ingress
    metadata:
        name: example-ingress
        annotations:
            ngnix.ingress.Kubernetes.io/rewrite-target /
    spec:
        ingressClassName: nginx
        rules:
        -   http:
            paths:
            -   path: /app1
                pathType: Prefix
                backend:
                    service:
                        name: app-once
                        port:
                            number: 8080
            -   path: /app2
                pathType: Prefix
                backend:
                    service:
                        name: app-two
                        port:
                            number: 8080
EOF

kubectl apply -f ingress.yaml

kubectl get services -n ingress-nginx

curl http:192.168.1.161:32733/app1

curl http:192.168.1.161:32733/app2


-----------------------------------------------------
- GATEWAY API

Next Generation Ingress (expressive/flexible/role-oriented)
Decouples config in 3 resource types:
           - GatewayClass:(Admin)
             Template fo a type of load balancer
           - Gateway: (Operator)
             Define where the load balancer listens.
           - HTTPRoute:(Developer)
             Protocal-Specific routing rules
-----------------------------------------------------


-----------------------------------------------------
- Network Policies
-----------------------------------------------------

-Acts as a firewall for pods, control traffic flow at IP and
 port level.
- Default , all pods communicate with other pods.
- Requires CNI plugin that supports ( Calico)
- Start with "default deny" policy and explicitly
  allow required traffic.



- Create a deny policy
----------------------
cat << EOF > deny-all.yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: default-deny-ingress
spec:
    podSelector: {} # The empty selector means "select all pods"
    policyTypes:
    - Ingress
EOF


kubectl apply -f deny-all.yaml

kubectl create deployment web-server --image=nginx

kubectl expose deployment web-server --port=80

# Check for the error not able to connect
kubectl run tmp-shell --rm -it --image=busybox --/bin/sh -c "wget -O- --timeout=2 webserver" | grep -q "Failed" && echo "Error: Unable to connect" || echo "Success: Connected"


----------------------------------------------------------
- Create Allow firewall Policy
----------------------------------------------------------

cat << EOF > allow-web-access.yaml
# allow-web-access.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: allow-web-access
spec:
    podSelector:
        matchLabels:
            app: web-server
    policyTypes:
    -   Ingress
    ingress:
    - from:
        - podSelector:
            matchLabels:
                access: "true"
        ports:
        -   protocal: TCP
            port: 80
EOF

kubectl run tmp-shell --rm -it --labels=access=true --image=busybox -- /bin/sh -c "wget -O- web-server"

----------------------------------------------------------
# Check for the error not able to connect
----------------------------------------------------------

kubectl run tmp-shell --rm -it --image=busybox -- /bin/sh -c "wget -O- --timeout=2 webserver" | grep -q "Failed" && echo "Error: Unable to connect" || echo "Success: Connected"

----------------------------------------------------------
# CoreDNS
----------------------------------------------------------
# - Default DNS server for Kubernetes
# - Creating a service, CoreDNS automatically creates DNS record.
# - <servicename>.<namespace>.svc.cluster.local
# - Configured via ConfigMap in kube-system namespace.
----------------------------------------------------------

kubectl edit configmap coredns -n kube-system

    # Check for the Corefile: module
    # Add entry
    my-corp.com:53 {
        errors
        cache 30
        forward . 10.10.0.53
    }

$ kubectl run tmp-shell --rm -it --image=busybox -- /bin/sh
$ nslookup db.my-corp.com

----------------------------------------------------------
- STORAGE
----------------------------------------------------------
Volume:
       - Tied to lifecycle of Pod . Data is lost when Pod is deleted
PersistentVolume:
       - Storage in cluster whose lifecycle is independent of any pod.
       - Provisioned by an administrator.
PersistentVolumeClaims:
       - Request for storage by a user ,acts as a claim on PV Resource.
----------------------------------------------------------

- Binding Process
----------------------------------------------------------
- User creates a PVC requesting a certain size and access mode.
- Kubernetes control plane looks for an available PV that satisfies the claim.
- If suitable PV is found, PVC is bound to the PV in one-to-one mapping.
- Pod can mount the storage by referencing the PVC by name.
       Access Modes:
           ReadWriteOnce(RWO):Read-write by a single node.
           ReadOnlyMany(ROX): Read-only by many nodes.
           ReadWriteMany(RWX): Read-write by many node.(NFS)
           ReadWriteOncePod(RWOP): Read-write by single Pod. Most Secure
----------------------------------------------------------

- Reclaims Policies
----------------------------------------------------------
- Retain: (Safest) The PV remains. Data and underlying storage asset are not deleted.
- Delete : PV and associated external storage asset are automatically deleted.
- Recycle: Depreacated. Perfors a basic scrub (rm -rf) and makes PV available again.
----------------------------------------------------------

# Local demo pv

cat << EOF > pv.yaml
#pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
    name: task-pv-volume
spec:
    capacity:
        storage: 5Gi
    accessModes:
        -   ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: manual
    hostPath:
        path: "/mnt/data"
EOF

kubectl apply -f pv.yaml

kubectl get pv


cat << EOF > pvc.yaml
#pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaims
metadata:
    name: task-pv-claim
spec:
    storageClassName: manual
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
            storage: 2Gi
EOF


kubectl apply -f pvc.yaml

kubectl get pv,pvs


cat << EOF > pod-storage.yaml
# pod-storage.yaml
apiVersion: v1
kind: Pod
metadata:
    name: storage-pod
spec:
    containers:
     -  name: nginx
        image: nginx
        volumeMounts:
        - mountPath: '/usr/share/ngnix/html'
          name: my-storage
    volumes:
     -  name: my-storage
        PersistentVolumeClaims:
            claimName: task-pv-claim
EOF

kubectl apply -f pod-storage.yaml

--------------------------------------------------------------------
- StorageClasses and Dynamic Provisioning
--------------------------------------------------------------------
 -> Manual create PVs doesnot scale, dynamic provisioning does.
 -> administrator define one/more StorageClasses
 -> StorageClasses descirbes a class of storage
 -> eg ebs.csi.aws.com and paramter.
 -> User creates a PVC referencing a storageClassName, the provisioner
 -> automatically creats a matching PV.
--------------------------------------------------------------------
kubectl get storageclass

- To use local-path storage, apply the following manifest:
(it is a simple local storage solution that does not require any external storage provider.)
--------------------------------------------------------------------
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisoner/v0.0.26/deploy/local-path-storage.yaml

kubectl get storageclass

cat << EOF > my-pvc.yaml
# my-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaims
metadata:
    name: my-storage-claim
spec:
# This tell the PVC to use StorageClass we created .
    storageClassName: local-path
    accessModes:
        - ReadWriteOnce # This volume can be mounted by a single node
        resources:
            requests:
                storage: 1Gi # Requesting 1Gi-byte of storage
EOF


--------------------------------------------------------------------
- Troubleshoot Methodology
--------------------------------------------------------------------
- i. Identify the Problem:
       - Define what is not working
         eg: kubectl get pods
- ii. Gather Information:
       - kubectl describe ...
- iii. Analayze the Data:
       - Form a hypothesis about the root cause.
- iv. Implment a Solution:
       - Apply a fix .
- v. Verify the Solution:
       - Confirm the issue is resolved.

--------------------------------------------------------------------
- Troubleshoot Application and Pods
--------------------------------------------------------------------
- i. Pending:
       - Waiting to be schedule/downloading images.
- ii. ContainerCreating:
       - Container runtime is starting a container.
- iii. ImagePullBackoff/ ErrImagePull:
       - Unable to pull the container image.
- iv.  CrashLoopBackoff:
       - Container started but exited with an error.
- v.   OMMKilled:
       - Container was terminated becuase exceeded memory limit.


--------------------------------------------------------------------
- Debug Pending Pods
--------------------------------------------------------------------
- Causes:
       -Insufficient resources(CPU/Memory)
       -Failing due to affinity rules.
       -Node taints without matching tolerations.
       -Unbound PVC.
- Debug:
       - kubectl describe pod <pod-name>
       - Look at events section for FailedScheduling.

--------------------------------------------------------------------
- Debug CrashLoopBackoff
--------------------------------------------------------------------
- Causes:
       - Error in application code.
       - Misconfiguration (wrong password,bad file path).
       - Failing liveness probe.
- Debug Steps:
       - Check the logs $ kubectl logs <pod-name>
                    $ kubectl logs <pod-name> --previous
       - Check events and exit code
                    $ kubectl describe pod <pod-name>
       - Exec into container for live debug if needed.
                    $ kubectl exec
--------------------------------------------------------------------
- Not Ready Node
--------------------------------------------------------------------
- Causes:
       - Kubelet on node is not reporting a healthy status.
       - kubelet process is not running.
       - Network partition preventing comm with API Server.
       - underlying host machine is down.
- Debug Steps:
       - SSH into affected noded.
       - Check kublet service $ sudo systemctl status kublet
       - Examine kublet logs: $ journalctl -u kubectl -f

--------------------------------------------------------------------
- Troubleshoot Cluster Components
--------------------------------------------------------------------
- Kubeadm cluster , control plane component run as static pods.
- Manifests are in /etc/kubernetes/manifests/ on control-plane nodes.
- kubectl fails with "connection refused", likely API server is down.
- Debug Steps:
       - SSH into control-plane node.
       - Check static Pod container using crictl ps.
       - Check logs $ crictl logs <container-id>.
       - Inspect its manifest for errors.

--------------------------------------------------------------------
- Troubleshoot Services and Network
--------------------------------------------------------------------
- Check DNS Resolution:
        kubectl exec -it client-pod -- nslookup my-service
- Check Service and Endpoint:
        kubectl describe service my-service
- Check Pod Connectivity:
       Try curl the backend Pod's IP directly
- Check Network Policies:
        kubectl get networkpolicy
       (Temporarily delete policies to isloated the issue)

--------------------------------------------------------------------
- Monitor Cluster/Application Resource Usage
--------------------------------------------------------------------
- Top command is primary tool to check resource consumption.
       kubectl top
- Relies on the metrics server.
- Check Node Resource Usage:
        kubectl top nodes  (Identifies nodes under pressure).
- Check Pod Resource Usage:
        kubectl top pods -n <namespace> (Diagnose OMMKilled /tune HPA targets).
