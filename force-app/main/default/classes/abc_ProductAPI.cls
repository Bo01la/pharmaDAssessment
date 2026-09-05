/**
 * REST Resource: Product List
 * URL:           /services/apexrest/abc/products
 * Methods:       GET
 *
 * GET /services/apexrest/abc/products
 *   Returns all products with available stock (abc_Available_Quantity__c > 0).
 *   Response 200:
 *     { "success": true, "count": 3, "data": [
 *         { "id": "...", "name": "...", "sku": "...", "unitPrice": 50.0, "availableQuantity": 100 }
 *     ]}
 *   Response 500:
 *     { "success": false, "error": "..." }
 */
@RestResource(urlMapping='/abc/products/*')
global with sharing class abc_ProductAPI {

    @HttpGet
    global static void getProducts() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        try {
            List<abc_Product__c> products = [
                SELECT Id, Name, abc_SKU__c, abc_Unit_Price__c, abc_Available_Quantity__c
                FROM abc_Product__c
                WHERE abc_Available_Quantity__c > 0
                ORDER BY Name ASC
            ];

            List<Map<String, Object>> data = new List<Map<String, Object>>();
            for (abc_Product__c p : products) {
                data.add(new Map<String, Object>{
                    'id'                => p.Id,
                    'name'              => p.Name,
                    'sku'               => p.abc_SKU__c,
                    'unitPrice'         => p.abc_Unit_Price__c,
                    'availableQuantity' => (Integer) p.abc_Available_Quantity__c
                });
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'count'   => data.size(),
                'data'    => data
            }));
        } catch (Exception e) {
            abc_APILogger.log('abc_ProductAPI', 'getProducts', e);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            }));
        }
    }
}