public without sharing class abc_APILogger {

    public static void log(String className, String methodName, Exception e) {
        try {
            insert new abc_API_Log__c(
                abc_Class_Name__c    = className,
                abc_Method_Name__c   = methodName,
                abc_Error_Message__c = e.getMessage(),
                abc_Stack_Trace__c   = e.getStackTraceString()
            );
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR, '[abc_APILogger] Failed to persist log: ' + logEx.getMessage());
        }
        System.debug(
            LoggingLevel.ERROR,
            '[ABC_API_ERROR] ' + className + '.' + methodName +
            ' | Message: ' + e.getMessage() +
            ' | Stack: ' + e.getStackTraceString()
        );
    }
}
