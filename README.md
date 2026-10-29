# GitHub Pages Static Website

## Task Overview
This project was created as part of *Task 6* of a DevOps internship to learn how to deploy a static website using *GitHub Pages*.

## What I Did
- Created a simple index.html file with basic HTML content.
- Pushed the code to a new public GitHub repository.
- Enabled GitHub Pages from the repository settings.
- Selected the main branch and root folder as the source.
- Accessed the live website from the URL provided by GitHub Pages.

## Optional Customization
I also added a style.css file to style the page and make it look more presentable.

## Live Website
[Click here to view the live website](https://aashishsharma5555.github.io/my-site/) 


MySite — Docker & Kubernetes Deployment Guide

A complete guide to deploying a static website using Docker and a two-node Kubernetes cluster, including networking, monitoring, NodePort load balancing, autoscaling, self-healing, and load testing.

1. Project Overview
Architecture
VM1 — Master + Worker: aashish-vmware20-1
VM2 — Worker: linuxuser-vmware20-1
Website: Nginx static website
Container runtime: containerd
CNI network: Flannel
Service exposure: NodePort
Monitoring: Metrics Server
Autoscaling: Horizontal Pod Autoscaler (HPA)
Namespace: mysite
Website port: 80
NodePort: 30080
Autoscaling target: 70% CPU utilization
Important: The node names above identify the VMs in Kubernetes. They do not prove that the machines are physically located in Mumbai or Hyderabad. Kubernetes region labels are logical labels that you configure.
2. Verify the Kubernetes Cluster

Run these commands on VM1, where kubectl is configured.

bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl get namespaces


Expected node names:

text
aashish-vmware20-1     Ready   control-plane
linuxuser-vmware20-1   Ready   <none>


Both nodes should be Ready.

3. Allow VM1 to Run Application Pods

By default, a control-plane node normally has a taint that prevents ordinary workloads from being scheduled on it.

To allow VM1 to run website pods as well as control-plane components:

bash
kubectl taint nodes aashish-vmware20-1 node-role.kubernetes.io/control-plane:NoSchedule-


Verify the node taints:

bash
kubectl describe node aashish-vmware20-1 | grep -i taint
kubectl describe node linuxuser-vmware20-1 | grep -i taint


The command removes the control-plane NoSchedule taint if it exists. This allows ordinary workloads to schedule on VM1; it does not remove the control-plane role.

4. Verify Docker and the Project Files
bash
cd ~/my-site

docker --version
docker info
ls -la

find . -maxdepth 3 -type f \
  \( -name 'Dockerfile' -o -name '*.yaml' -o -name '*.yml' \)


The project contains:

text
my-site/
├── Dockerfile
├── index.html
├── style.css
└── k8s/
    ├── deployment.yaml
    ├── service.yaml
    ├── mysite-nodeport.yaml
    ├── namespace.yaml
    ├── hpa.yaml
    ├── ingress.yaml
    ├── egress.yaml
    └── kind-config.yaml


The kind-config.yaml file is only relevant if you are using Kind. It is not needed for an existing kubeadm cluster.

5. Build the Docker Image

Run on VM1:

bash
cd ~/my-site

docker build -t aashishsharma5555/mysite:latest .

docker images | grep mysite


Test the image locally:

bash
docker run -d --name mysite-test -p 8080:80 \
  aashishsharma5555/mysite:latest

curl -I http://localhost:8080
docker rm -f mysite-test


An HTTP response such as 200 OK indicates that Nginx is serving the website.

Push the image to Docker Hub

If the repository is public or your Docker Hub account has access:

bash
docker login
docker push aashishsharma5555/mysite:latest


If the worker cannot pull the image, verify that the image exists in Docker Hub and that the deployment references the correct repository and tag.

For reproducible deployments, use versioned tags instead of relying exclusively on latest.

6. Configure Flannel Networking

Flannel provides pod networking between Kubernetes nodes.

Verify the pods:

bash
kubectl get pods -n kube-flannel -o wide
kubectl logs -n kube-flannel ds/kube-flannel-ds \
  --all-containers=true --tail=100


Both Flannel pods should be Running and 1/1 Ready.

Troubleshooting br_netfilter

On Ubuntu, run on both VMs:

bash
sudo modprobe overlay
sudo modprobe br_netfilter

lsmod | grep -E 'overlay|br_netfilter'

sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.ipv4.ip_forward=1


Persist the settings:

bash
sudo tee /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system


After correcting a missing kernel module, restart Flannel from VM1:

bash
kubectl rollout restart daemonset/kube-flannel-ds \
  -n kube-flannel

kubectl rollout status daemonset/kube-flannel-ds \
  -n kube-flannel

kubectl get pods -n kube-flannel -o wide


If Flannel continues to crash, inspect the logs before making additional changes.

7. Create the Namespace
bash
kubectl apply -f ~/my-site/k8s/namespace.yaml

kubectl get namespace mysite


The namespace should be Active.

8. Deploy the Website

Review the deployment:

bash
cat ~/my-site/k8s/deployment.yaml


The deployment should use the image:

yaml
image: aashishsharma5555/mysite:latest


It should also define CPU and memory requests, resource limits, and HTTP readiness/liveness probes.

Apply the deployment:

bash
kubectl apply -f ~/my-site/k8s/deployment.yaml

kubectl rollout status deployment/mysite -n mysite

kubectl get deployment,pods -n mysite -o wide


The initial deployment uses two replicas. Verify that both pods are Running and Ready.

9. Configure NodePort Load Balancing

For a local two-VM cluster, NodePort is a straightforward way to expose the application.

Apply the existing NodePort service:

bash
kubectl apply -f ~/my-site/k8s/mysite-nodeport.yaml


Verify it:

bash
kubectl get svc -n mysite
kubectl get endpointslice -n mysite
kubectl get pods -n mysite -o wide


Expected service configuration:

text
TYPE       PORT(S)
NodePort   80:30080/TCP


Kubernetes routes connections to ready backend pods selected by the Service. A NodePort Service can be accessed through either node's IP when networking and firewall rules permit it.

Open the website in a browser

Use either of these addresses from a machine that can reach the VMs:

http://192.168.0.11:30080
http://192.168.0.16:30080

These are the VM IP addresses observed during cluster verification. If the addresses change, retrieve them again with:

bash
kubectl get nodes -o wide


Test from the VM:

bash
curl -I http://192.168.0.11:30080
curl -I http://192.168.0.16:30080


If the browser cannot connect, check VM networking, host firewalls, and whether TCP port 30080 is reachable.

Important: Load balancing is not the same as a cloud LoadBalancer

The existing mysite-service uses type: LoadBalancer, but your local cluster has no external IP provisioned for that Service.

For this lab, use mysite-nodeport. A working NodePort Service demonstrates Kubernetes Service routing, but it does not provide a managed cloud load balancer or prove equal traffic distribution between replicas.

10. Configure Metrics Server

Metrics Server supplies resource usage metrics used by kubectl top and the HPA.

Check whether it is installed:

bash
kubectl get deployment metrics-server -n kube-system
kubectl get pods -n kube-system | grep metrics-server


If it is not installed, follow the official Metrics Server installation instructions for your cluster.

Fix kubelet certificate verification

Your cluster initially reported errors similar to:

text
tls: failed to verify certificate
cannot validate certificate for 192.168.0.11 because it doesn't contain any IP SANs


For a local lab, the common workaround is to allow Metrics Server to skip kubelet certificate verification. This weakens TLS verification and is not recommended for production.

If your existing Metrics Server deployment needs this workaround, add the argument:

text
--kubelet-insecure-tls


For example, if the deployment already exists:

bash
kubectl edit deployment metrics-server -n kube-system


Under the Metrics Server container's args list, add --kubelet-insecure-tls without removing the existing arguments. Save and exit.

Wait for the rollout:

bash
kubectl rollout status deployment/metrics-server -n kube-system

kubectl get pods -n kube-system | grep metrics-server

kubectl top nodes
kubectl top pods -n mysite
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes


Do not proceed to HPA load testing until resource metrics are available.

11. Configure HPA for 70% CPU

Edit k8s/hpa.yaml so the CPU utilization target is 70%.

The essential configuration is:

yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mysite-hpa
  namespace: mysite
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mysite
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70


Apply the configuration:

bash
kubectl apply -f ~/my-site/k8s/hpa.yaml

kubectl get hpa -n mysite
kubectl describe hpa mysite-hpa -n mysite

How HPA works
Minimum replicas: 2.
Maximum replicas: 10.
Target average CPU utilization: 70% of the CPU requests.
HPA periodically evaluates resource metrics and adjusts the replica count.

Important: 70% is a target, not a guaranteed instantaneous trigger. Scaling depends on metrics availability, evaluation intervals, stabilization rules, and the workload.

For a container with a CPU request of 100m, 70% utilization corresponds to approximately 70m of CPU usage per container, averaged as HPA evaluates its pods.

12. Install a Load-Testing Tool

Install hey on VM1, or use another machine that can reach the website.

If Go is installed:

bash
go install github.com/rakyll/hey@latest


Ensure the Go binary directory is on your PATH, then verify:

bash
hey -h


Alternatively, install hey using a trusted package or release appropriate for your operating system.

13. Generate Load for 3 Minutes

The following command sends requests for 3 minutes with a target concurrency of 100 workers:

bash
hey -z 3m -c 100 http://192.168.0.11:30080/


Replace the IP address if needed.

Important distinction: -c 100 means 100 concurrent workers, not exactly 100 requests per second. The actual request rate depends on response latency and system capacity.

To target approximately 100 requests per second for 3 minutes, use a rate-limited load generator that explicitly supports a request-rate limit. For example, with a compatible vegeta binary:

bash
echo "GET http://192.168.0.11:30080/" \
  | vegeta attack -rate=100/s -duration=3m \
  | tee results.bin \
  | vegeta report


This targets 100 requests per second for 180 seconds, or approximately 18,000 requests if the generator can sustain the configured rate. Actual successful requests may be fewer if errors or capacity constraints occur.

Run the load test from a machine other than the cluster nodes if possible, so the load generator does not consume the CPU resources being measured.

14. Monitor Autoscaling During the Test

Open separate terminals on VM1.

Terminal 1 — Watch the HPA:

bash
kubectl get hpa -n mysite -w


Terminal 2 — Watch pods and their placement:

bash
kubectl get pods -n mysite -o wide -w


Terminal 3 — Watch deployment replicas:

bash
kubectl get deployment mysite -n mysite -w


Terminal 4 — Monitor resource usage:

bash
watch -n 2 'kubectl top nodes; echo; kubectl top pods -n mysite'


In another terminal, run the load test.

Expected behavior

When average CPU utilization rises above the HPA target for long enough, HPA may increase the number of replicas from 2 toward 10. After the load falls, replicas may decrease, subject to HPA stabilization rules and the configured minimum.

If replicas do not increase, check:

bash
kubectl describe hpa mysite-hpa -n mysite
kubectl top pods -n mysite
kubectl get pods -n mysite
kubectl logs -n kube-system deployment/metrics-server --tail=100


Low CPU usage, missing metrics, or a bottleneck outside the application can prevent scaling from occurring.

15. Test Kubernetes Self-Healing

First, record the running pods:

bash
kubectl get pods -n mysite -o wide


Delete one pod:

bash
kubectl delete pod <POD_NAME> -n mysite


Replace <POD_NAME> with an actual pod name.

Watch the replacement:

bash
kubectl get pods -n mysite -o wide -w


The Deployment should create a replacement pod to maintain its desired replica count.

Verify recovery
bash
kubectl get deployment mysite -n mysite
kubectl rollout status deployment/mysite -n mysite
kubectl get endpointslice -n mysite


This demonstrates pod self-healing. It does not by itself prove recovery from a full VM or control-plane failure.

16. Verify Traffic Routing

Check the Service and its endpoints:

bash
kubectl get svc mysite-nodeport -n mysite
kubectl get endpointslice -n mysite -o wide


Send repeated requests:

bash
for i in $(seq 1 20); do
  curl -s -o /dev/null -w '%{http_code}\n' \
    http://192.168.0.11:30080/
done


HTTP status codes such as 200 indicate successful HTTP responses.

To prove which replica served a request, you would need to expose a response identifier or log each request with pod identity. Repeated successful requests alone do not prove an even distribution of traffic.

17. Assign Logical Region Labels

If you want to identify VM1 as Mumbai and VM2 as Hyderabad for scheduling and reporting, add custom labels.

Run on VM1:

bash
kubectl label node aashish-vmware20-1 region=mumbai --overwrite

kubectl label node linuxuser-vmware20-1 region=hyderabad --overwrite

kubectl get nodes -L region


This adds logical labels only. It does not change the actual geographic location or networking of either VM.

Show pods by node
bash
kubectl get pods -n mysite -o wide

Count website pods on each node
bash
kubectl get pods -n mysite -o wide \
  --field-selector=status.phase=Running


The NODE column shows where each pod is running.

Kubernetes can schedule replicas on both nodes if resources and scheduling rules allow it. Node labels alone do not force a pod onto a particular node; use nodeSelector, affinity, or topology-spread rules if you require specific placement.

18. Complete Verification Checklist

Run the following commands after deployment and configuration.

bash
kubectl get nodes -o wide

kubectl get pods -A

kubectl get deployment,pods,svc -n mysite -o wide

kubectl get endpointslice -n mysite

kubectl get hpa -n mysite

kubectl top nodes

kubectl top pods -n mysite

curl -I http://192.168.0.11:30080/

curl -I http://192.168.0.16:30080/

Success criteria
Both Kubernetes nodes show Ready.
Flannel pods are Running and ready on both nodes.
The website Deployment has its desired replicas available.
The NodePort Service exposes port 30080.
EndpointSlices list ready application pod endpoints.
Metrics Server provides node and pod metrics.
HPA displays a valid CPU metric and a 70% target.
Load testing produces successful HTTP responses.
A deleted pod is replaced by the Deployment.
Under sufficient sustained CPU load, HPA increases replicas when needed.
19. Troubleshooting Quick Reference
Pods are Pending
bash
kubectl describe pod <POD_NAME> -n mysite
kubectl get events -n mysite --sort-by=.lastTimestamp


Check scheduling constraints, available resources, and image-pull errors.

Pods are CrashLoopBackOff
bash
kubectl logs <POD_NAME> -n mysite --previous
kubectl describe pod <POD_NAME> -n mysite


Check the container command, application logs, and probe configuration.

Website does not open
bash
kubectl get svc -n mysite
kubectl get endpointslice -n mysite
kubectl get pods -n mysite -o wide
curl -v http://192.168.0.11:30080/


Check the node IP, TCP port 30080, VM networking, and firewall rules.

HPA shows unknown metrics
bash
kubectl top nodes
kubectl top pods -n mysite
kubectl describe hpa mysite-hpa -n mysite
kubectl logs -n kube-system deployment/metrics-server --tail=100


Verify Metrics Server readiness, kubelet connectivity, certificate configuration, and resource requests.

HPA does not scale
bash
kubectl get hpa -n mysite -w
kubectl top pods -n mysite
kubectl describe hpa mysite-hpa -n mysite


Check that CPU utilization rises above the target, metrics are available, and the Deployment has reached neither an applicable replica limit nor another scheduling constraint.

20. Useful Cleanup Commands

Remove the load-testing container if you created it:

bash
docker rm -f mysite-test


Remove the HPA if you no longer need autoscaling:

bash
kubectl delete -f ~/my-site/k8s/hpa.yaml


Remove the application resources when intentionally cleaning up:

bash
kubectl delete -f ~/my-site/k8s/mysite-nodeport.yaml
kubectl delete -f ~/my-site/k8s/deployment.yaml


Do not delete the namespace or cluster networking components unless you intend to remove those resources too.

21. Official Documentation
Kubernetes documentation: https://kubernetes.io/docs/
Deployments: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
Services: https://kubernetes.io/docs/concepts/services-networking/service/
Horizontal Pod Autoscaling: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
Metrics Server: https://github.com/kubernetes-sigs/metrics-server
Flannel: https://github.com/flannel-io/flannel
Docker documentation: https://docs.docker.com/

Project summary: MySite runs as an Nginx container in a two-node Kubernetes cluster. Flannel supplies pod networking, NodePort exposes the website, Metrics Server provides resource usage metrics, HPA targets 70% CPU utilization, and a Deployment maintains the desired number of replicas.
