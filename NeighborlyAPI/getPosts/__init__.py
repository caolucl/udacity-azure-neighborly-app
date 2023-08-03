import logging
import azure.functions as func
import pymongo
import json
from bson.json_util import dumps


def main(req: func.HttpRequest) -> func.HttpResponse:

    logging.info('Python getPosts trigger function processed a request.')

    try:
        url = "mongodb://azurecosmosdblab2:pSnTsgTC04XSVOUa5BwJ5qM3QzKeeufYNFYLSrKEjIdhrFCv9a7HE45ve5QxYAi2p5yxnudBarvNACDbQifWPw==@azurecosmosdblab2.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@azurecosmosdblab2@"
        client = pymongo.MongoClient(url)
        database = client['myfirstdatabase']
        collection = database['posts']

        result = collection.find({})
        result = dumps(result)

        return func.HttpResponse(result, mimetype="application/json", charset='utf-8', status_code=200)
    except:
        return func.HttpResponse("Bad request.", status_code=400)