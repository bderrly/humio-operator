#!/usr/bin/env bash

set -x

# Ensure we use the correct working directory and KUBECONFIG:
cd ~/go/src/github.com/humio/humio-operator
export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"

# Clean up old stuff
kubectl delete humiocluster humiocluster-sample
helm template ~/git/humio-cp-helm-charts --name humio --namespace=default --set cp-zookeeper.servers=1 --set cp-kafka.brokers=1 --set cp-schema-registry.enabled=false --set cp-kafka-rest.enabled=false --set cp-kafka-connect.enabled=false --set cp-ksql-server.enabled=false --set cp-control-center.enabled=false | kubectl delete -f -
kubectl get pvc | grep -v ^NAME | cut -f1 -d' ' | xargs -I{} kubectl delete pvc {}
kind delete cluster

# Wait a bit before we start everything up again
sleep 5

# Create new kind cluster, deploy Kafka and run operator
kind create cluster

# Pre-load confluent images
docker pull confluentinc/cp-enterprise-kafka:5.3.1
docker pull confluentinc/cp-zookeeper:5.3.1
docker pull docker.io/confluentinc/cp-enterprise-kafka:5.3.1
docker pull docker.io/confluentinc/cp-zookeeper:5.3.1
docker pull solsson/kafka-prometheus-jmx-exporter@sha256:6f82e2b0464f50da8104acd7363fb9b995001ddff77d248379f8788e78946143
kind load docker-image confluentinc/cp-enterprise-kafka:5.3.1
kind load docker-image confluentinc/cp-enterprise-kafka:5.3.1
kind load docker-image docker.io/confluentinc/cp-zookeeper:5.3.1
kind load docker-image docker.io/confluentinc/cp-zookeeper:5.3.1
kind load docker-image solsson/kafka-prometheus-jmx-exporter@sha256:6f82e2b0464f50da8104acd7363fb9b995001ddff77d248379f8788e78946143

# Pre-load telepresence images
docker pull datawire/telepresence-k8s:0.103
docker pull docker.io/datawire/telepresence-k8s:0.103
kind load docker-image datawire/telepresence-k8s:0.102
kind load docker-image docker.io/datawire/telepresence-k8s:0.102

# Pre-load humio images
docker pull humio/humio-core:1.6.5
kind load docker-image humio/humio-core:1.6.5

mkdir ~/git
git clone https://github.com/humio/cp-helm-charts.git ~/git/humio-cp-helm-charts
helm template ~/git/humio-cp-helm-charts --name humio --namespace=default --set cp-zookeeper.servers=1 --set cp-kafka.brokers=1 --set cp-schema-registry.enabled=false --set cp-kafka-rest.enabled=false --set cp-kafka-connect.enabled=false --set cp-ksql-server.enabled=false --set cp-control-center.enabled=false | kubectl apply -f -

# Install CRD
make install

# Create a CR instance of HumioCluster
sleep 30
kubectl apply -f config/samples/core_v1alpha1_humiocluster.yaml