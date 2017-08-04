/**
 * Batch for Execute Anonymous
 * 
 * @author Enrico Murru (http://enree.co)
 * @version 1.0
 * @description Execute custom code in batch. Needs a named credentials with OAuth 2.0 on running user.
 * Example
 * String script = 'List<Account> acList = [Select Id, Name From Account Where Id IN :ID_LIST];' 
 *		+'\nfor(Account acc : acList){'
 *		+'\n   acc.BillingCity = \'Gnite City\';'
 *		+'\n}'
 *		+'\n update acList;';
 * ExecuteAnonymoutBatch batch = new ExecuteAnonymoutBatch('Select Id From Account',script, true);
 * Database.executeBatch(batch, 100);
 * @history
 * 2017-08-02 : Enrico Murru - Original version
 */
public class ExecuteAnonymousBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final String API_VERSION = '40.0';
    private static final String NAMED_CREDENTIAL = 'EXECUTE_ANONYMOUS';

    private String executeScript{get;set;}
    private String soqlQuery{get;set;}
    @testVisible
    private List<String> errors{get;set;}
    private Boolean sendEmail{get;set;}
    
    /*
     * Constructor
     * @param soqlQuery - SOQL query to be issued
     * @param executeScript - Apex script to be executed: the script has the "ID_LIST" list of type List<ID>
     * @param sendEmail - send a finish email
     */
    public ExecuteAnonymousBatch(String soqlQuery, String executeScript, Boolean sendEmail){
        this.executeScript = executeScript;
        this.soqlQuery = soqlQuery;
        this.errors = new List<String>();
        this.sendEmail = sendEmail;
    }
    
    /*
     * Batchable Start method
     */
    public Iterable<SObject> start(Database.BatchableContext BC){
        return Database.query(this.soqlQuery);
    }
    
    /*
     * Executes the anonymous code on the batch objects.
     * The original script is "augmented" by the ID_List variable (of type List<ID>)
     * that contains the list of current batch's ids.
     */
    public void execute(Database.BatchableContext BC, List<SObject> scope){
        List<ID> scopeIds = new List<ID>();
        for(Sobject obj : scope){
            scopeIds.add((ID)obj.get('Id'));
        }
        
        String idList = '\''+String.join(scopeIds, '\',\'')+'\'';
        String script = 'List<ID> ID_LIST = new List<ID>{'
            + idList
            + '};\n'
            + this.executeScript;
        String result = executeAnonymous(script);
        if(String.isNotBlank(result)){
            errors.add(idList+': '+result);
        }
    }
    
    /*
     * Sends an email when done
     */
    public void finish(Database.BatchableContext BC) {
        
        if(sendEmail == true){
            String subject = 'Elaboration completed: ';
            if(this.errors.isEmpty()){
                subject += ' no errors.';
            }else{
                subject += ' with '+this.errors.size()+' errors.';
            }
            String body = 'Query: \n\t'
                        +this.soqlQuery
                        +'\nExecute anonymous code: \n\t'
                        +this.executeScript.replace('\n','\n\t')
                        +'\nErrors:\n\t'
                        +String.join(this.errors,'\n\t')
                		+'\n\n\nSent by: '+userinfo.getUserName();
            sendEmail(subject,body);
        }
    }
    
    /*
     * Executes the execute anonymous script.
     * Uses a named credential to get a valid session ID.
     * @param script - script to be executed (contains the ID_LIST variable)
     * @return (String) error message or null in case of success
     */
    private static String executeAnonymous(String script){
        String apexNS = 'http://soap.sforce.com/2006/08/apex';
        String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
        String url = 'callout:'+NAMED_CREDENTIAL+'/services/Soap/s/'+API_VERSION;
        //SOAP call gives you the possibility to get the debuglog as well
        String body = '<soapenv:Envelope xmlns:soapenv="'+soapNS+'" xmlns:apex="'+apexNS+'">'
            +'<soapenv:Header>'
            +'<apex:SessionHeader>'
            +'<apex:sessionId>{!$Credential.OAuthToken}</apex:sessionId>'
            +'</apex:SessionHeader>'
            +'</soapenv:Header>'
            +'<soapenv:Body>'
            +'<apex:executeAnonymous>'
            +'<apex:String><![CDATA['
            + script
            +']]></apex:String>'
            +'</apex:executeAnonymous>'
            +'</soapenv:Body>'
            +'</soapenv:Envelope>';
        Http h = new Http();
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setMethod('POST');
        request.setHeader('Content-Type','text/xml; charset=utf-8');
        request.setHeader('SOAPAction','executeAnonymous');
        
        request.setEndpoint(url);
        request.setBody(body);
        try{
            HttpResponse resp = h.send(request);
            if(resp.getStatusCode() != 200){
                return 'Unexpected server response ['+resp.getStatusCode()+']: '+resp.getBody();
            }
            
            Dom.Document doc = resp.getBodyDocument();
            Dom.XMLNode rootNode = doc.getRootElement();
            Dom.XMLNode bodyNode = rootNode.getChildElement('Body', soapNS);
            Dom.XMLNode executeAnonymousResponseNode = bodyNode.getChildElement('executeAnonymousResponse', apexNS);
            Dom.XMLNode resultNode = executeAnonymousResponseNode.getChildElement('result', apexNS);
            String success = resultNode.getChildElement('success',apexNS).getText();
            if(success != 'true'){
                String rslt = (resultNode.getChildElement('exceptionMessage', apexNS).getTExt() +' -- '
                    + resultNode.getChildElement('exceptionStackTrace',apexNS).getText())
                    + ((resultNode.getChildElement('compiled',apexNS).getText() == 'false')?
                    	('Compilation problem: '+resultNode.getChildElement('compileProblem',apexNS).getText()
                    	+ ' Line: '+resultNode.getChildElement('line',apexNS).getText()
                    	+ ' Column: '+resultNode.getChildElement('column',apexNS).getText()):'');
                return rslt;
            }
            
            return null;
        }catch(Exception e){
            return 'Fatal exception on batch code: '+e.getMessage()+' | '+e.getStackTraceString().replaceAll('\\n',' >> ');
        }
    }
    
    /**
     * Sends an email to current user
     * @param subject - email's subject
     * @param message - email's body
     */
    private static void sendEmail(String subject, String message)
    {
        Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        subject = '[Execute Anonymous Batch] '+subject;
        mail.setSubject(subject);
        mail.setPlainTextBody(message);
        if(Test.isRunningTest()==false){
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}