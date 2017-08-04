# Execute Anonymous Batch

Author: [Enrico Murru](https://enree.co)

Read details @ http://blog.enree.co/2017/08/salesforce-apex-execute-anonymous-batch.html

The `ID_LIST` *global* variable is of type `List<ID>` and contains all the IDs provided by the Batch's scope.

Example of usage:

```java
String script = 'List<Account> acList = [Select Id, Name From Account Where Id IN :ID_LIST];' 
				+'\nfor(Account acc : acList){'
				+'\n   acc.BillingCity = \'Gnite City\';'
				+'\n}'
				+'\n update acList;';
String query = 'Select Id From Account Where BillingCity != \'Gnite City\'';
ExecuteAnonymousBatch batch = new ExecuteAnonymousBatch(query, script, true);
Database.executeBatch(batch, 100);
```

The job sends a completion email with all eventual errors on finish.