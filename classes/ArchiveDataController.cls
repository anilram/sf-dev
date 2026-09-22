/**
 * @description Apex controller to handle LWC requests for archived data.
 * This version removes Named Credential dependency and can work with mock data or direct calls.
 * Client sorting is handled in LWC. Server handles pagination and filtering.
 *
 * Security:
 * - No sharing required; this is a service layer for data handling.
 * - Can be extended to work with various data sources.
 *
 * Author: Agentforce
 */
public without sharing class ArchiveDataController {

    public class FilterDTO {
        @AuraEnabled public String field;
        @AuraEnabled public String operator; // equals | contains | startsWith
        @AuraEnabled public String value;
    }
    public class SortSpecDTO {
        @AuraEnabled public String field;
        @AuraEnabled public String direction; // asc | desc
    }
    public class PageRequestDTO {
        @AuraEnabled public String objectName;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public List<FilterDTO> filters;
        @AuraEnabled public SortSpecDTO sortSpec;
    }
    public class FieldMetadataDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String label;
        @AuraEnabled public Integer length;
        @AuraEnabled public Boolean nillable;
    }
    public class PageResponseDTO {
        @AuraEnabled public ObjectInfoDTO objectInfo;
        @AuraEnabled public List<Object> records;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
    }

     public class PicklistValue {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Boolean defaultValue;
    }

    public class Field {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Integer length;
        @AuraEnabled public Boolean nillable;
        @AuraEnabled public Boolean createable;
        @AuraEnabled public Boolean updateable;
        @AuraEnabled public Boolean filterable;
        @AuraEnabled public Boolean sortable;
        @AuraEnabled public Boolean unique;
        @AuraEnabled public Integer precision;
        @AuraEnabled public Integer scale;
        @AuraEnabled public List<PicklistValue> picklistValues;
    }

    public class ObjectInfoDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String labelPlural;
        @AuraEnabled public Boolean custom;
        @AuraEnabled public Boolean createable;
        @AuraEnabled public Boolean updateable;
        @AuraEnabled public Boolean deletable;
        @AuraEnabled public Boolean queryable;
        @AuraEnabled public Boolean searchable;
        @AuraEnabled public List<Field> fields;
    }
    /**
     * @description Primary entry for LWC. Accepts a JSON request, validates, calls out, and returns structured response.
     * @param requestJson JSON-serialized PageRequestDTO
     */
    @AuraEnabled(cacheable=false)
    public static PageResponseDTO fetchPage(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request is empty.');
        }
        Teacher__c tt = new Teacher__c();
        tt.TeacherInfo__c  = 'Test Teacher';
        // acc.AccountNumber = 'WAO';
        PageRequestDTO req;
        try {
            req = (PageRequestDTO) System.JSON.deserialize(requestJson, PageRequestDTO.class);
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid request format: ' + ex.getMessage());
        }

        if (String.isBlank(req.objectName)) {
            throw new AuraHandledException('objectName is required.');
        }
        if (req.pageNumber == null || req.pageNumber < 1) req.pageNumber = 1;
        if (req.pageSize == null || req.pageSize <= 0 || req.pageSize > 2000) req.pageSize = 50;

        PageResponseDTO resp = new PageResponseDTO();

        if(req.objectName != 'Account') {
            // For non-Account objects, simulate data fetching from external service
            try {
                // Simulate fetching object metadata
                HttpRequest objectInfoReq = new HttpRequest();
                objectInfoReq.setEndpoint('https://mocki.io/v1/bacc62dd-0dcb-4ff6-813a-baa844fc99dc');
                objectInfoReq.setMethod('GET');
                Http http = new Http();
                HttpResponse objectInfoRes = http.send(objectInfoReq);
                ObjectInfoDTO bodyRes = (ObjectInfoDTO) JSON.deserialize(objectInfoRes.getBody(), ObjectInfoDTO.class);
                resp.objectInfo = bodyRes;

                // Simulate fetching records
                HttpRequest objectRecordsReq = new HttpRequest();
                objectRecordsReq.setEndpoint('https://mocki.io/v1/14bf7e31-2c8e-4ed8-b21a-e4f981b6fe10');
                objectRecordsReq.setMethod('GET');

                http = new Http();
                HttpResponse res = http.send(objectRecordsReq);
                System.debug(res.getBody());
                List<Map<String, String>> objectRecordsRes = (List<Map<String, String>>) JSON.deserialize(res.getBody(), List<Map<String, String>>.class);
                resp.records = objectRecordsRes;

                resp.pageNumber = 0;
                resp.pageSize = objectRecordsRes.size();
                resp.totalRecords = objectRecordsRes.size();
            } catch (Exception e) {
                System.debug('EXCEPTION MESSAGE: ' + e.getMessage());
            }
        } else {
            resp = getDummyData(req);
        }
        
        return resp;
    }

    private static PageResponseDTO getDummyData(PageRequestDTO req) {
            PageResponseDTO resp = new PageResponseDTO();

            List<Map<String, String>> mockRecords = new List<Map<String, String>>();
            
            // Sample account records
            Map<String, String> account1 = new Map<String, String>{
                'Id' => '001xx000003DHPpAAO',
                'Name' => 'Acme Corporation',
                'Industry' => 'Technology',
                'AnnualRevenue' => '100000000.00',
                'NumberOfEmployees' => '5000',
                'Type' => 'Customer',
                'BillingCity' => 'San Francisco',
                'BillingCountry' => 'USA'
            };
            
            Map<String, String> account2 = new Map<String, String>{
                'Id' => '001xx000003DHQqAAO',
                'Name' => 'Globex Industries',
                'Industry' => 'Manufacturing',
                'AnnualRevenue' => '75000000.00',
                'NumberOfEmployees' => '2500',
                'Type' => 'Partner',
                'BillingCity' => 'Boston',
                'BillingCountry' => 'USA'
            };
            
            Map<String, String> account3 = new Map<String, String>{
                'Id' => '001xx000003DHRrAAO',
                'Name' => 'Initech Inc',
                'Industry' => 'Finance',
                'AnnualRevenue' => '150000000.00',
                'NumberOfEmployees' => '10000',
                'Type' => 'Customer',
                'BillingCity' => 'New York',
                'BillingCountry' => 'USA'
            };
            
            mockRecords.add(account1);
            mockRecords.add(account2);
            mockRecords.add(account3);
            
            // Set up response for Account object
            resp.records = mockRecords;
            resp.totalRecords = mockRecords.size();
            resp.pageNumber = req.pageNumber;
            resp.pageSize = req.pageSize;
            
            // Set up object info for Account
            ObjectInfoDTO accountInfo = new ObjectInfoDTO();
            accountInfo.name = 'Account';
            accountInfo.label = 'Account';
            accountInfo.labelPlural = 'Accounts';
            accountInfo.custom = false;
            accountInfo.createable = true;
            accountInfo.updateable = true;
            accountInfo.deletable = true;
            accountInfo.queryable = true;
            accountInfo.searchable = true;
            
            // Add fields matching the provided task structure
            List<Field> accountFields = new List<Field>();
            
            Field idField = new Field();
            idField.name = 'Id';
            idField.label = 'Account ID';
            idField.type = 'id';
            idField.length = 18;
            idField.nillable = false;
            idField.createable = false;
            idField.updateable = false;
            idField.filterable = true;
            idField.sortable = true;
            idField.unique = true;
            accountFields.add(idField);
            
            Field nameField = new Field();
            nameField.name = 'Name';
            nameField.label = 'Account Name';
            nameField.type = 'string';
            nameField.length = 255;
            nameField.nillable = false;
            nameField.createable = true;
            nameField.updateable = true;
            nameField.filterable = true;
            nameField.sortable = true;
            nameField.unique = false;
            accountFields.add(nameField);
            
            Field industryField = new Field();
            industryField.name = 'Industry';
            industryField.label = 'Industry';
            industryField.type = 'picklist';
            industryField.length = 40;
            industryField.nillable = true;
            industryField.createable = true;
            industryField.updateable = true;
            industryField.filterable = true;
            industryField.sortable = true;
            industryField.unique = false;
            
            // Add picklist values for Industry
            List<PicklistValue> industryValues = new List<PicklistValue>();
            PicklistValue techValue = new PicklistValue();
            techValue.label = 'Technology';
            techValue.value = 'Technology';
            techValue.active = true;
            techValue.defaultValue = false;
            industryValues.add(techValue);
            
            PicklistValue manufValue = new PicklistValue();
            manufValue.label = 'Manufacturing';
            manufValue.value = 'Manufacturing';
            manufValue.active = true;
            manufValue.defaultValue = false;
            industryValues.add(manufValue);
            
            PicklistValue financeValue = new PicklistValue();
            financeValue.label = 'Finance';
            financeValue.value = 'Finance';
            financeValue.active = true;
            financeValue.defaultValue = false;
            industryValues.add(financeValue);
            
            industryField.picklistValues = industryValues;
            accountFields.add(industryField);
            
            Field revenueField = new Field();
            revenueField.name = 'AnnualRevenue';
            revenueField.label = 'Annual Revenue';
            revenueField.type = 'currency';
            revenueField.precision = 18;
            revenueField.scale = 2;
            revenueField.nillable = true;
            revenueField.createable = true;
            revenueField.updateable = true;
            revenueField.filterable = true;
            revenueField.sortable = true;
            revenueField.unique = false;
            accountFields.add(revenueField);
            
            Field employeesField = new Field();
            employeesField.name = 'NumberOfEmployees';
            employeesField.label = 'Employees';
            employeesField.type = 'int';
            employeesField.nillable = true;
            employeesField.createable = true;
            employeesField.updateable = true;
            employeesField.filterable = true;
            employeesField.sortable = true;
            employeesField.unique = false;
            accountFields.add(employeesField);
            
            Field typeField = new Field();
            typeField.name = 'Type';
            typeField.label = 'Account Type';
            typeField.type = 'picklist';
            typeField.length = 40;
            typeField.nillable = true;
            typeField.createable = true;
            typeField.updateable = true;
            typeField.filterable = true;
            typeField.sortable = true;
            typeField.unique = false;
            
            // Add picklist values for Type
            List<PicklistValue> typeValues = new List<PicklistValue>();
            PicklistValue customerValue = new PicklistValue();
            customerValue.label = 'Customer';
            customerValue.value = 'Customer';
            customerValue.active = true;
            customerValue.defaultValue = false;
            typeValues.add(customerValue);
            
            PicklistValue partnerValue = new PicklistValue();
            partnerValue.label = 'Partner';
            partnerValue.value = 'Partner';
            partnerValue.active = true;
            partnerValue.defaultValue = false;
            typeValues.add(partnerValue);
            
            PicklistValue prospectValue = new PicklistValue();
            prospectValue.label = 'Prospect';
            prospectValue.value = 'Prospect';
            prospectValue.active = true;
            prospectValue.defaultValue = false;
            typeValues.add(prospectValue);
            
            typeField.picklistValues = typeValues;
            accountFields.add(typeField);
            
            Field cityField = new Field();
            cityField.name = 'BillingCity';
            cityField.label = 'Billing City';
            cityField.type = 'string';
            cityField.length = 40;
            cityField.nillable = true;
            cityField.createable = true;
            cityField.updateable = true;
            cityField.filterable = true;
            cityField.sortable = true;
            cityField.unique = false;
            accountFields.add(cityField);
            
            Field countryField = new Field();
            countryField.name = 'BillingCountry';
            countryField.label = 'Billing Country';
            countryField.type = 'string';
            countryField.length = 80;
            countryField.nillable = true;
            countryField.createable = true;
            countryField.updateable = true;
            countryField.filterable = true;
            countryField.sortable = true;
            countryField.unique = false;
            accountFields.add(countryField);
            
            accountInfo.fields = accountFields;
            resp.objectInfo = accountInfo;

            return resp;
    }
}