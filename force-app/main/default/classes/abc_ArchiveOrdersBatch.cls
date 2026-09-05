/**
 * Batch class: abc_ArchiveOrdersBatch
 *
 * Archives abc_Order__c records into the abc_Archived_Order__b Big Object
 * when both conditions are met:
 *   1. abc_Status__c = 'Delivered'
 *   2. abc_Order_Date__c is more than 1 year before today
 *
 * Scheduled usage:
 *   Database.executeBatch(new abc_ArchiveOrdersBatch(), 200);
 */
public with sharing class abc_ArchiveOrdersBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date cutoff = Date.today().addYears(-1);
        return Database.getQueryLocator([
            SELECT Id, Name,
                   abc_Status__c,
                   abc_Order_Date__c,
                   abc_Order_Total__c,
                   abc_External_Cart_Id__c,
                   abc_Governorate__c,
                   abc_City__c,
                   abc_Detailed_Address__c,
                   abc_Client_Type__c,
                   abc_Email__c,
                   abc_Customer__r.abc_Email__c
            FROM abc_Order__c
            WHERE abc_Status__c = 'Delivered'
            AND   abc_Order_Date__c < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<abc_Order__c> scope) {
        List<abc_Archived_Order__b> archives = new List<abc_Archived_Order__b>();

        for (abc_Order__c order : scope) {
            // Prefer the linked customer email; fall back to the order-level email for guest orders
            String customerEmail = (order.abc_Customer__r != null && String.isNotBlank(order.abc_Customer__r.abc_Email__c))
                ? order.abc_Customer__r.abc_Email__c
                : order.abc_Email__c;

            archives.add(new abc_Archived_Order__b(
                abc_Order_Number__c     = order.Name,
                abc_Order_Date__c       = DateTime.newInstance(
                                              order.abc_Order_Date__c,
                                              Time.newInstance(0, 0, 0, 0)
                                          ),
                abc_Status__c           = order.abc_Status__c,
                abc_Order_Total__c      = order.abc_Order_Total__c,
                abc_Customer_Email__c   = customerEmail,
                abc_External_Cart_Id__c = order.abc_External_Cart_Id__c,
                abc_Governorate__c      = order.abc_Governorate__c,
                abc_City__c             = order.abc_City__c,
                abc_Detailed_Address__c = order.abc_Detailed_Address__c,
                abc_Client_Type__c      = order.abc_Client_Type__c
            ));
        }

        if (!archives.isEmpty()) {
            Database.insertImmediate(archives);
        }
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        System.debug(
            '[abc_ArchiveOrdersBatch] Complete — Processed: ' + job.JobItemsProcessed +
            ' batches | Errors: ' + job.NumberOfErrors +
            ' | Status: ' + job.Status
        );
    }
}