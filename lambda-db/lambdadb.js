const { DynamoDBClient, ScanCommand, DeleteItemCommand, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { marshall } = require('@aws-sdk/util-dynamodb');

const dynamoDBClient = new DynamoDBClient();
const getAllRecords = async (table) => {
  let params = {
    TableName: table,
  };
  let items = [];

  try {
    let data;
    do {
      data = await dynamoDBClient.send(new ScanCommand(params));
      if (data.Items) {
        items = [...items, ...data.Items];
      }
      params.ExclusiveStartKey = data.LastEvaluatedKey;
    } while (data.LastEvaluatedKey);
  } catch (error) {
    console.error("Error scanning DynamoDB table:", error);
    throw error;
  }

  return items;
};


const deleteItem = async (table, id) => {
  const params = {
    TableName: table,
    Key: marshall({ id: id }),
  };

  try {
    await dynamoDBClient.send(new DeleteItemCommand(params));
    console.log("Success deleting item with id:", id);
  } catch (error) {
    console.error("Error deleting item with id:", id, "Error:", error);
    throw error;
  }
};

const putItem = async (table, item) => {
  const params = {
    TableName: table,
    Item: item,
  };

  try {
    await dynamoDBClient.send(new PutItemCommand(params));
    console.log("Success putting item:", item);
  } catch (error) {
    console.error("Error putting item:", item, "Error:", error);
    throw error;
  }
};

exports.handler = async (event) => {
  const operation = event.requestContext.httpMethod;

  let response;

  try {
    switch (operation) {
      case 'POST':
        const itemName = event.body
        const newItem = {
          id: { S: event.requestContext.requestId },
          name: { S: itemName },
        };
        await putItem("myDB", newItem);

        response = {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            item: itemName
          }),
        };
        break;

      case 'DELETE':
        const allRecords = await getAllRecords("myDB");
        await Promise.all(allRecords.map(item => deleteItem("myDB", item.id.S)));
        console.log("All records are deleted.");

        response = {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            listeCourse: [],
          }),
        };
        break;

      case 'GET':
        const data = await getAllRecords("myDB");
        const courses = data.map(item => item.name.S).join(',');

        response = {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            listeCourse: courses,
          }),
        };
        break;

      default:
        console.log(`Invalid method: ${operation}`);
        response = { statusCode: 500 };
        break;
    }
  } catch (error) {
    console.error("Uncaught Exception:", error);
    response = {
      statusCode: 500,
    };
  }

  return response;
};

