/**
 * Controller for the abc_WarehouseOrders Visualforce page.
 * Uses without sharing so the warehouse profile can see all orders
 * regardless of org-wide defaults or sharing rules.
 */
public without sharing class abc_WarehouseOrdersController {

    public class OrderWrapper {
        public abc_Order__c               order     { get; set; }
        public String                     icon      { get; set; }
        public List<abc_Order_Line_Item__c> lineItems { get; set; }

        public OrderWrapper(abc_Order__c o, List<abc_Order_Line_Item__c> items) {
            this.order     = o;
            this.lineItems = items;
            this.icon      = resolveIcon(o);
        }

        private String resolveIcon(abc_Order__c o) {
            if (o.abc_Status__c == 'Delivered')   return '✅';
            if (o.abc_Status__c == 'In delivery') return '🚚';
            if (o.abc_Order_Date__c == Date.today()) return '⏳';
            return '⌛';
        }
    }

    public List<OrderWrapper> orders { get; private set; }

    public abc_WarehouseOrdersController() {
        loadOrders();
    }

    private void loadOrders() {
        orders = new List<OrderWrapper>();

        List<abc_Order__c> orderList = [
            SELECT Id, Name, abc_Status__c, abc_Order_Date__c, abc_Order_Total__c,
                   (SELECT Id, abc_Product__r.Name, abc_Quantity__c, abc_Price_per_unit__c
                    FROM Order_Line_Items__r
                    ORDER BY CreatedDate ASC)
            FROM abc_Order__c
            ORDER BY abc_Order_Date__c DESC NULLS LAST, CreatedDate DESC
        ];

        for (abc_Order__c o : orderList) {
            orders.add(new OrderWrapper(o, o.Order_Line_Items__r));
        }
    }
}