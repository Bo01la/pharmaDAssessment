@IsTest
private class abc_ProductAPITest {

    @TestSetup
    static void setup() {
        insert new List<abc_Product__c>{
            new abc_Product__c(
                Name                      = 'Paracetamol 500mg',
                abc_SKU__c                = 'SKU-PARA-500',
                abc_Unit_Price__c         = 15.00,
                abc_Available_Quantity__c = 200
            ),
            new abc_Product__c(
                Name                      = 'Aspirin 100mg',
                abc_SKU__c                = 'SKU-ASP-100',
                abc_Unit_Price__c         = 8.50,
                abc_Available_Quantity__c = 0  // out of stock — should not appear
            )
        };
    }

    @IsTest
    static void testGetProducts_returnsOnlyAvailable() {
        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI = '/services/apexrest/abc/products';
        RestContext.request.httpMethod = 'GET';

        Test.startTest();
        abc_ProductAPI.getProducts();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected HTTP 200');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            res.responseBody.toString()
        );
        System.assertEquals(true,  body.get('success'), 'success flag should be true');
        System.assertEquals(1,     (Integer) body.get('count'), 'Only 1 product has stock');

        List<Object> data = (List<Object>) body.get('data');
        Map<String, Object> product = (Map<String, Object>) data[0];
        System.assertEquals('Paracetamol 500mg', product.get('name'));
        System.assertEquals('SKU-PARA-500',       product.get('sku'));
    }

    @IsTest
    static void testGetProducts_emptyOrg_returns200WithZeroCount() {
        delete [SELECT Id FROM abc_Product__c];

        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI = '/services/apexrest/abc/products';
        RestContext.request.httpMethod = 'GET';

        Test.startTest();
        abc_ProductAPI.getProducts();
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(200,  RestContext.response.statusCode);
        System.assertEquals(0,    (Integer) body.get('count'));
    }
}