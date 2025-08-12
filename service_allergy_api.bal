import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/health.clients.fhir;
import ballerinax/health.fhir.r4 as r4;
import ballerinax/health.fhir.r4.uscore501 as uscore501;

service /healthcare on new http:Listener(servicePort) {

    resource function post allergies(PatientRequest patientRequest) returns ApiResponse|error {

        string patientMemberId = patientRequest.patientMemberId;
        log:printInfo("Processing allergy intolerance request for patient: " + patientMemberId);

        // Search for allergy intolerance resources
        map<string[]> searchParams = {
            "patient": [patientMemberId]
        };

        fhir:FHIRResponse|fhir:FHIRError searchResult = fhirConnectorObject->search("AllergyIntolerance", searchParameters = searchParams);

        if searchResult is fhir:FHIRError {
            log:printError("Error searching for allergy intolerance: " + searchResult.message());
            return searchResult;
        }

        json searchResultJson = <json>searchResult.'resource;
        uscore501:USCoreAllergyIntolerance[] allergies = [];

        json|error bundleData = searchResultJson;
        if bundleData is error {
            return error("Error parsing allergy results");
        }

        json|error entryData = bundleData.entry;
        if entryData is json[] {
            foreach json entry in entryData {
                json|error resourceEntry = entry.'resource;
                if resourceEntry is json {
                    uscore501:USCoreAllergyIntolerance|error allergy = resourceEntry.cloneWithType(uscore501:USCoreAllergyIntolerance);
                    if allergy is uscore501:USCoreAllergyIntolerance {
                        allergies.push(allergy);
                    }
                }
            }
        }

        io:println("Found " + allergies.length().toString() + " allergy intolerance records for patient " + patientMemberId);

        AllergyIntoleranceData[]|error allergyData = self.processAllergyData(allergies);
        if allergyData is error {
            log:printError("Error processing allergy data: " + allergyData.message());
            return allergyData;
        }
        // Send data to external APIs
        error? jsonResult = self.sendToJsonEndpoint(allergyData);
        if jsonResult is error {
            log:printError("Failed to send data to JSON endpoint: " + jsonResult.message());
        }

        error? xmlResult = self.sendToXmlEndpoint(allergyData);
        if xmlResult is error {
            log:printError("Failed to send data to XML endpoint: " + xmlResult.message());
        }

        return {
            status: "success",
            message: "Allergy intolerance data processed and sent to external endpoints",
            patientId: patientMemberId
        };

    }

    private function processAllergyData(uscore501:USCoreAllergyIntolerance[] allergyResources) returns AllergyIntoleranceData[]|error {

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

    private function sendToJsonEndpoint(AllergyIntoleranceData[] allergyDataArray) returns error? {
        // Send to JSON endpoint
        http:Response|http:ClientError response = jsonApiClient->post("/", allergyDataArray);
        if response is http:ClientError {
            return response;
        }

        log:printInfo("Successfully sent allergy data to JSON endpoint");
        return;
    }

    private function sendToXmlEndpoint(AllergyIntoleranceData[] allergyDataArray) returns error? {

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
        http:Response|http:ClientError response = xmlApiClient->post("/", root, mediaType = "application/xml");
        if response is http:ClientError {
            return response;
        }

        log:printInfo("Successfully sent allergy data to XML endpoint");
        return;
    }

}
