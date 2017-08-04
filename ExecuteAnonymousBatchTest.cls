/**
 * Test class for ExecuteAnonymousBatch
 * 
 * @author Enrico Murru (http://enree.co)
 * @version 1.0
 * @history
 * 2017-08-02 : Enrico Murru - Original version
 */
@IsTest
private class ExecuteAnonymousBatchTest {
    
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private String response{get;set;}
        private Integer status{get;set;}
        public MockHttpResponseGenerator(String response, Integer status){
            this.response = response;
            this.status = status;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','text/xml; charset=utf-8');
            res.setBody(this.response);
            res.setStatusCode(this.status);
            return res;
        }
    }
    
    @testsetup
    private static void testSetup(){
        insert new Account(Name = 'Test');
    }
    
    @IsTest
    private static void test_method_batch_execution(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, 
                     new MockHttpResponseGenerator('<response>Invalid response</response>', 500));
        ExecuteAnonymousBatch btc = new ExecuteAnonymousBatch('Select Id From Account','update ID_LIST;',true);
        Database.executeBatch(btc, 1);
        Test.stopTest();
    }
    
    @IsTest
    private static void test_method_batch_execute(){
        Test.startTest();
        
        //Invalid Http Status Code
        Test.setMock(HttpCalloutMock.class, 
                     new MockHttpResponseGenerator('<response>Invalid response</response>', 500));
        ExecuteAnonymousBatch btc = new ExecuteAnonymousBatch('Select Id From Account','update ID_LIST;',true);
        btc.execute(null, [Select Id From Account]);
        System.assert(btc.errors.isEmpty() == false, 'Why empty?');
        System.assert(btc.errors[0].contains('Unexpected server response'), 'Invalid error format: '+btc.errors);
        
        //Parsing error
        Test.setMock(HttpCalloutMock.class, 
                     new MockHttpResponseGenerator('<?xml version="1.0" encoding="UTF-8"?>'
                                                   +'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://soap.sforce.com/2006/08/apex" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
                                                   +'<soapenv:Body><executeAnonymousResponse>'
                                                   +'<result><column>1</column><compileProblem>Compilation Problem</compileProblem>'
                                                   +'<compiled>false</compiled>'
                                                   +'<exceptionMessage xsi:nil="true"/>'
                                                   +'<exceptionStackTrace xsi:nil="true"/><line>5</line>'
                                                   +'<success>false</success></result></executeAnonymousResponse></soapenv:Body>'
                                                   +'</soapenv:Envelope>', 200));
        btc = new ExecuteAnonymousBatch('Select Id From Account','update ID_LIST;',true);
        btc.execute(null, [Select Id From Account]);
        System.assert(btc.errors.isEmpty() == false, 'Why empty?');
        System.assert(btc.errors[0].contains('Compilation Problem'), 'Invalid error format: '+btc.errors);
        
        //Code Exception
        Test.setMock(HttpCalloutMock.class, 
                     new MockHttpResponseGenerator('<?xml version="1.0" encoding="UTF-8"?>'
                                                   +'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://soap.sforce.com/2006/08/apex" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
                                                   +'<soapenv:Body><executeAnonymousResponse>'
                                                   +'<result><column>1</column><compileProblem></compileProblem>'
                                                   +'<compiled>true</compiled>'
                                                   +'<exceptionMessage>Exception Thrown</exceptionMessage>'
                                                   +'<exceptionStackTrace >Stack Trace</exceptionStackTrace><line>5</line>'
                                                   +'<success>false</success></result></executeAnonymousResponse></soapenv:Body>'
                                                   +'</soapenv:Envelope>', 200));
        btc = new ExecuteAnonymousBatch('Select Id From Account','update ID_LIST;',true);
        btc.execute(null, [Select Id From Account]);
        System.assert(btc.errors.isEmpty() == false, 'Why empty?');
        System.assert(btc.errors[0].contains('Exception Thrown')
                      && btc.errors[0].contains('Stack Trace'), 'Invalid error format: '+btc.errors);
        
        //Everything is gonna be alright
        Test.setMock(HttpCalloutMock.class, 
                     new MockHttpResponseGenerator('<?xml version="1.0" encoding="UTF-8"?>'
                                                   +'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="http://soap.sforce.com/2006/08/apex" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
                                                   +'<soapenv:Body><executeAnonymousResponse>'
                                                   +'<result><column>1</column><compileProblem></compileProblem>'
                                                   +'<compiled>true</compiled>'
                                                   +'<exceptionMessage></exceptionMessage>'
                                                   +'<exceptionStackTrace ></exceptionStackTrace><line>5</line>'
                                                   +'<success>true</success></result></executeAnonymousResponse></soapenv:Body>'
                                                   +'</soapenv:Envelope>', 200));
        btc = new ExecuteAnonymousBatch('Select Id From Account','update ID_LIST;',true);
        btc.execute(null, [Select Id From Account]);
        System.assert(btc.errors.isEmpty() == true, 'Found errors: '+btc.errors);
        Test.stopTest();
    }
}