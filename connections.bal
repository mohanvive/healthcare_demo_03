import ballerinax/health.clients.fhir;
import ballerina/http;

// FHIR server configuration
configurable string base = ?;
configurable string tokenUrl = ?;
configurable string clientIdValue = ?;
configurable string clientSecret = ?;
configurable string[] scopesArray = ["system/Patient.read", "system/Patient.create", "system/Observation.read", "system/AllergyIntolerance.read"];

// External API endpoints configuration
configurable string jsonApiEndpoint = "https://testmohan.free.beeceptor.com";
configurable string xmlApiEndpoint = "https://testmohan.free.beeceptor.com";

// FHIR client configuration
fhir:FHIRConnectorConfig cernerConfiuration = {
    baseURL: base,
    mimeType: fhir:FHIR_JSON,
    authConfig: {
        tokenUrl: tokenUrl,
        clientId: clientIdValue,
        clientSecret: clientSecret,
        scopes: scopesArray
    }
};

// Initialize FHIR connector
final fhir:FHIRConnector fhirConnectorObject = check new (cernerConfiuration);

// HTTP clients for external APIs
final http:Client jsonApiClient = check new (jsonApiEndpoint);
final http:Client xmlApiClient = check new (xmlApiEndpoint);

// Service port configuration
configurable int servicePort = 9090;