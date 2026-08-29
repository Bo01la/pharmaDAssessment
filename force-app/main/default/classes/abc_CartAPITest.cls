@IsTest
private class abc_CartAPITest {

    static abc_Product__c testProduct;

    @TestSetup
    static void setup() {
        insert new abc_Product__c(
            Name                      = 'Ibuprofen 400mg',
            abc_SKU__c                = 'SKU-IBU-400',
            abc_Unit_Price__c         = 20.00,
            abc_Available_Quantity__c = 50
        );
    }

    static void setUpRequest(Map<String, Object> body) {
        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI  = '/services/apexrest/abc/cart';
        RestContext.request.httpMethod  = 'POST';
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(body));
    }

    @IsTest
    static void testCreateCart_bySalesforceId_success() {
        abc_Product__c prod = [SELECT Id FROM abc_Product__c LIMIT 1];

        setUpRequest(new Map<String, Object>{
            'externalCartId' => 'CART-TEST-001',
            'guestFirstName' => 'Ahmed',
            'guestLastName'  => 'Ali',
            'email'          => 'ahmed@test.com',
            'items'          => new List<Object>{
                new Map<String, Object>{ 'productId' => prod.Id, 'quantity' => 3 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true, body.get('success'));
        System.assertNotEquals(null, body.get('orderId'));
        System.assertNotEquals(null, body.get('orderNumber'));

        System.assertEquals(1, [SELECT COUNT() FROM abc_Order__c]);
        System.assertEquals(1, [SELECT COUNT() FROM abc_Order_Line_Item__c]);

        abc_Order__c order = [SELECT abc_External_Cart_Id__c, abc_Status__c FROM abc_Order__c LIMIT 1];
        System.assertEquals('CART-TEST-001', order.abc_External_Cart_Id__c);
        System.assertEquals('Draft',         order.abc_Status__c);
    }

    @IsTest
    static void testCreateCart_bySKU_success() {
        setUpRequest(new Map<String, Object>{
            'items' => new List<Object>{
                new Map<String, Object>{ 'productId' => 'SKU-IBU-400', 'quantity' => 1 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        System.assertEquals(1,   [SELECT COUNT() FROM abc_Order_Line_Item__c]);
    }

    @IsTest
    static void testCreateCart_idempotency_returnsExisting() {
        abc_Product__c prod = [SELECT Id FROM abc_Product__c LIMIT 1];
        Map<String, Object> requestBody = new Map<String, Object>{
            'externalCartId' => 'CART-DUPE-001',
            'items'          => new List<Object>{
                new Map<String, Object>{ 'productId' => prod.Id, 'quantity' => 1 }
            }
        };

        // First call — creates the order
        setUpRequest(requestBody);
        abc_CartAPI.createCart();

        // Second call — should return 200 with existing order
        setUpRequest(requestBody);
        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals('Cart already exists.', body.get('message'));
        System.assertEquals(1, [SELECT COUNT() FROM abc_Order__c]);
    }

    @IsTest
    static void testCreateCart_emptyItems_returns400() {
        setUpRequest(new Map<String, Object>{
            'items' => new List<Object>()
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void testCreateCart_nullItems_returns400() {
        setUpRequest(new Map<String, Object>{
            'externalCartId' => 'CART-NULL'
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testCreateCart_productNotFound_returns404() {
        setUpRequest(new Map<String, Object>{
            'items' => new List<Object>{
                new Map<String, Object>{ 'productId' => 'SKU-DOES-NOT-EXIST', 'quantity' => 1 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void testCreateCart_insufficientStock_returns422() {
        abc_Product__c prod = [SELECT Id FROM abc_Product__c LIMIT 1];
        setUpRequest(new Map<String, Object>{
            'items' => new List<Object>{
                new Map<String, Object>{ 'productId' => prod.Id, 'quantity' => 9999 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode);
    }

    @IsTest
    static void testCreateCart_invalidCustomerId_returns400() {
        abc_Product__c prod = [SELECT Id FROM abc_Product__c LIMIT 1];
        setUpRequest(new Map<String, Object>{
            'customerId' => 'not-a-valid-sf-id',
            'items'      => new List<Object>{
                new Map<String, Object>{ 'productId' => prod.Id, 'quantity' => 1 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void testCreateCart_blankProductId_returns400() {
        setUpRequest(new Map<String, Object>{
            'items' => new List<Object>{
                new Map<String, Object>{ 'productId' => '', 'quantity' => 1 }
            }
        });

        Test.startTest();
        abc_CartAPI.createCart();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}
