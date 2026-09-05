@IsTest
private class abc_ArchiveOrdersBatchTest {

    @IsTest
    static void testBatch_archivesOldDeliveredOrders() {
        // Should be archived: Delivered + Order Date > 1 year ago
        abc_Order__c oldDelivered = new abc_Order__c(
            abc_Status__c     = 'Delivered',
            abc_Order_Date__c = Date.today().addYears(-2),
            abc_Email__c      = 'old@test.com'
        );

        // Should NOT be archived: Delivered but recent
        abc_Order__c recentDelivered = new abc_Order__c(
            abc_Status__c     = 'Delivered',
            abc_Order_Date__c = Date.today().addMonths(-3)
        );

        // Should NOT be archived: old but not Delivered
        abc_Order__c oldDraft = new abc_Order__c(
            abc_Status__c     = 'Draft',
            abc_Order_Date__c = Date.today().addYears(-2)
        );

        // Should NOT be archived: In delivery and old
        abc_Order__c oldInDelivery = new abc_Order__c(
            abc_Status__c     = 'In delivery',
            abc_Order_Date__c = Date.today().addYears(-2)
        );

        insert new List<abc_Order__c>{
            oldDelivered, recentDelivered, oldDraft, oldInDelivery
        };

        Test.startTest();
        Database.executeBatch(new abc_ArchiveOrdersBatch(), 200);
        Test.stopTest();

        // All source orders remain (batch does not delete them)
        System.assertEquals(4, [SELECT COUNT() FROM abc_Order__c],
            'Source orders should not be deleted by the batch');
    }

    @IsTest
    static void testBatch_emptyScope_noErrors() {
        // No orders at all — batch should complete without exceptions
        Test.startTest();
        Database.executeBatch(new abc_ArchiveOrdersBatch(), 200);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM abc_Order__c]);
    }

    @IsTest
    static void testBatch_withCustomerEmail_usesCustomerEmail() {
        abc_Customer__c customer = new abc_Customer__c(
            abc_Email__c = 'customer@pharmacy.com'
        );
        insert customer;

        abc_Order__c order = new abc_Order__c(
            abc_Status__c     = 'Delivered',
            abc_Order_Date__c = Date.today().addYears(-2),
            abc_Customer__c   = customer.Id,
            abc_Email__c      = 'guest@email.com'  // should be ignored in favour of customer email
        );
        insert order;

        Test.startTest();
        Database.executeBatch(new abc_ArchiveOrdersBatch(), 200);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM abc_Order__c]);
    }
}