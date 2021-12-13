# AppSync Cognito Authorization Example Project

This repo shows the different ways to control access in AppSync for Cognito users. This creates all the resources that is needed.

## Requirements

* Terraform
* AWS account + configured AWS CLI

## Deploy

* ```terraform apply```

## Data model

There are **users** that can be in 2 groups: ```admin``` and ```user```. Admin users can query all users, while normal users can only query themselves.

There are also **documents** that have an access level: ```PUBLIC``` and ```SECRET```. Everybody can query ```PUBLIC``` documents, but only users with the ```secret_documents``` permissions (stored for the user object) can retrieve ```SECRET``` ones.

## Usage

* Go to the AppSync console and select the API. Go to the Queries menu.
* Log in with ```user1``` (```user1```/```Password.1```)

![image](https://user-images.githubusercontent.com/82075/145780350-b9fb5696-da1c-41fe-b14d-74d642ac9b66.png)

* Send the ```me``` query and note the sub

![image](https://user-images.githubusercontent.com/82075/145780475-b357e5f4-0862-410e-960a-3ee184cc1ecd.png)

* Send a query to the ```user``` query with this sub:

![image](https://user-images.githubusercontent.com/82075/145780596-ca91e0a9-930c-4c93-8659-31174114fb1e.png)

* Change the sub and see an Unauthorized error:

![image](https://user-images.githubusercontent.com/82075/145780674-2250edc7-df59-4162-a24a-0a8d0582a187.png)

* The ```allUsers``` does not work:

![image](https://user-images.githubusercontent.com/82075/145780769-b084482e-4b45-4a2c-83c9-9fa1823576a2.png)

* Logout and login as an admin:

![image](https://user-images.githubusercontent.com/82075/145780876-c592560b-8faf-4def-a942-51452d25da5f.png)

* ```allUsers``` now works:

![image](https://user-images.githubusercontent.com/82075/145780948-29019e82-8580-4cac-b216-54a7cfd42460.png)

* As well as getting users:

![image](https://user-images.githubusercontent.com/82075/145781055-950b3af4-3017-4c6e-bfab-b5fc6a3cd6d3.png)

* Login back as user1
* Get the documents:

![image](https://user-images.githubusercontent.com/82075/145781142-1720d80f-b50a-41fc-82cc-89a1dad89db5.png)

* Logout and login with user2
* Query the documents again:

![image](https://user-images.githubusercontent.com/82075/145781232-6662d0b5-c068-42e8-8986-09f6dc09d7a9.png)

## Cleanup

```terraform destroy```
