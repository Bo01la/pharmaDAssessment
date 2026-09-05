@IsTest
private class abc_WarehouseOrdersControllerTest {

    @TestSetup
    static void setup() {
        abc_Product__c prod = new abc_Product__c(
            Name                      = 'Amoxicillin 250mg',
            abc_SKU__c                = 'SKU-AMOX-250',
            abc_Unit_Price__c         = 35.00,
            abc_Available_Quantity__c = 100
        );
        insert prod;

        List<abc_Order__c> orders = new List<abc_Order__c>{
            new abc_Order__c(abc_Status__c = 'Delivered',   abc_Order_Date__c = Date.today().addDays(-10)),
            new abc_Order__c(abc_Status__c = 'In delivery', abc_Order_Date__c = Date.today()),
            new abc_Order__c(abc_Status__c = 'Draft',       abc_Order_Date__c = Date.today().addDays(-5)),
            new abc_Order__c(abc_Status__c = 'Draft',       abc_Order_Date__c = Date.today())
        };
        insert orders;

        insert new abc_Order_Line_Item__c(
            abc_Order__c    = orders[0].Id,
            abc_Product__c  = prod.Id,
            abc_Quantity__c = 10
        );
    }

    @IsTest
    static void testController_loadsAllOrders() {
        Test.startTest();
        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        Test.stopTest();

        System.assertEquals(4, ctrl.orders.size(), 'All 4 orders should be loaded');
    }

    @IsTest
    static void testIcon_delivered() {
        abc_Order__c o = new abc_Order__c(
            abc_Status__c     = 'Delivered',
            abc_Order_Date__c = Date.today().addDays(-1)
        );
        insert o;

        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        abc_WarehouseOrdersController.OrderWrapper delivered = null;
        for (abc_WarehouseOrdersController.OrderWrapper w : ctrl.orders) {
            if (w.order.Id == o.Id) { delivered = w; break; }
        }
        System.assertNotEquals(null, delivered);
        System.assertEquals('✅', delivered.icon);
    }

    @IsTest
    static void testIcon_inDelivery() {
        abc_Order__c o = new abc_Order__c(
            abc_Status__c     = 'In delivery',
            abc_Order_Date__c = Date.today().addDays(-3)
        );
        insert o;

        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        abc_WarehouseOrdersController.OrderWrapper wrapper = null;
        for (abc_WarehouseOrdersController.OrderWrapper w : ctrl.orders) {
            if (w.order.Id == o.Id) { wrapper = w; break; }
        }
        System.assertEquals('🚚', wrapper.icon);
    }

    @IsTest
    static void testIcon_today_draft() {
        abc_Order__c o = new abc_Order__c(
            abc_Status__c     = 'Draft',
            abc_Order_Date__c = Date.today()
        );
        insert o;

        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        abc_WarehouseOrdersController.OrderWrapper wrapper = null;
        for (abc_WarehouseOrdersController.OrderWrapper w : ctrl.orders) {
            if (w.order.Id == o.Id) { wrapper = w; break; }
        }
        System.assertEquals('⏳', wrapper.icon);
    }

    @IsTest
    static void testIcon_past_draft() {
        abc_Order__c o = new abc_Order__c(
            abc_Status__c     = 'Draft',
            abc_Order_Date__c = Date.today().addDays(-7)
        );
        insert o;

        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        abc_WarehouseOrdersController.OrderWrapper wrapper = null;
        for (abc_WarehouseOrdersController.OrderWrapper w : ctrl.orders) {
            if (w.order.Id == o.Id) { wrapper = w; break; }
        }
        System.assertEquals('⌛', wrapper.icon);
    }

    @IsTest
    static void testLineItems_loadedForOrder() {
        abc_Order__c deliveredOrder = [
            SELECT Id FROM abc_Order__c WHERE abc_Status__c = 'Delivered' LIMIT 1
        ];

        abc_WarehouseOrdersController ctrl = new abc_WarehouseOrdersController();
        abc_WarehouseOrdersController.OrderWrapper wrapper = null;
        for (abc_WarehouseOrdersController.OrderWrapper w : ctrl.orders) {
            if (w.order.Id == deliveredOrder.Id) { wrapper = w; break; }
        }
        System.assertNotEquals(null, wrapper);
        System.assertEquals(1, wrapper.lineItems.size(), 'One line item should be loaded');
        System.assertNotEquals(null, wrapper.lineItems[0].abc_Product__r.Name);
    }
}