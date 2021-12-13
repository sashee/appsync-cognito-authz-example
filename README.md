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
