# Execute Anonymous Batch

Author: [Enrico Murru](https://enree.co)

Read details @ https://blog.enree.co/xxxxx

The `ID_LIST` *global* variable is of type `List<ID>` and contains all the IDs provided by the Batch's scope.
Example of usage:

```java
String script = 'List<Account> acList = [Select Id, Name From Account Where Id IN :ID_LIST];' 
				+'\nfor(Account acc : acList){'
                +'\n   acc.BillingCity = \'Gnite City\';'
                +'\n}'
				+'\n update acList;';

ExecuteAnonymousBatch batch = new ExecuteAnonymousBatch('Select Id From Account limit 1',script, true);
Database.executeBatch(batch, 100);
```