#! /bin/sh

resourceGroup=luccvfptrg
########################################
# Variables for the Function App
# Must be unique worldwide
functionApp=luccvfptfunctionapp
# Must be unique worldwide
storageAccount=luccvfptstorageaccount
region=eastus
########################################
# Variables for MongoDB API resources
# Needs to be lower case
cosmosDBAccountName="azurecosmosdblab2" 
serverVersion='4.0'
# MongoDB database name
databaseName='myfirstdatabase'
# Collection within the MongoDB database
collectionName1='advertisements'
collectionName2='posts'

########################################
# General purpose variables
# uniqueId=$RANDOM
########################################
# Must be unique worldwide
webApp='luccvfptWebApp'
########################################
containerRegistry='luccvfptacr'
AKSCluster='luccvfptakscluster'
imageName='luccvfptimage'
imageTag='latest'
########################################

########################################
namespaceName="udacityneighborlylcao"
eventhubName="dev"

# create resource group
az group create -l $region -n $resourceGroup

# create cosmosdb account
az cosmosdb create \
    -n $cosmosDBAccountName \
    -g $resourceGroup \
    --kind MongoDB \
    --server-version $serverVersion \
    --default-consistency-level Eventual \
    --enable-automatic-failover false

printf ' 
[ 
    {
        "key": {"keys": ["_id"]}
    }
]' > idxpolicy-2023.json

# create collections
az cosmosdb mongodb collection create \
    -a $cosmosDBAccountName \
    -g $resourceGroup \
    -d $databaseName \
    -n $collectionName1 \
    --shard '_id' \
    --throughput 400 \
    --idx @idxpolicy-2023.json

az cosmosdb mongodb collection create \
    -a $cosmosDBAccountName \
    -g $resourceGroup \
    -d $databaseName \
    -n $collectionName2 \
    --shard '_id' \
    --throughput 400 \
    --idx @idxpolicy-2023.json

#Import data into mongodb

# Get mongodb connection string
# Fetch and store the connection string
connectionString=$(az cosmosdb keys list \
--type connection-strings \
--name $cosmosDBAccountName \
--resource-group $resourceGroup \
  --query 'connectionStrings[0].connectionString' \
--output tsv) 
echo "MongoDB connection string..."
echo $connectionString

# Create function app in Azure
az storage account create \
  --name $storageAccount \
  --location $region \
  --resource-group $resourceGroup \
  --sku Standard_LRS

az functionapp create \
  --name $functionApp  \
  --storage-account $storageAccount \
  --consumption-plan-location $region \
  --resource-group $resourceGroup \
  --functions-version 4 \
  --os-type Linux \
  --runtime python

# connect cosmosdb to func app
az functionapp config appsettings set \
  --name $functionApp \
  --resource-group $resourceGroup \
  --setting MyDbConnection=$connectionString


# create event hub
az eventhubs namespace create --name $namespaceName --resource-group $resourceGroup -l $region
az eventhubs eventhub create --name $eventhubName --resource-group $resourceGroup --namespace-name $namespaceName

# Create function app on local
func init NeighborlyAPI --python
cd NeighborlyAPI
# create a new function in local
func new --name createAdvertisement --template "HTTP trigger" --authlevel "anonymous"
func new --name deleteAdvertisement --template "HTTP trigger" --authlevel "anonymous"
func new --name eventHubTrigger --template "Event Grid trigger"
func new --name getAdvertisement --template "HTTP trigger" --authlevel "anonymous"
func new --name getAdvertisements --template "HTTP trigger" --authlevel "anonymous"
func new --name getPost --template "HTTP trigger" --authlevel "anonymous"
func new --name getPosts --template "HTTP trigger" --authlevel "anonymous"
func new --name updateAdvertisement --template "HTTP trigger" --authlevel "anonymous"

## run in local
func start

# publish function app
func azure functionapp publish $functionApp

# Get func app
az functionapp list  --resource-group $resourceGroup

# Create web app on local
# create a new virtual environment with virtualenv tool, and name it venv

cd ../NeighborlyFrontEnd
python3 -m venv venv

# activate the environment
source venv/bin/activate

# Needed only for local run
python3 -m pip install -r requirements.txt

# export variable so the Azure stack knows which entry point to start your Flask app.  If your application file is named `application.py` or `something_else.py`, then you can replace that here.    
export FLASK_RUN=app.py
flask run


# create web app in Azure
cd ../NeighborlyFrontEnd
az webapp up --sku F1   --name $webApp   --resource-group $resourceGroup   --location $region

# Run from within the existing Function project directory.
cd ../NeighborlyAPI
func init --docker-only --python

# docker build -t <name:tag> <path>
docker build -t $imageName:$imageTag .

docker run -p 7071:7071 -it $imageName:$imageTag

az login
# Create a repository in ACR service
az group create --location $region --name $resourceGroup
az acr create --resource-group $resourceGroup --name $containerRegistry --sku Basic

az acr update -n $containerRegistry --admin-enabled true
password=$(az acr credential show -n $containerRegistry --query 'passwords[0].value' -o tsv)

docker login $containerRegistry.azurecr.io
docker tag   $imageName:$imageTag $containerRegistry.azurecr.io/$imageName:$imageTag
docker push $containerRegistry.azurecr.io/$imageName:$imageTag

# View the newly pushed image in the ACR respository
az acr repository list --name $containerRegistry --output table


az extension add --name aks-preview
az extension update --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "AKS-KedaPreview"
az feature show --namespace "Microsoft.ContainerService" --name "AKS-KedaPreview"
az provider register --namespace Microsoft.ContainerService

# Create AKS
az aks create \
--name $AKSCluster \
--resource-group $resourceGroup \
--node-count 1 \
--generate-ssh-keys \
--attach-acr $containerRegistry \
--location $region \
--enable-keda 

az aks update \
  --resource-group $resourceGroup \
  --name $AKSCluster \
  --enable-keda 
# Get credentials for your container service
az aks get-credentials \
  --name $AKSCluster \
  --resource-group $resourceGroup

# Get nodes of AKS
kubectl get nodes

# Deploy the App to Kubernetes
func kubernetes deploy \
  --name $functionApp \
  --registry $containerRegistry.azurecr.io
# option
func kubernetes deploy \
  --name $functionApp \
  --registry $containerRegistry.azurecr.io \
  --dry-run > deploy.yml

# Check your deployment
kubectl config get-contexts

# Delete the resource group
az group delete --name $resourceGroup
