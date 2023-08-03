import azure.functions as func
import pymongo
from bson.objectid import ObjectId


def main(req: func.HttpRequest) -> func.HttpResponse:

    id = req.params.get('id')

    if id:
        try:
            url = "mongodb://azurecosmosdblab2:pSnTsgTC04XSVOUa5BwJ5qM3QzKeeufYNFYLSrKEjIdhrFCv9a7HE45ve5QxYAi2p5yxnudBarvNACDbQifWPw==@azurecosmosdblab2.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@azurecosmosdblab2@"
            client = pymongo.MongoClient(url)
            database = client['myfirstdatabase']
            collection = database['advertisements']
            
            query = {'_id': ObjectId(id)}
            result = collection.delete_one(query)
            return func.HttpResponse("")

        except:
            print("could not connect to mongodb")
            return func.HttpResponse("could not connect to mongodb", status_code=500)

    else:
        return func.HttpResponse("Please pass an id in the query string",
                                 status_code=400)