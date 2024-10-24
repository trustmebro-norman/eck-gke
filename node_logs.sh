#!/bin/bash

kubectl logs -f -l "elasticsearch.k8s.elastic.co/node-$1=true"