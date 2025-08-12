import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/health.clients.fhir;
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

        AllergyIntoleranceData[]|error allergyData = processAllergyData(allergies);
        if allergyData is error {
            log:printError("Error processing allergy data: " + allergyData.message());
            return allergyData;
        }
        // Retrieve endpoints from database and send data
        error? sendResult = sendToEndpoints(allergyData);
        if sendResult is error {
            log:printError("Failed to send data to endpoints: " + sendResult.message());
        }

        return {
            status: "success",
            message: "Allergy intolerance data processed and sent to external endpoints",
            patientId: patientMemberId
        };

    }

}

