# Overview

This is a built-in module to environment [pip-templates-env-master](https://github.com/pip-templates/pip-templates-env-master). 
This module stores scripts for management cloud mongodb cluster.

# Usage

- Download this repository
- Copy *src*, *lib* and *templates* folder to master template
- Add content of *.ps1.add* files to correspondent files from master template
- Add content of *config/config.mongo.json.add* to json config file from master template and set the required values

# Config parameters

Config variables description

| Variable | Default value | Description |
|----|----|---|
| aws_access_id | XXX | AWS id for access resources |
| aws_access_id | XXX | AWS access id for access resources |
| aws_access_key | XXX | AWS access key for access resources |
| aws_region | us-east-1 | AWS region where resources will be created |
| env_network_cidr | 10.9.0.0/21 | Environment cidr required for peering mongo cluster and k8s environment |
| mgmt_vpc | vpc-xxx | AWS vpc of management station |
| mgmt_network_cidr | 10.0.0.0/24 | CIDR of management station |
| mongo_enabled | true | Boolean flag to indicate is required to create mongo cluster |
| mongo_access_id | somebody@somewhere.com | Mongo Atlas credentials |
| mongo_access_key | xxx | Mongo Atlas credentials |
| mongo_org_name | pip-devs | Mongo Atlass organization name |
| mongo_group_name | pip-devs-example | Mongo Atlass group name |
| mongo_cluster_name | pip-devs-template | Mongo cluster name |
| mongo_shards | 1 | Mongo cluster shards count |
| mongo_size | 1 | Mongo cluster size in gb |
| mongo_instance_type | M2 | Mongo atlas instance size  |
| mongo_db | tracker | Mongo db name  |
| mongo_user | positron | Mongo db user |
| mongo_pass | positron#123 | Mongo db password |
| mongo_backup | true | Boolean flag to indicate is required to enable mongo atlas backups |
| mongo_network_cidr | 10.2.0.0/21 | Mongo CIDR |
