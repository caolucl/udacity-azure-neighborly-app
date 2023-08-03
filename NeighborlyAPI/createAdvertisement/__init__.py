import azure.functions as func
import pymongo

def main(req: func.HttpRequest) -> func.HttpResponse:

        request = req.get_json()

        if request:
            try:
                url = "mongodb://azurecosmosdblab2:pSnTsgTC04XSVOUa5BwJ5qM3QzKeeufYNFYLSrKEjIdhrFCv9a7HE45ve5QxYAi2p5yxnudBarvNACDbQifWPw==@azurecosmosdblab2.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@azurecosmosdblab2@"
                client = pymongo.MongoClient(url)
                database = client['myfirstdatabase']
                collection = database['advertisements']

                rec_id1 = collection.insert_one(request)

                return func.HttpResponse(req.get_body())
            except ValueError:
                print("could not connect to mongodb")
                return func.HttpResponse('Could not connect to mongodb', status_code=500)
        else:
            return func.HttpResponse(
                "Please pass name in the body",
                status_code=400
            )