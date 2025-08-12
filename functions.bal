import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/sql;
import ballerinax/health.fhir.r4.uscore501 as uscore501;
import ballerinax/health.fhir.r4 as r4;

// Function to retrieve active endpoints from database
public function getActiveEndpoints() returns EndpointQueryResult[]|error {

    sql:ParameterizedQuery query = `
        SELECT endpoint_url, endpoint_type 
        FROM api_endpoints 
        WHERE is_active = true 
        ORDER BY endpoint_type
    `;

    stream<EndpointQueryResult, sql:Error?> resultStream = dbClient->query(query);
    EndpointQueryResult[] endpoints = [];

    check from EndpointQueryResult endpoint in resultStream
        do {
            endpoints.push(endpoint);
        };

    check resultStream.close();

    if endpoints.length() == 0 {
        log:printWarn("No active endpoints found in database");
    } else {
        log:printInfo("Retrieved " + endpoints.length().toString() + " active endpoints from database");
    }

    return endpoints;
}

// Function to get endpoints by type
public function getEndpointsByType(string endpointType) returns string[]|error {

    sql:ParameterizedQuery query = `
        SELECT endpoint_url 
        FROM api_endpoints 
        WHERE endpoint_type = ${endpointType} AND is_active = true
    `;

    stream<record {|string endpoint_url;|}, sql:Error?> resultStream = dbClient->query(query);
    string[] endpointUrls = [];

    check from record {|string endpoint_url;|} endpoint in resultStream
        do {
            endpointUrls.push(endpoint.endpoint_url);
        };

    check resultStream.close();

    return endpointUrls;
}

public function sendToJsonEndpoint(AllergyIntoleranceData[] allergyDataArray, string endpointUrl) returns error? {

    // Create HTTP client for the specific endpoint
    http:Client|error jsonClient = new (endpointUrl);
    if jsonClient is error {
        return error("Failed to create HTTP client for JSON endpoint: " + endpointUrl);
    }

    // Send to JSON endpoint
    http:Response|http:ClientError response = jsonClient->post("/", allergyDataArray);
    if response is http:ClientError {
        return response;
    }

    log:printInfo("Successfully sent allergy data to JSON endpoint: " + endpointUrl);
    return;
}

public function sendToXmlEndpoint(AllergyIntoleranceData[] allergyDataArray, string endpointUrl) returns error? {

    // Create HTTP client for the specific endpoint
    http:Client|error xmlClient = new (endpointUrl);
    if xmlClient is error {
        return error("Failed to create HTTP client for XML endpoint: " + endpointUrl);
    }

    xml root = xml ``;
    foreach AllergyIntoleranceData allergyData in allergyDataArray {
        xml xmlData = xml `<AllergyIntolerance>
                <resourceType>${allergyData.resourceType}</resourceType>
                <id>${allergyData.id ?: ""}</id>
                <patientReference>${allergyData.patientReference}</patientReference>
                <clinicalStatus>${allergyData.clinicalStatus ?: ""}</clinicalStatus>
                <verificationStatus>${allergyData.verificationStatus ?: ""}</verificationStatus>
            </AllergyIntolerance>`;
        root = (root + xmlData);
    }

    root = xml `<AllergyIntoleranceData>${root}</AllergyIntoleranceData>`;

    io:println(root.toString());

    // Send to XML endpoint
    http:Response|http:ClientError response = xmlClient->post("/", root, mediaType = "application/xml");
    if response is http:ClientError {
        return response;
    }

    log:printInfo("Successfully sent allergy data to XML endpoint: " + endpointUrl);
    return;
}

public function sendToEndpoints(AllergyIntoleranceData[] allergyDataArray) returns error? {
    //Get JSON endpoints from database
    string[]|error jsonEndpoints = getEndpointsByType("JSON");
    if jsonEndpoints is error {
        log:printError("Failed to retrieve JSON endpoints: " + jsonEndpoints.message());
    } else {
        foreach string jsonEndpoint in jsonEndpoints {
            error? jsonResult = sendToJsonEndpoint(allergyDataArray, jsonEndpoint);
            if jsonResult is error {
                log:printError("Failed to send data to JSON endpoint " + jsonEndpoint + ": " + jsonResult.message());
            }
        }
    }

    //Get XML endpoints from database
    string[]|error xmlEndpoints = getEndpointsByType("XML");
    if xmlEndpoints is error {
        log:printError("Failed to retrieve XML endpoints: " + xmlEndpoints.message());
    } else {
        foreach string xmlEndpoint in xmlEndpoints {
            error? xmlResult = sendToXmlEndpoint(allergyDataArray, xmlEndpoint);
            if xmlResult is error {
                log:printError("Failed to send data to XML endpoint " + xmlEndpoint + ": " + xmlResult.message());
            }
        }
    }

    return;
}

    public function processAllergyData(uscore501:USCoreAllergyIntolerance[] allergyResources) returns AllergyIntoleranceData[]|error {

        AllergyIntoleranceData[] allergyDataArray = [];
        foreach uscore501:USCoreAllergyIntolerance allergyResource in allergyResources {

            // Serialize to JSON
            json|r4:FHIRSerializerError jsonData = r4:executeResourceJsonSerializer(allergyResource);
            if jsonData is r4:FHIRSerializerError {
                return jsonData;
            }

            // Create structured data for JSON endpoint
            string patientRef = allergyResource.patient.reference ?: "";
            string resourceId = allergyResource.id ?: "";

            AllergyIntoleranceData allergyData = {
                resourceType: "AllergyIntolerance",
                id: resourceId,
                patientReference: patientRef,
                code: allergyResource.code
            };

            // Add optional fields if present
            if allergyResource.clinicalStatus is r4:CodeableConcept {
                r4:CodeableConcept clinicalStatus = <r4:CodeableConcept>allergyResource.clinicalStatus;
                r4:Coding[]? codings = clinicalStatus.coding;
                if codings is r4:Coding[] && codings.length() > 0 {
                    string? codeValue = codings[0].code;
                    if codeValue is string {
                        allergyData.clinicalStatus = codeValue;
                    }
                }
            }

            if allergyResource.verificationStatus is r4:CodeableConcept {
                r4:CodeableConcept verificationStatus = <r4:CodeableConcept>allergyResource.verificationStatus;
                r4:Coding[]? codings = verificationStatus.coding;
                if codings is r4:Coding[] && codings.length() > 0 {
                    string? codeValue = codings[0].code;
                    if codeValue is string {
                        allergyData.verificationStatus = codeValue;
                    }
                }
            }

            allergyDataArray.push(allergyData);

        }

        io:println(allergyDataArray);
        return allergyDataArray;
    }
