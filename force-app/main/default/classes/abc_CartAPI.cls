/**
 * REST Resource: Shopping Cart
 * URL:           /services/apexrest/abc/cart
 * Methods:       POST
 *
 * POST /services/apexrest/abc/cart
 *   Creates a new Pharmacy Order with line items.
 *   Supports both Salesforce record IDs and SKU codes as product references.
 *   Idempotent: re-submitting the same externalCartId returns the existing order.
 *
 *   Request Body (JSON):
 *     {
 *       "externalCartId":  "CART-UUID-001",   // optional — enables idempotency
 *       "customerId":      "003XXXXXXXXXXXXXXX", // optional — SF ID of abc_Customer__c
 *       "guestFirstName":  "John",             // optional — for guest checkouts
 *       "guestLastName":   "Doe",              // optional
 *       "governorate":     "Cairo",            // optional — must match picklist value
 *       "city":            "Nasr City",        // optional — must match picklist value
 *       "email":           "john@example.com", // optional
 *       "phone":           "+201001234567",    // optional
 *       "detailedAddress": "123 Main St",      // optional
 *       "items": [                             // required — at least one item
 *         { "productId": "SKU-001", "quantity": 2 },
 *         { "productId": "003XXXXXXXXXXXXXXX", "quantity": 1 }
 *       ]
 *     }
 *
 *   Response 201 (created):
 *     { "success": true, "orderId": "...", "orderNumber": "ORD-0001" }
 *   Response 200 (idempotent — order already existed):
 *     { "success": true, "message": "Cart already exists.", "orderId": "...", "orderNumber": "ORD-0001" }
 *   Response 400 (bad request):
 *     { "success": false, "error": "Cart must contain at least one item." }
 *   Response 404 (product not found):
 *     { "success": false, "error": "Product not found: SKU-999" }
 *   Response 422 (insufficient stock):
 *     { "success": false, "error": "Insufficient stock for product: Paracetamol" }
 *   Response 500 (server error):
 *     { "success": false, "error": "..." }
 */
@RestResource(urlMapping='/abc/cart/*')
global with sharing class abc_CartAPI {

    global class CartRequest {
        global String       externalCartId;
        global String       customerId;
        global String       guestFirstName;
        global String       guestLastName;
        global String       governorate;
        global String       city;
        global String       email;
        global String       phone;
        global String       detailedAddress;
        global List<CartItem> items;
    }

    global class CartItem {
        global String  productId; // Salesforce record ID or abc_SKU__c value
        global Integer quantity;
    }

    @HttpPost
    global static void createCart() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        try {
            CartRequest cartReq = (CartRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                CartRequest.class
            );

            // Validate items
            if (cartReq.items == null || cartReq.items.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error'   => 'Cart must contain at least one item.'
                }));
                return;
            }

            // Validate each item has a productId and positive quantity
            for (CartItem item : cartReq.items) {
                if (String.isBlank(item.productId)) {
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Each cart item must include a productId (SF ID or SKU).'
                    }));
                    return;
                }
                if (item.quantity == null || item.quantity <= 0) {
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Quantity must be a positive integer for product: ' + item.productId
                    }));
                    return;
                }
            }

            // Idempotency check via externalCartId
            if (String.isNotBlank(cartReq.externalCartId)) {
                List<abc_Order__c> existing = [
                    SELECT Id, Name
                    FROM abc_Order__c
                    WHERE abc_External_Cart_Id__c = :cartReq.externalCartId
                    LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success'     => true,
                        'message'     => 'Cart already exists.',
                        'orderId'     => existing[0].Id,
                        'orderNumber' => existing[0].Name
                    }));
                    return;
                }
            }

            // Collect all product references (SF ID or SKU)
            Set<String> productRefs = new Set<String>();
            for (CartItem item : cartReq.items) {
                productRefs.add(item.productId);
            }

            // Query matching products by both Id and SKU in a single query
            Map<String, abc_Product__c> productById  = new Map<String, abc_Product__c>();
            Map<String, abc_Product__c> productBySku = new Map<String, abc_Product__c>();
            for (abc_Product__c p : [
                SELECT Id, Name, abc_SKU__c, abc_Unit_Price__c, abc_Available_Quantity__c
                FROM abc_Product__c
                WHERE Id IN :productRefs OR abc_SKU__c IN :productRefs
            ]) {
                productById.put(p.Id, p);
                if (String.isNotBlank(p.abc_SKU__c)) {
                    productBySku.put(p.abc_SKU__c, p);
                }
            }

            // Validate all referenced products exist and have sufficient stock
            Map<String, abc_Product__c> resolvedProducts = new Map<String, abc_Product__c>();
            for (CartItem item : cartReq.items) {
                abc_Product__c prod = productById.containsKey(item.productId)
                    ? productById.get(item.productId)
                    : productBySku.get(item.productId);

                if (prod == null) {
                    res.statusCode = 404;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Product not found: ' + item.productId
                    }));
                    return;
                }
                if (prod.abc_Available_Quantity__c < item.quantity) {
                    res.statusCode = 422;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Insufficient stock for product: ' + prod.Name +
                                     ' (available: ' + (Integer) prod.abc_Available_Quantity__c +
                                     ', requested: ' + item.quantity + ')'
                    }));
                    return;
                }
                resolvedProducts.put(item.productId, prod);
            }

            // Build Order record
            abc_Order__c order = new abc_Order__c(
                abc_Status__c           = 'Draft',
                abc_Order_Date__c       = Date.today(),
                abc_External_Cart_Id__c = cartReq.externalCartId,
                abd_Guest_first_name__c = cartReq.guestFirstName,
                abc_Guest_Last_Name__c  = cartReq.guestLastName,
                abc_Governorate__c      = cartReq.governorate,
                abc_City__c             = cartReq.city,
                abc_Email__c            = cartReq.email,
                abc_Detailed_Address__c = cartReq.detailedAddress
            );
            if (String.isNotBlank(cartReq.phone)) {
                order.abc_Phone__c = cartReq.phone;
            }
            if (String.isNotBlank(cartReq.customerId)) {
                try {
                    order.abc_Customer__c = (Id) cartReq.customerId;
                } catch (System.TypeException ex) {
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Invalid customerId format: ' + cartReq.customerId
                    }));
                    return;
                }
            }
            insert order;

            // Build and insert Line Items — the flow handles abc_Price_per_unit__c on insert
            List<abc_Order_Line_Item__c> lineItems = new List<abc_Order_Line_Item__c>();
            for (CartItem item : cartReq.items) {
                abc_Product__c prod = resolvedProducts.get(item.productId);
                lineItems.add(new abc_Order_Line_Item__c(
                    abc_Order__c    = order.Id,
                    abc_Product__c  = prod.Id,
                    abc_Quantity__c = item.quantity
                ));
            }
            insert lineItems;

            // Re-query for the auto-number Name
            order = [SELECT Id, Name FROM abc_Order__c WHERE Id = :order.Id];

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success'     => true,
                'orderId'     => order.Id,
                'orderNumber' => order.Name
            }));

        } catch (Exception e) {
            abc_APILogger.log('abc_CartAPI', 'createCart', e);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error'   => e.getMessage()
            }));
        }
    }
}