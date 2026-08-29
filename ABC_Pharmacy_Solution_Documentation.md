# ABC Pharmacy — Salesforce Solution Documentation

**Project:** ABC Pharmacy Order Management System
**Org:** orgfarm-7e74891727-dev-ed.develop.my.salesforce.com
**API Version:** 67.0 (Winter '26)
**Prepared by:** Abdelrhman Ehab Abdelkhalek
**Date:** August 2026

---

## Table of Contents

1. [Solution Overview](#1-solution-overview)
2. [Data Model](#2-data-model)
3. [Apex Components](#3-apex-components)
4. [Salesforce Features Used](#4-salesforce-features-used)
5. [API Reference](#5-api-reference)
6. [Org Access](#6-org-access)

---

## 1. Solution Overview

The ABC Pharmacy solution is a Salesforce-based order management system that:

- Allows **admin and pharmacist users** to manage products, customers, and orders via a custom Lightning app
- Exposes **two REST API endpoints** for the Ionic web app to browse products and place orders
- Provides a **Visualforce page** for the warehouse user to track orders with at-a-glance status icons
- Automatically **archives** old delivered orders to a Big Object to maintain data hygiene
- Logs all API errors to a dedicated custom object for observability

All custom metadata follows the `abc_` API name prefix convention as required.

---

## 2. Data Model

### 2.1 Entity Relationship Diagram (ERD)

```
┌─────────────────────────┐
│    abc_Customer__c      │
│─────────────────────────│
│ PK  Id                  │
│     Name (text)         │
│     abc_Email__c        │
│     abc_Phone__c        │
│     abc_DateOfBirth__c  │
│     abc_Governorate__c  │
│     abc_City__c         │
│     abc_Detailed_       │
│       Address__c        │
└────────────┬────────────┘
             │ Lookup (0..1)
             │ SetNull on delete
             ▼
┌─────────────────────────┐          ┌─────────────────────────┐
│      abc_Order__c       │          │    abc_Product__c       │
│─────────────────────────│          │─────────────────────────│
│ PK  Id                  │          │ PK  Id                  │
│     Name (AutoNumber    │          │     Name (text)         │
│       ORD-{0000})       │          │     abc_SKU__c          │
│     abc_Customer__c ────┘          │       (ExternalId,      │
│     abc_Status__c                  │        Unique)          │
│       (Picklist:        │          │     abc_Unit_Price__c   │
│        Draft /          │          │     abc_Buying_price__c │
│        In delivery /    │          │     abc_Profit__c       │
│        Delivered)       │          │     abc_Available_      │
│     abc_Order_Date__c   │◄─────────┤       Quantity__c       │
│     abc_Order_Total__c  │          └────────────┬────────────┘
│       (Roll-up Sum)     │                       │ Lookup (required)
│     abc_External_       │                       │ Restrict delete
│       Cart_Id__c        │                       ▼
│       (ExternalId,      │   ┌───────────────────────────────────┐
│        Unique)          │   │       abc_Order_Line_Item__c      │
│     abd_Guest_          │   │───────────────────────────────────│
│       first_name__c     │   │ PK  Id                            │
│     abc_Guest_          │   │     abc_Order__c (MasterDetail) ──┘
│       Last_Name__c      │   │     abc_Product__c (Lookup)        │
│     abc_Governorate__c  │   │     abc_Quantity__c               │
│     abc_City__c         │   │     abc_Price_per_unit__c         │
│     abc_Email__c        │   │       (set by Flow on insert)     │
│     abc_Phone__c        │   │     abc_Total_Price__c            │
│     abc_Detailed_       │   │       (Formula: Qty × Price)      │
│       Address__c        │   │     abc_Unit_Price__c             │
│     abc_Client_Type__c  │   └───────────────────────────────────┘
└─────────────────────────┘

                              ┌───────────────────────────────────┐
                              │      abc_Archived_Order__b        │
                              │  (Big Object — Index on           │
                              │   Order Date DESC, Order          │
                              │   Number ASC)                     │
                              │───────────────────────────────────│
                              │     abc_Order_Date__c (DateTime)  │
                              │     abc_Order_Number__c (Text)    │
                              │     abc_Status__c (Text)          │
                              │     abc_Order_Total__c (Number)   │
                              │     abc_Customer_Email__c         │
                              │     abc_External_Cart_Id__c       │
                              │     abc_Governorate__c (Text)     │
                              │     abc_City__c (Text)            │
                              │     abc_Client_Type__c (Text)     │
                              │     abc_Detailed_Address__c       │
                              └───────────────────────────────────┘

                              ┌───────────────────────────────────┐
                              │         abc_API_Log__c            │
                              │───────────────────────────────────│
                              │     Name (AutoNumber LOG-{0000})  │
                              │     abc_Class_Name__c             │
                              │     abc_Method_Name__c            │
                              │     abc_Error_Message__c          │
                              │     abc_Stack_Trace__c            │
                              └───────────────────────────────────┘
```

### 2.2 Objects Reference

| Object | Type | Purpose |
|---|---|---|
| `abc_Customer__c` | Custom | Stores registered pharmacy customer profiles |
| `abc_Product__c` | Custom | Pharmacy product catalog with pricing and stock |
| `abc_Order__c` | Custom | Pharmacy orders (supports both registered and guest users) |
| `abc_Order_Line_Item__c` | Custom | Individual line items within an order (Master-Detail to Order) |
| `abc_Archived_Order__b` | Big Object | Immutable archive of delivered orders older than 1 year |
| `abc_API_Log__c` | Custom | Structured error log records written by API classes |

### 2.3 Key Design Decisions

**Guest vs. Registered Orders**
`abc_Order__c.abc_Customer__c` is a nullable Lookup rather than a required Master-Detail. This allows the Ionic app to place orders for guest users (using `abd_Guest_first_name__c`, `abc_Guest_Last_Name__c`, and `abc_Email__c` on the order) without requiring account creation. Guest and registered orders share the same object, simplifying reporting.

**Price Freezing on Line Items**
`abc_Order_Line_Item__c.abc_Price_per_unit__c` is populated by a before-save Flow (not by the Ionic app) at the moment the line item is created. This ensures that future changes to a product's `abc_Unit_Price__c` do not retroactively alter historical order values.

**Idempotent Cart API**
`abc_Order__c.abc_External_Cart_Id__c` is an External ID / Unique Text field. The cart API checks this field before inserting, so the Ionic app can safely retry failed requests without creating duplicate orders.

**Big Object for Archiving**
`abc_Archived_Order__b` is used instead of a standard custom object for long-term archiving because Big Objects offer virtually unlimited storage at low cost and are well suited for append-only historical records. The index is ordered by `abc_Order_Date__c DESC` so the most recent archived orders are retrieved first.

**SKU as External ID on Products**
`abc_Product__c.abc_SKU__c` is marked as an External ID and Unique. This allows the Ionic app to reference products by their real-world SKU codes instead of Salesforce record IDs, which would be meaningless to the Ionic app's product catalog.

---

## 3. Apex Components

### 3.1 REST API Classes

#### `abc_ProductAPI`
| | |
|---|---|
| **Type** | `@RestResource`, `global with sharing` |
| **URL** | `/services/apexrest/abc/products` |
| **Method** | `GET` |
| **Purpose** | Returns the list of all products that have available stock, formatted for the Ionic app. Filters out products with `abc_Available_Quantity__c = 0` so the app never presents out-of-stock items. |
| **Error Handling** | Wraps the entire method in try/catch; on exception logs via `abc_APILogger` and returns HTTP 500 with a JSON error body. |

#### `abc_CartAPI`
| | |
|---|---|
| **Type** | `@RestResource`, `global with sharing` |
| **URL** | `/services/apexrest/abc/cart` |
| **Method** | `POST` |
| **Purpose** | Creates a `abc_Order__c` record and one `abc_Order_Line_Item__c` per item in the request. Supports both Salesforce record IDs and SKU codes as product references. |
| **Idempotency** | Checks `abc_External_Cart_Id__c` before inserting; returns HTTP 200 with the existing order if the cart ID has already been processed. |
| **Validation** | Returns HTTP 400 for missing/empty items, HTTP 404 for unknown product references, HTTP 422 when requested quantity exceeds available stock. |
| **Error Handling** | All unexpected exceptions are caught, logged via `abc_APILogger`, and returned as HTTP 500. |

### 3.2 Logger

#### `abc_APILogger`
| | |
|---|---|
| **Type** | `public without sharing` |
| **Purpose** | Centralised error logging. Inserts a `abc_API_Log__c` record with class name, method name, error message, and stack trace. Uses `without sharing` so logs are always written regardless of the calling user's access. Falls back to `System.debug` if the DML insert itself fails. |

### 3.3 Batch Class

#### `abc_ArchiveOrdersBatch`
| | |
|---|---|
| **Type** | `public with sharing`, `implements Database.Batchable<SObject>` |
| **Purpose** | Identifies all `abc_Order__c` records where `abc_Status__c = 'Delivered'` AND `abc_Order_Date__c < TODAY - 1 year`, then writes them to `abc_Archived_Order__b` using `Database.insertImmediate`. |
| **Batch Size** | Default 200 (configurable at execution time). |
| **Running** | Execute via Developer Console: `Database.executeBatch(new abc_ArchiveOrdersBatch(), 200);` |
| **Note** | The batch does not delete source records — archiving is a copy, not a move. Deletion of source records would be a separate, explicit step if required. |

### 3.4 Visualforce Controller

#### `abc_WarehouseOrdersController`
| | |
|---|---|
| **Type** | `public without sharing` |
| **Purpose** | Backs the `abc_WarehouseOrders` Visualforce page. Loads all orders with their line items in a single SOQL query using a sub-query. Uses `without sharing` to ensure the warehouse profile user can see all orders irrespective of sharing rules. |
| **Inner Class** | `OrderWrapper` — pairs each order with its resolved icon string (⏳ / ⌛ / 🚚 / ✅) and its line item list. |

### 3.5 Test Classes

| Test Class | Covers | Key Scenarios |
|---|---|---|
| `abc_ProductAPITest` | `abc_ProductAPI` | Returns only in-stock products; empty product list returns 200 with count 0 |
| `abc_CartAPITest` | `abc_CartAPI` | Success by SF ID; success by SKU; idempotency; 400/404/422 error paths; blank productId; invalid customerId |
| `abc_ArchiveOrdersBatchTest` | `abc_ArchiveOrdersBatch` | Old delivered orders archived; recent delivered orders excluded; draft orders excluded; customer email fallback |
| `abc_WarehouseOrdersControllerTest` | `abc_WarehouseOrdersController` | All 4 icon types; line items loaded; total order count |

---

## 4. Salesforce Features Used

### 4.1 Lightning App (`abc_PharmaD`)
A custom Lightning Experience app providing a dedicated navigation space for business stakeholders. It surfaces the Pharmacy Products, Customers, Orders, and Order Line Items tabs under a single branded app, keeping pharmacy management separate from standard Salesforce objects.

### 4.2 Custom Objects & Fields
Five custom objects (`abc_Customer__c`, `abc_Product__c`, `abc_Order__c`, `abc_Order_Line_Item__c`, `abc_Archived_Order__b`) model the pharmacy's domain. The `abc_API_Log__c` object provides structured observability for API errors. Custom field types used include AutoNumber, Roll-up Summary, Formula, Currency, Picklist (with Global Value Sets), External ID, and Big Object index fields.

### 4.3 Big Object (`abc_Archived_Order__b`)
Chosen for long-term order archiving because Big Objects are designed for high-volume, append-only data and do not consume standard storage limits. `Database.insertImmediate` is used for direct write. The compound index (`Order Date DESC`, `Order Number ASC`) ensures efficient retrieval of recent archives.

### 4.4 Record-Triggered Flow (`abc_product_and_line_item_price_match`)
A before-save Flow fires when a `abc_Order_Line_Item__c` is created with a product set. It copies the product's current `abc_Unit_Price__c` to the line item's `abc_Price_per_unit__c`. Using a before-save Flow (rather than Apex or a formula) means the frozen price is written in the same transaction without an extra DML operation, and it requires no code — making it maintainable by admins.

### 4.5 Roll-Up Summary Field (`abc_Order_Total__c`)
`abc_Order__c.abc_Order_Total__c` is a Roll-up Summary that sums `abc_Order_Line_Item__c.abc_Total_Price__c`. This was possible because `abc_Order_Line_Item__c` has a Master-Detail relationship to `abc_Order__c`. It provides a real-time, always-accurate order total with zero Apex overhead.

### 4.6 REST Apex (`@RestResource`)
Used for both integration endpoints because the Ionic app requires programmatic access via HTTP. Apex REST was chosen over Salesforce Platform APIs (like the standard object API) because the cart creation involves multi-step logic (idempotency check, stock validation, parent + child DML) that cannot be expressed in a single standard API call.

### 4.7 Batch Apex (`Database.Batchable`)
Used for archiving because it safely handles large data volumes by processing records in configurable chunks, respecting governor limits. A scheduled Batch is the standard Salesforce pattern for nightly/periodic data maintenance jobs.

### 4.8 Visualforce Page (`abc_WarehouseOrders`)
Chosen over a Lightning component for the warehouse view because the assessment explicitly requested Visualforce. The page uses a server-side `OrderWrapper` to resolve icons in Apex (clean separation of logic from markup) and client-side JavaScript for row expansion (instant UX without a server round-trip).

### 4.9 Custom Profiles (`pharmacist`, `warehouse`)
Separate profiles for each user role ensure the principle of least privilege. The warehouse profile has read-only access to orders and products; the pharmacist profile has broader access to manage the full order lifecycle. This mirrors real pharmacy operations where warehouse staff only need to pick and dispatch — not create or price orders.

### 4.10 Lightning Record Pages (Flexipages)
All four custom objects have activated Lightning Record Pages (`Pharmacy_Order_Record_Page`, `Pharmacy_Product_Record_Page`, etc.) providing a polished, customised layout in the Lightning App beyond what the default page layout offers.

### 4.11 Global Value Sets (`abc_Governorate_values`, `abc_City_values`)
Egyptian governorates and cities are centralised in Global Value Sets and referenced by multiple objects (`abc_Customer__c`, `abc_Order__c`). This ensures a single source of truth for picklist options — adding a new city requires updating only one place.

### 4.12 External ID Fields
`abc_Product__c.abc_SKU__c` and `abc_Order__c.abc_External_Cart_Id__c` are designated as External IDs. This enables the Ionic app to reference products by their real-world SKU codes rather than Salesforce record IDs, and provides idempotency for the cart endpoint. External IDs are also indexed, so lookups by SKU/CartId are efficient.

### 4.13 Error Logging Object (`abc_API_Log__c`)
Rather than relying solely on debug logs (which require active debug sessions to capture), errors are persisted as `abc_API_Log__c` records. This provides a queryable, durable audit trail of API failures visible directly in Salesforce — accessible to admins without needing log access.

---

## 5. API Reference

### Authentication

All endpoints require a valid Salesforce OAuth2 Bearer token in the `Authorization` header.

```
Authorization: Bearer <access_token>
```

Tokens are obtained via Salesforce's OAuth2 flows. For server-to-server integration with the Ionic app, the **Connected App + JWT Bearer Flow** is recommended for production.

---

### 5.1 GET /services/apexrest/abc/products

Returns all pharmacy products that have stock available.

**Request**

```
GET https://<instance-url>/services/apexrest/abc/products
Authorization: Bearer <token>
```

**Response 200 — Success**

```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "id": "a01bm000001XxxxAAA",
      "name": "Amoxicillin 250mg",
      "sku": "SKU-AMOX-250",
      "unitPrice": 35.0,
      "availableQuantity": 100
    },
    {
      "id": "a01bm000001XyyyAAA",
      "name": "Paracetamol 500mg",
      "sku": "SKU-PARA-500",
      "unitPrice": 15.0,
      "availableQuantity": 200
    }
  ]
}
```

**Response 500 — Server Error**

```json
{ "success": false, "error": "<exception message>" }
```

---

### 5.2 POST /services/apexrest/abc/cart

Creates a pharmacy order with one or more line items.

**Request**

```
POST https://<instance-url>/services/apexrest/abc/cart
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

```json
{
  "externalCartId":  "CART-IONIC-001",
  "customerId":      "003bm000001XxxxAAA",
  "guestFirstName":  "Ahmed",
  "guestLastName":   "Ali",
  "governorate":     "Cairo",
  "city":            "Nasr City",
  "email":           "ahmed@example.com",
  "phone":           "01001234567",
  "detailedAddress": "123 Tahrir Street, Apt 5",
  "items": [
    { "productId": "SKU-PARA-500", "quantity": 2 },
    { "productId": "a01bm000001XxxxAAA", "quantity": 1 }
  ]
}
```

**Field Reference**

| Field | Type | Required | Notes |
|---|---|---|---|
| `externalCartId` | String | No | Enables idempotency — safe to re-send on retry |
| `customerId` | String | No | Salesforce ID of `abc_Customer__c`; omit for guests |
| `guestFirstName` | String | No | Used when no customerId is provided |
| `guestLastName` | String | No | |
| `governorate` | String | No | Must match a value in `abc_Governorate_values` |
| `city` | String | No | Must match a value in `abc_City_values` |
| `email` | String | No | Contact email for the order |
| `phone` | String | No | Numeric digits only (e.g. `01001234567`) |
| `detailedAddress` | String | No | Free text address |
| `items` | Array | **Yes** | Minimum 1 item |
| `items[].productId` | String | **Yes** | Salesforce record ID **or** `abc_SKU__c` value |
| `items[].quantity` | Integer | **Yes** | Must be > 0 |

**Responses**

| Status | Condition | Body |
|---|---|---|
| `201 Created` | Order created | `{ "success": true, "orderId": "...", "orderNumber": "ORD-0001" }` |
| `200 OK` | Idempotent — `externalCartId` already exists | `{ "success": true, "message": "Cart already exists.", "orderId": "...", "orderNumber": "..." }` |
| `400 Bad Request` | Empty items / blank productId / invalid quantity / bad customerId | `{ "success": false, "error": "..." }` |
| `404 Not Found` | Product not found by ID or SKU | `{ "success": false, "error": "Product not found: ..." }` |
| `422 Unprocessable` | Quantity exceeds available stock | `{ "success": false, "error": "Insufficient stock for product: ... (available: X, requested: Y)" }` |
| `500 Server Error` | Unexpected exception (logged to `abc_API_Log__c`) | `{ "success": false, "error": "..." }` |

---

## 6. Org Access

**Instance URL:** `https://orgfarm-7e74891727-dev-ed.develop.my.salesforce.com`

**Reviewer Account**

| Field | Value |
|---|---|
| Username | `assessments@cloudastick.com.pharmaD` |
| Email | `assessments@cloudastick.com` |
| Profile | System Administrator |
| License | Salesforce |

> **Note:** The account has been created in the org. Please use the "Forgot Password" flow at the instance URL above to set a password for the reviewer account before logging in.

**Warehouse User (for Visualforce page)**

| Field | Value |
|---|---|
| Profile | `warehouse` |
| Visualforce Page URL | `<instance-url>/apex/abc_WarehouseOrders` |

---

*This document was prepared as part of the Cloudastick Systems Salesforce Entry Assessment.*
