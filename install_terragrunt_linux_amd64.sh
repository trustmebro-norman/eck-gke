#!/bin/bash

wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.68.4/terragrunt_linux_amd64

sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt && chmod a+x /usr/local/bin/terragrunt

echo "alias tg=terragrunt" >> ~/.bashrc
source ~/.bashrc
