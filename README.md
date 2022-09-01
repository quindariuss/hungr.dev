# hungr.dev
Senior Project
Grocery Application

## Backend 

### Service: Digital Ocean 

For renting out hardware to run the services on that will connect each of the clients. 
Possibility of running a Postgres Instance really quickly, and having a functioning database. 
  
### HTTP Server: Node JS, express

Very well documented http server. 
Simple to set up, extremely performant.
Having the language be JS on the backend allows for any team member to step in quickly and start writing requests soon if need be.
Will have a variety of GET, POST, PATCH, DELETE requests to be written for the client to interact with the data storage solution. 

### Data Storage: JSON File, Postgres, SQLite

Json File: 

While it is possible to use a file based system for the requirements of the application, lots of things will have to be considered. 
File access while many agents are using it will be a problem, having a lock file in place would eliminate the cause of many users having many different states. 
At the same time the cost of this would be the UX of the application. 
Not being able to edit the contents of grocery list in a reasonable amount of time would annoy most users. 

Postgres: 

Postgres is a battle tested database that handle our requirements with ease. 
Setting up postgres to link with the node application can be a little bit of work. 
Configuring the certificates has always been a pain, and having the database instance on a different computer gives another point of failure. 

SQLite: 

The best option of all three. 
Will satisfy all the data requirements.
There are plenty of node modules for interacting with an sqlite database.
The database can live on the same machine as the http server, 
reducing the overhead of calling to another machine like we would with Postgres. 
Would also be the most accessible between the two databases because postgres can be a bear to handle. 

Auth: 

Using a table on the selected database to authorize users would be the most streamlined option. 

Users: 
Standard email and password sign up

## Frontend

The clients of the application will feed directly to the servers with only taking a local state of the saved grocery list. 
The clients will be able to send push notifications to the users about the state of the server. 


### iOS Application: 
##### Stack: 
Swift: General Multi-Paradigm Programming Language
SwiftUI: Declarative User Interface Builder, Stateful updates
Async/Await: Asynchronous method of scheduling work to be done, useful for networking and other tasks that cannot be done synchronously. 

### Android Application: 
##### Stack: 



## Website
A statically generated site to track the progress and show off the application. 

##### Stack: 
Hugo
HTML
CSS

