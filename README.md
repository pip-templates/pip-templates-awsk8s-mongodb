# Overview
Scriptable databases introduce “infrastructure as a code” into devops practices. Scripts for install cloud mongo cluster.

# Syntax
All sripts have one required parameter - *$ConfigPath*. This is the path to config, path can be absolute or relative. 

**Examples of installing aks**
Relative path example (you should be in *piptemplates-devops-envmgmt* folder):
`
./cloud/install_mongo.ps1 ./config/cloud_config.json
`
Absolute path example:
`
~/pip-templates-mongodb-cloud/cloud/install_mongo.ps1 ~/pip-templates-mongodb-cloud/config/cloud_config.json
`

**Example delete script**
`
./cloud/destroy_mongo.ps1 ./config/cloud_config.json
`

Also you can install environment using single script:
`
./create_env.ps1 ./config/cloud_config.json
`

Delete whole environment:
`
./delete_env.ps1 ./config/cloud_config.json
`

If you have any problem with not installed tools - use `install_prereq_` script for you type of operation system.

# Project structure
| Folder | Description |
|----|----|
| Cloud | Scripts related to management cloud environment. | 
| Config | Config files for scripts. Store *example* configs for each environment, recomendation is not change this files with actual values, set actual values in duplicate config files without *example* in name. Also stores *resources* files, created automaticaly. | 
| Lib | Scripts with support functions like working with configs, templates etc. | 

### Cloud mongo

* Cloud mongo config parameters

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
