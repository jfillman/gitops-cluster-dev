#!/bin/bash

# start up dev cluster with kaic
 kiac create cluster --name dev --workers 0 --cni cilium --kernel full --cpus 5 --memory 20G --gateway
 